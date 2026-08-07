import Foundation
import VertexCore
import VertexMedia
import VertexProject
import VertexRender

public struct CompositionGraphCompiler: Sendable {
    public static let compilerVersion = 1

    public init() {}

    public func compile(
        _ request: CompositionRenderRequest,
        resolver: any CompositionFrameResolver,
        cancellationToken: RenderCancellationToken
    ) async throws -> RenderRequest {
        let project = try request.project.validated()
        let limits = try request.limits.validated()
        guard request.time >= .zero else {
            throw CompositionError.invalidTimingRange("Requested composition time must be nonnegative.")
        }
        guard let root = project.composition(id: request.compositionID) else {
            throw CompositionError.missingComposition(request.compositionID.rawValue)
        }
        guard request.time < root.duration else {
            throw CompositionError.invalidTimingRange("Requested composition time is outside the root duration.")
        }

        let state = CompilerState(
            project: project,
            output: request.output,
            limits: limits,
            resolver: resolver,
            cancellationToken: cancellationToken
        )
        let rootPath = [request.compositionID.rawValue]
        let rootNode = try await state.compileComposition(
            id: request.compositionID,
            time: request.time,
            path: rootPath,
            stack: [],
            depth: 1
        )
        let outputID = try state.nodeID(path: rootPath, role: "output")
        try state.append(RenderNode(id: outputID, dependencies: [rootNode], kind: .output))
        try await cancellationToken.throwIfCancelled()

        do {
            return try RenderRequest(
                graph: RenderGraph(nodes: state.nodes),
                time: request.time,
                output: request.output,
                context: RenderCacheContext(
                    compositionID: request.compositionID,
                    projectRevision: project.revision,
                    compilerVersion: Self.compilerVersion
                )
            )
        } catch let error as RenderError {
            throw CompositionError.graphCompilationFailed(error.localizedDescription)
        }
    }
}

private final class CompilerState: @unchecked Sendable {
    let project: ProjectDocument
    let output: RenderOutputSpecification
    let limits: CompositionRenderLimits
    let resolver: any CompositionFrameResolver
    let cancellationToken: RenderCancellationToken
    var nodes: [RenderNode] = []
    var frameCache: [CompositionFrameCacheKey: CompositionFrameResolution] = [:]

    init(
        project: ProjectDocument,
        output: RenderOutputSpecification,
        limits: CompositionRenderLimits,
        resolver: any CompositionFrameResolver,
        cancellationToken: RenderCancellationToken
    ) {
        self.project = project
        self.output = output
        self.limits = limits
        self.resolver = resolver
        self.cancellationToken = cancellationToken
    }

    func compileComposition(
        id: VertexID,
        time: RationalTime,
        path: [String],
        stack: [VertexID],
        depth: Int
    ) async throws -> VertexID {
        try await cancellationToken.throwIfCancelled()
        guard depth <= limits.maximumNestedDepth else {
            throw CompositionError.nestingDepthExceeded(depth)
        }
        if let cycleStart = stack.firstIndex(of: id) {
            let cycle = Array(stack[cycleStart...]) + [id]
            throw CompositionError.nestedCompositionCycle(cycle.map(\.rawValue))
        }
        guard let composition = project.composition(id: id) else {
            throw CompositionError.missingComposition(id.rawValue)
        }
        guard composition.width <= limits.maximumDimension,
              composition.height <= limits.maximumDimension else {
            throw CompositionError.graphCompilationFailed("Composition dimensions exceed the render limit.")
        }
        guard composition.layerIDs.count <= limits.maximumLayersPerComposition else {
            throw CompositionError.layerLimitExceeded(composition.layerIDs.count)
        }

        let backgroundID = try nodeID(path: path, role: "background")
        try append(RenderNode(
            id: backgroundID,
            dependencies: [],
            kind: .solidColor(renderColor(composition.backgroundColor))
        ))
        var accumulator = backgroundID
        let visible = try CompositionVisibilityResolver().participatingLayers(
            in: composition,
            project: project,
            time: time
        )

        for layer in visible.reversed() {
            try await cancellationToken.throwIfCancelled()
            let layerPath = path + [layer.id.rawValue]
            switch layer.source {
            case .media(let mediaID, let sourceStartTime):
                let sourceTime = try time.subtracting(layer.timing.startTime).adding(sourceStartTime)
                guard sourceTime >= .zero else { continue }
                let resolution = try await resolveFrame(mediaID: mediaID, time: sourceTime)
                guard case .frame(let image) = resolution else { continue }
                let sourceID = try nodeID(path: layerPath, role: "source")
                try append(RenderNode(id: sourceID, dependencies: [], kind: .source(image)))
                let prepared = try appendLayerOperations(layer, input: sourceID, path: layerPath)
                accumulator = try appendComposite(layer, backdrop: accumulator, source: prepared, path: layerPath)

            case .composition(let childID, let sourceStartTime):
                let childTime = try time.subtracting(layer.timing.startTime).adding(sourceStartTime)
                guard childTime >= .zero else { continue }
                guard let child = project.composition(id: childID) else {
                    throw CompositionError.missingComposition(childID.rawValue)
                }
                guard childTime < child.duration else { continue }
                let childRoot = try await compileComposition(
                    id: childID,
                    time: childTime,
                    path: layerPath + [childID.rawValue],
                    stack: stack + [id],
                    depth: depth + 1
                )
                let prepared = try appendLayerOperations(layer, input: childRoot, path: layerPath)
                accumulator = try appendComposite(layer, backdrop: accumulator, source: prepared, path: layerPath)

            case .adjustment:
                let adjustmentID = try nodeID(path: layerPath, role: "adjustment")
                try append(RenderNode(
                    id: adjustmentID,
                    dependencies: [accumulator],
                    kind: .adjustment(renderOperations(layer.operations), mix: layer.transform.opacity)
                ))
                accumulator = adjustmentID

            case .null, .guide, .camera, .light:
                continue
            }
        }
        return accumulator
    }

