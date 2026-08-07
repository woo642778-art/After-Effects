import Foundation
import VertexCore
import VertexMedia
import VertexProject
import VertexRender

public struct CompositionGraphCompiler: Sendable {
    public static let compilerVersion = 2

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
        let visibleByID = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0) })
        let consumedMatteIDs = Set(visible.compactMap { $0.trackMatte?.sourceLayerID })

        for layer in visible.reversed() {
            try await cancellationToken.throwIfCancelled()
            if consumedMatteIDs.contains(layer.id) {
                continue
            }
            let layerPath = path + [layer.id.rawValue]
            let evaluated = try LayerAnimationEvaluator.evaluate(layer: layer, at: time)

            switch layer.source {
            case .media, .composition:
                guard var prepared = try await compileRenderableLayer(
                    layer: layer,
                    evaluated: evaluated,
                    compositionTime: time,
                    path: layerPath,
                    stack: stack + [id],
                    depth: depth,
                    visibleByID: visibleByID,
                    matteStack: []
                ) else { continue }
                if let matte = layer.trackMatte {
                    let matteID = try await compileTrackMatteSource(
                        targetLayer: layer,
                        trackMatte: matte,
                        compositionTime: time,
                        path: layerPath,
                        stack: stack + [id],
                        depth: depth,
                        visibleByID: visibleByID,
                        matteStack: [layer.id]
                    )
                    let matteNodeID = try nodeID(path: layerPath, role: "matte")
                    try append(RenderNode(
                        id: matteNodeID,
                        dependencies: [prepared, matteID],
                        kind: .matte(renderTrackMatteMode(matte.mode))
                    ))
                    prepared = matteNodeID
                }
                accumulator = try appendComposite(layer, backdrop: accumulator, source: prepared, path: layerPath)

            case .adjustment:
                let adjustmentID = try nodeID(path: layerPath, role: "adjustment")
                try append(RenderNode(
                    id: adjustmentID,
                    dependencies: [accumulator],
                    kind: .adjustment(renderOperations(layer.operations), mix: evaluated.transform.opacity)
                ))
                var prepared = adjustmentID
                let hasMasking = !evaluated.masks.isEmpty
                if hasMasking {
                    prepared = try appendMasks(evaluated.masks, input: prepared, path: layerPath)
                }
                if let matte = layer.trackMatte {
                    let matteID = try await compileTrackMatteSource(
                        targetLayer: layer,
                        trackMatte: matte,
                        compositionTime: time,
                        path: layerPath,
                        stack: stack + [id],
                        depth: depth,
                        visibleByID: visibleByID,
                        matteStack: [layer.id]
                    )
                    let matteNodeID = try nodeID(path: layerPath, role: "matte")
                    try append(RenderNode(
                        id: matteNodeID,
                        dependencies: [prepared, matteID],
                        kind: .matte(renderTrackMatteMode(matte.mode))
                    ))
                    prepared = matteNodeID
                }
                if hasMasking || layer.trackMatte != nil {
                    accumulator = try appendComposite(layer, backdrop: accumulator, source: prepared, path: layerPath)
                } else {
                    accumulator = adjustmentID
                }

            case .null, .guide, .camera, .light:
                continue
            }
        }
        return accumulator
    }

    func compileRenderableLayer(
        layer: ProjectLayer,
        evaluated: EvaluatedLayerState,
        compositionTime: RationalTime,
        path: [String],
        stack: [VertexID],
        depth: Int,
        visibleByID: [VertexID: ProjectLayer],
        matteStack: [VertexID]
    ) async throws -> VertexID? {
        let sourceID: VertexID
        switch layer.source {
        case .media(let mediaID, let sourceStartTime):
            let sourceTime = try compositionTime.subtracting(layer.timing.startTime).adding(sourceStartTime)
            guard sourceTime >= .zero else { return nil }
            let resolution = try await resolveFrame(mediaID: mediaID, time: sourceTime)
            guard case .frame(let image) = resolution else { return nil }
            sourceID = try nodeID(path: path, role: "source")
            try append(RenderNode(id: sourceID, dependencies: [], kind: .source(image)))

        case .composition(let childID, let sourceStartTime):
            let childTime = try compositionTime.subtracting(layer.timing.startTime).adding(sourceStartTime)
            guard childTime >= .zero else { return nil }
            guard let child = project.composition(id: childID) else {
                throw CompositionError.missingComposition(childID.rawValue)
            }
            guard childTime < child.duration else { return nil }
            sourceID = try await compileComposition(
                id: childID,
                time: childTime,
                path: path + [childID.rawValue],
                stack: stack,
                depth: depth + 1
            )

        case .adjustment, .null, .guide, .camera, .light:
            throw CompositionError.graphCompilationFailed("Only media and nested-composition layers can be prepared as standalone pixels.")
        }

        var prepared = sourceID
        if !evaluated.masks.isEmpty {
            prepared = try appendMasks(evaluated.masks, input: prepared, path: path)
        }
        prepared = try appendLayerOperations(layer, transform: evaluated.transform, input: prepared, path: path)

        if let matte = layer.trackMatte {
            let nextStack = matteStack + [layer.id]
            guard !nextStack.contains(matte.sourceLayerID) else {
                throw CompositionError.graphCompilationFailed("Track matte cycle reached the graph compiler.")
            }
            let matteSourceID = try await compileTrackMatteSource(
                targetLayer: layer,
                trackMatte: matte,
                compositionTime: compositionTime,
                path: path,
                stack: stack,
                depth: depth,
                visibleByID: visibleByID,
                matteStack: nextStack
            )
            let matteNodeID = try nodeID(path: path, role: "nested-matte-\(nextStack.count)")
            try append(RenderNode(
                id: matteNodeID,
                dependencies: [prepared, matteSourceID],
                kind: .matte(renderTrackMatteMode(matte.mode))
            ))
            prepared = matteNodeID
        }
        return prepared
    }

    func compileTrackMatteSource(
        targetLayer: ProjectLayer,
        trackMatte: ProjectTrackMatte,
        compositionTime: RationalTime,
        path: [String],
        stack: [VertexID],
        depth: Int,
        visibleByID: [VertexID: ProjectLayer],
        matteStack: [VertexID]
    ) async throws -> VertexID {
        guard let matteLayer = project.layer(id: trackMatte.sourceLayerID),
              matteLayer.compositionID == targetLayer.compositionID else {
            throw CompositionError.graphCompilationFailed("Track matte source is missing or belongs to another composition.")
        }
        guard case .media = matteLayer.source || isCompositionSource(matteLayer.source) else {
            throw CompositionError.graphCompilationFailed("Track matte sources must be media or nested-composition layers.")
        }
        guard visibleByID[matteLayer.id] != nil else {
            let transparentID = try nodeID(path: path + ["matte", matteLayer.id.rawValue], role: "inactive")
            try append(RenderNode(
                id: transparentID,
                dependencies: [],
                kind: .solidColor(RenderRGBAColor(red: 0, green: 0, blue: 0, alpha: 0))
            ))
            return transparentID
        }
        guard !matteStack.contains(matteLayer.id) else {
            throw CompositionError.graphCompilationFailed("Track matte relationships contain a cycle.")
        }
        let mattePath = path + ["matte", matteLayer.id.rawValue, String(matteStack.count)]
        let evaluated = try LayerAnimationEvaluator.evaluate(layer: matteLayer, at: compositionTime)
        guard let prepared = try await compileRenderableLayer(
            layer: matteLayer,
            evaluated: evaluated,
            compositionTime: compositionTime,
            path: mattePath,
            stack: stack,
            depth: depth,
            visibleByID: visibleByID,
            matteStack: matteStack
        ) else {
            let transparentID = try nodeID(path: mattePath, role: "empty")
            try append(RenderNode(
                id: transparentID,
                dependencies: [],
                kind: .solidColor(RenderRGBAColor(red: 0, green: 0, blue: 0, alpha: 0))
            ))
            return transparentID
        }
        return prepared
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

    func appendMasks(_ masks: [ProjectMask], input: VertexID, path: [String]) throws -> VertexID {
        let definitions = try masks.map { mask -> RenderMaskDefinition in
            let segments = try mask.flattenedSegments().map { segment in
                RenderMaskSegment(
                    start: RenderMaskPoint(x: segment.start.x, y: segment.start.y),
                    end: RenderMaskPoint(x: segment.end.x, y: segment.end.y)
                )
            }
            return RenderMaskDefinition(
                segments: segments,
                mode: renderMaskMode(mask.mode),
                opacity: mask.opacity,
                featherPixels: mask.featherPixels,
                expansionPixels: mask.expansionPixels,
                inverted: mask.inverted,
                enabled: mask.enabled
            )
        }
        let stack = try RenderMaskStack(masks: definitions).validated()
        let maskID = try nodeID(path: path, role: "mask")
        try append(RenderNode(id: maskID, dependencies: [input], kind: .mask(stack)))
        return maskID
    }

    func appendLayerOperations(
        _ layer: ProjectLayer,
        transform: LayerTransform,
        input: VertexID,
        path: [String]
    ) throws -> VertexID {
        let operationID = try nodeID(path: path, role: "operations")
        let renderTransform = RenderTransform2D(
            positionX: transform.positionX,
            positionY: transform.positionY,
            anchorX: transform.anchorX,
            anchorY: transform.anchorY,
            scaleX: transform.scaleX,
            scaleY: transform.scaleY,
            rotationDegrees: transform.rotationDegrees
        )
        var operations: [RenderOperation] = [.transform2D(renderTransform)]
        operations.append(contentsOf: renderOperations(layer.operations))
        operations.append(.opacity(transform.opacity))
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
            domain: "vertex.phase8.render-node",
            components: [project.projectID.rawValue] + path + [role]
        )
    }

    private func isCompositionSource(_ source: LayerSource) -> Bool {
        if case .composition = source { return true }
        return false
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

    private func renderMaskMode(_ mode: ProjectMaskMode) -> RenderMaskMode {
        switch mode {
        case .add: .add
        case .subtract: .subtract
        case .intersect: .intersect
        case .none: .none
        }
    }

    private func renderTrackMatteMode(_ mode: ProjectTrackMatteMode) -> RenderTrackMatteMode {
        switch mode {
        case .alpha: .alpha
        case .alphaInverted: .alphaInverted
        case .luma: .luma
        case .lumaInverted: .lumaInverted
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