    func resolveFrame(mediaID: VertexID, time: RationalTime) async throws -> CompositionFrameResolution {
        guard project.mediaRegistry.contains(where: { $0.id == mediaID }) else {
            throw CompositionError.missingMedia(mediaID.rawValue)
        }
        let key = CompositionFrameCacheKey(
            mediaID: mediaID,
            time: time,
            width: output.width,
            height: output.height
        )
        if let cached = frameCache[key] { return cached }
        try await cancellationToken.throwIfCancelled()
        do {
            let result = try await resolver.resolve(
                mediaID: mediaID,
                exactSourceTime: time,
                targetSize: VertexSize(width: Double(output.width), height: Double(output.height))
            )
            try await cancellationToken.throwIfCancelled()
            frameCache[key] = result
            return result
        } catch let error as CompositionError {
            throw error
        } catch {
            throw CompositionError.frameResolutionFailed(error.localizedDescription)
        }
    }

    func appendLayerOperations(_ layer: ProjectLayer, input: VertexID, path: [String]) throws -> VertexID {
        let operationID = try nodeID(path: path, role: "operations")
        let transform = RenderTransform2D(
            positionX: layer.transform.positionX,
            positionY: layer.transform.positionY,
            anchorX: layer.transform.anchorX,
            anchorY: layer.transform.anchorY,
            scaleX: layer.transform.scaleX,
            scaleY: layer.transform.scaleY,
            rotationDegrees: layer.transform.rotationDegrees
        )
        var operations: [RenderOperation] = [.transform2D(transform)]
        operations.append(contentsOf: renderOperations(layer.operations))
        operations.append(.opacity(layer.transform.opacity))
        try append(RenderNode(id: operationID, dependencies: [input], kind: .operations(operations)))
        return operationID
    }

    func appendComposite(
        _ layer: ProjectLayer,
        backdrop: VertexID,
        source: VertexID,
        path: [String]
    ) throws -> VertexID {
        let compositeID = try nodeID(path: path, role: "composite")
        try append(RenderNode(
            id: compositeID,
            dependencies: [backdrop, source],
            kind: .composite(renderBlendMode(layer.blendMode))
        ))
        return compositeID
    }

    func append(_ node: RenderNode) throws {
        guard nodes.count < limits.maximumExpandedNodes else {
            throw CompositionError.nodeLimitExceeded(nodes.count + 1)
        }
        nodes.append(node)
    }

    func nodeID(path: [String], role: String) throws -> VertexID {
        try DeterministicVertexID.derive(
            domain: "vertex.phase6.render-node",
            components: [project.projectID.rawValue] + path + [role]
        )
    }

    private func renderColor(_ color: ProjectRGBAColor) -> RenderRGBAColor {
        RenderRGBAColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    private func renderBlendMode(_ blend: LayerBlendMode) -> RenderBlendMode {
        switch blend {
        case .normal: .normal
        case .add: .add
        case .multiply: .multiply
        case .screen: .screen
        }
    }

    private func renderOperations(_ operations: [LayerOperation]) -> [RenderOperation] {
        operations.map { operation in
            switch operation {
            case .exposure(let stops): .exposure(stops: stops)
            case .saturation(let value): .saturation(value)
            case .invert(let enabled): .invert(enabled)
            }
        }
    }
}
