import Foundation
import VertexCore
import VertexMedia
import VertexProject
import VertexRender

/// Lowers a persisted V18 node graph into the same RenderGraph substrate used by the layer compiler.
/// Control-domain nodes are evaluated deterministically and image-domain nodes are emitted as RenderNodes.
public struct NodeCompositorCompiler: Sendable {
    public static let compilerVersion = 18

    public init() {}

    public func compile(
        _ request: CompositionRenderRequest,
        resolver: any CompositionFrameResolver,
        effectResolver: any CompositionEffectResolver = RejectingCompositionEffectResolver(),
        cancellationToken: RenderCancellationToken
    ) async throws -> RenderRequest {
        let project = try request.project.validated()
        let limits = try request.limits.validated()
        guard request.time >= .zero else {
            throw CompositionError.invalidTimingRange("Requested node-compositor time must be nonnegative.")
        }
        guard let composition = project.composition(id: request.compositionID) else {
            throw CompositionError.missingComposition(request.compositionID.rawValue)
        }
        guard request.time < composition.duration else {
            throw CompositionError.invalidTimingRange("Requested node-compositor time is outside the composition duration.")
        }
        guard let graph = composition.nodeGraph else {
            throw CompositionError.graphCompilationFailed("The composition has no V18 node graph.")
        }
        guard graph.compositionID == composition.id else {
            throw CompositionError.graphCompilationFailed("The node graph belongs to another composition.")
        }

        let plan = try graph.evaluationPlan()
        guard plan.orderedNodes.count <= limits.maximumExpandedNodes else {
            throw CompositionError.nodeLimitExceeded(plan.orderedNodes.count)
        }

        var state = LoweringState(
            project: project,
            composition: composition,
            graph: graph,
            request: request,
            resolver: resolver,
            effectResolver: effectResolver,
            cancellationToken: cancellationToken
        )
        try await state.lower(plan: plan)
        try await cancellationToken.throwIfCancelled()

        do {
            return try RenderRequest(
                graph: RenderGraph(nodes: state.renderNodes),
                time: request.time,
                output: request.output,
                context: RenderCacheContext(
                    compositionID: composition.id,
                    projectRevision: project.revision,
                    compilerVersion: Self.compilerVersion
                )
            )
        } catch let error as RenderError {
            throw CompositionError.graphCompilationFailed(error.localizedDescription)
        }
    }
}

private struct LoweringState: Sendable {
    let project: ProjectDocument
    let composition: ProjectComposition
    let graph: ProjectNodeGraph
    let request: CompositionRenderRequest
    let resolver: any CompositionFrameResolver
    let effectResolver: any CompositionEffectResolver
    let cancellationToken: RenderCancellationToken

    var renderNodes: [RenderNode] = []
    var renderOutputByNode: [VertexID: VertexID] = [:]
    var scalarOutputByNode: [VertexID: Double] = [:]

    mutating func lower(plan: ProjectNodeEvaluationPlan) async throws {
        for node in plan.orderedNodes {
            try await cancellationToken.throwIfCancelled()
            switch node.kind {
            case .utility(let utility):
                try lowerUtility(node, utility: utility)
            case .math(let operation):
                try lowerMath(node, operation: operation)
            case .macroInput, .macroOutput:
                throw CompositionError.graphCompilationFailed("Macro boundary nodes must be expanded before root graph lowering.")
            default:
                try await lowerImageNode(node)
            }
        }
    }

    mutating func lowerImageNode(_ node: ProjectNode) async throws {
        if (!node.enabled || node.bypassed), let input = imageDependency(nodeID: node.id, portID: "image") {
            renderOutputByNode[node.id] = input
            return
        }

        switch node.kind {
        case .solidColor(let color):
            append(RenderNode(id: node.id, dependencies: [], kind: .solidColor(renderColor(color))))
            renderOutputByNode[node.id] = node.id

        case .mediaInput(let mediaID):
            guard project.mediaRegistry.contains(where: { $0.id == mediaID }) else {
                throw CompositionError.missingMedia(mediaID.rawValue)
            }
            let result: CompositionFrameResolution
            do {
                result = try await resolver.resolve(
                    mediaID: mediaID,
                    exactSourceTime: request.time,
                    targetSize: VertexSize(width: Double(request.output.width), height: Double(request.output.height))
                )
            } catch {
                throw CompositionError.frameResolutionFailed(error.localizedDescription)
            }
            switch result {
            case .frame(let image):
                append(RenderNode(id: node.id, dependencies: [], kind: .source(image)))
            case .transparent:
                append(RenderNode(id: node.id, dependencies: [], kind: .solidColor(.transparent)))
            }
            renderOutputByNode[node.id] = node.id

        case .transform(let transform):
            let input = try requiredImageDependency(node.id, "image")
            let resolved = try linkedTransform(nodeID: node.id, base: transform)
            var operations: [RenderOperation] = [
                .transform2D(RenderTransform2D(
                    positionX: resolved.positionX,
                    positionY: resolved.positionY,
                    anchorX: resolved.anchorX,
                    anchorY: resolved.anchorY,
                    scaleX: resolved.scaleX,
                    scaleY: resolved.scaleY,
                    rotationDegrees: resolved.rotationDegrees
                ))
            ]
            if resolved.opacity != 1 { operations.append(.opacity(resolved.opacity)) }
            append(RenderNode(id: node.id, dependencies: [input], kind: .operations(operations)))
            renderOutputByNode[node.id] = node.id

        case .maskStack(let masks):
            let input = try requiredImageDependency(node.id, "image")
            append(RenderNode(id: node.id, dependencies: [input], kind: .mask(try renderMaskStack(masks))))
            renderOutputByNode[node.id] = node.id

        case .matte(let mode):
            let image = try requiredImageDependency(node.id, "image")
            let matte = try requiredImageDependency(node.id, "matte")
            append(RenderNode(id: node.id, dependencies: [image, matte], kind: .matte(renderMatte(mode))))
            renderOutputByNode[node.id] = node.id

        case .merge(let mode):
            let background = try requiredImageDependency(node.id, "background")
            let foreground = try requiredImageDependency(node.id, "foreground")
            append(RenderNode(id: node.id, dependencies: [background, foreground], kind: .composite(renderBlend(mode))))
            renderOutputByNode[node.id] = node.id

        case .output:
            let input = try requiredImageDependency(node.id, "image")
            append(RenderNode(id: node.id, dependencies: [input], kind: .output))
            renderOutputByNode[node.id] = node.id

        case .layerInput(let layerID):
            try await lowerLayerInput(node, layerID: layerID)

        case .compositionInput(let compositionID):
            try await lowerCompositionInput(node, compositionID: compositionID)

        case .effect(let effect):
            try await lowerMaterializedEffect(node, effect: effect)

        case .macro(let macroID):
            throw CompositionError.graphCompilationFailed("Macro \(macroID.rawValue) must be expanded before image lowering.")

        case .math, .utility, .macroInput, .macroOutput:
            break
        }
    }

    /// Layer inputs intentionally reuse CompositionGraphCompiler rather than a second layer renderer.
    /// The subgraph is spliced without its terminal output node and IDs are deterministically namespaced.
    mutating func lowerLayerInput(_ node: ProjectNode, layerID: VertexID) async throws {
        guard let layer = project.layer(id: layerID), layer.compositionID == composition.id else {
            throw CompositionError.missingLayer(layerID.rawValue)
        }
        // V18 layer-input semantics are the layer's source pixels at the current composition time.
        // Media sources use the shared frame resolver directly; nested sources use the shared composition compiler.
        switch layer.source {
        case .media(let mediaID, let sourceStartTime):
            let local = try request.time.subtracting(layer.timing.startTime)
            let sourceTime = try local.adding(sourceStartTime).adding(layer.timing.sourceOffset)
            guard sourceTime >= .zero else {
                append(RenderNode(id: node.id, dependencies: [], kind: .solidColor(.transparent)))
                renderOutputByNode[node.id] = node.id
                return
            }
            let resolution = try await resolver.resolve(
                mediaID: mediaID,
                exactSourceTime: sourceTime,
                targetSize: VertexSize(width: Double(request.output.width), height: Double(request.output.height))
            )
            switch resolution {
            case .frame(let image): append(RenderNode(id: node.id, dependencies: [], kind: .source(image)))
            case .transparent: append(RenderNode(id: node.id, dependencies: [], kind: .solidColor(.transparent)))
            }
            renderOutputByNode[node.id] = node.id
        case .composition(let childID, _):
            try await lowerCompositionInput(node, compositionID: childID)
        case .adjustment, .null, .guide, .camera, .light:
            append(RenderNode(id: node.id, dependencies: [], kind: .solidColor(.transparent)))
            renderOutputByNode[node.id] = node.id
        }
    }

    mutating func lowerCompositionInput(_ node: ProjectNode, compositionID: VertexID) async throws {
        guard compositionID != composition.id else {
            throw CompositionError.nestedCompositionCycle([composition.id.rawValue, composition.id.rawValue])
        }
        guard let child = project.composition(id: compositionID), request.time < child.duration else {
            append(RenderNode(id: node.id, dependencies: [], kind: .solidColor(.transparent)))
            renderOutputByNode[node.id] = node.id
            return
        }
        let compiled = try await CompositionGraphCompiler().compile(
            CompositionRenderRequest(
                project: project,
                compositionID: compositionID,
                time: request.time,
                output: request.output,
                limits: request.limits,
                purpose: request.purpose
            ),
            resolver: resolver,
            effectResolver: effectResolver,
            cancellationToken: cancellationToken
        )
        let plan = try compiled.graph.evaluationPlan()
        var remap: [VertexID: VertexID] = [:]
        for renderNode in plan.orderedNodes {
            remap[renderNode.id] = try DeterministicVertexID.derive(
                domain: "vertex18.node-compositor.nested",
                components: [composition.id.rawValue, node.id.rawValue, renderNode.id.rawValue]
            )
        }
        for renderNode in plan.orderedNodes {
            if case .output = renderNode.kind { continue }
            let id = try required(remap[renderNode.id], "Missing nested render-node remap.")
            let dependencies = try renderNode.dependencies.map { dependency in
                try required(remap[dependency], "Missing nested render dependency remap.")
            }
            append(RenderNode(id: id, dependencies: dependencies, kind: renderNode.kind))
        }
        guard let childOutput = plan.orderedNodes.first(where: { if case .output = $0.kind { return true }; return false }),
              let childSource = childOutput.dependencies.first,
              let loweredSource = remap[childSource] else {
            throw CompositionError.graphCompilationFailed("Nested composition did not produce an image node.")
        }
        renderOutputByNode[node.id] = loweredSource
    }

    /// Effect nodes preserve the existing effect resolver contract for source-materialized inputs.
    /// Graph-domain effects after merge/transform are rejected rather than silently producing a fake result.
    mutating func lowerMaterializedEffect(_ node: ProjectNode, effect: ProjectEffect) async throws {
        let connection = try required(graph.incomingConnection(nodeID: node.id, portID: "image"), "Effect node is missing its image input.")
        guard let sourceNode = graph.node(id: connection.from.nodeID) else {
            throw CompositionError.graphCompilationFailed("Effect input node is missing.")
        }
        let inputImage: PortableImage
        switch sourceNode.kind {
        case .mediaInput(let mediaID):
            let resolution = try await resolver.resolve(
                mediaID: mediaID,
                exactSourceTime: request.time,
                targetSize: VertexSize(width: Double(request.output.width), height: Double(request.output.height))
            )
            guard case .frame(let image) = resolution else {
                append(RenderNode(id: node.id, dependencies: [], kind: .solidColor(.transparent)))
                renderOutputByNode[node.id] = node.id
                return
            }
            inputImage = image
        default:
            throw CompositionError.graphCompilationFailed("Effect nodes currently require a directly materialized Media Input; merge/transform output cannot be re-materialized before the shared renderer executes.")
        }
        let resolvedEffect = try linkedEffect(nodeID: node.id, base: effect)
        let image = try await effectResolver.resolve(CompositionEffectRequest(
            projectID: project.projectID,
            projectRevision: project.revision,
            compositionID: composition.id,
            layerID: node.id,
            effect: resolvedEffect,
            exactCompositionTime: request.time,
            exactSourceTime: request.time,
            input: inputImage,
            targetSize: VertexSize(width: Double(request.output.width), height: Double(request.output.height)),
            purpose: request.purpose
        ))
        append(RenderNode(id: node.id, dependencies: [], kind: .source(image)))
        renderOutputByNode[node.id] = node.id
    }

    mutating func lowerUtility(_ node: ProjectNode, utility: ProjectNodeUtility) throws {
        switch utility {
        case .constant(let value):
            scalarOutputByNode[node.id] = value
        case .clamp(let minimum, let maximum):
            scalarOutputByNode[node.id] = min(max(try requiredScalarInput(node.id, "value"), minimum), maximum)
        case .remap(let inputMinimum, let inputMaximum, let outputMinimum, let outputMaximum):
            let value = try requiredScalarInput(node.id, "value")
            let t = (value - inputMinimum) / (inputMaximum - inputMinimum)
            scalarOutputByNode[node.id] = outputMinimum + t * (outputMaximum - outputMinimum)
        case .boolean:
            break
        }
    }

    mutating func lowerMath(_ node: ProjectNode, operation: ProjectNodeMathOperation) throws {
        let a = try requiredScalarInput(node.id, "a")
        let b = try requiredScalarInput(node.id, "b")
        let value: Double
        switch operation {
        case .add: value = a + b
        case .subtract: value = a - b
        case .multiply: value = a * b
        case .divide:
            guard b != 0 else { throw CompositionError.graphCompilationFailed("Node math division by zero.") }
            value = a / b
        case .minimum: value = min(a, b)
        case .maximum: value = max(a, b)
        }
        guard value.isFinite else { throw CompositionError.graphCompilationFailed("Node math produced a non-finite scalar.") }
        scalarOutputByNode[node.id] = value
    }

    func imageDependency(nodeID: VertexID, portID: String) -> VertexID? {
        guard let connection = graph.incomingConnection(nodeID: nodeID, portID: portID) else { return nil }
        return renderOutputByNode[connection.from.nodeID]
    }

    func requiredImageDependency(_ nodeID: VertexID, _ portID: String) throws -> VertexID {
        try required(imageDependency(nodeID: nodeID, portID: portID), "Node image input \(portID) is not available.")
    }

    func requiredScalarInput(_ nodeID: VertexID, _ portID: String) throws -> Double {
        guard let connection = graph.incomingConnection(nodeID: nodeID, portID: portID),
              let value = scalarOutputByNode[connection.from.nodeID] else {
            throw CompositionError.graphCompilationFailed("Node scalar input \(portID) is not available.")
        }
        return value
    }

    func linkedScalar(nodeID: VertexID, parameterID: String) -> Double? {
        guard let link = graph.parameterLinks.first(where: { $0.target.nodeID == nodeID && $0.target.parameterID == parameterID }),
              let source = scalarOutputByNode[link.source.nodeID] else { return nil }
        let result = source * link.scale + link.offset
        return result.isFinite ? result : nil
    }

    func linkedTransform(nodeID: VertexID, base: LayerTransform) throws -> LayerTransform {
        var result = base
        if let value = linkedScalar(nodeID: nodeID, parameterID: "positionX") { result.positionX = value }
        if let value = linkedScalar(nodeID: nodeID, parameterID: "positionY") { result.positionY = value }
        if let value = linkedScalar(nodeID: nodeID, parameterID: "anchorX") { result.anchorX = value }
        if let value = linkedScalar(nodeID: nodeID, parameterID: "anchorY") { result.anchorY = value }
        if let value = linkedScalar(nodeID: nodeID, parameterID: "scaleX") { result.scaleX = value }
        if let value = linkedScalar(nodeID: nodeID, parameterID: "scaleY") { result.scaleY = value }
        if let value = linkedScalar(nodeID: nodeID, parameterID: "rotationDegrees") { result.rotationDegrees = value }
        if let value = linkedScalar(nodeID: nodeID, parameterID: "opacity") { result.opacity = value }
        return try result.validated()
    }

    func linkedEffect(nodeID: VertexID, base: ProjectEffect) throws -> ProjectEffect {
        var result = base
        for link in graph.parameterLinks where link.target.nodeID == nodeID {
            guard let source = scalarOutputByNode[link.source.nodeID] else { continue }
            try result.setParameter(id: link.target.parameterID, value: .scalar(source * link.scale + link.offset))
        }
        return try result.validated()
    }

    func renderMaskStack(_ masks: [ProjectMask]) throws -> RenderMaskStack {
        let definitions = try masks.map { mask in
            RenderMaskDefinition(
                segments: try mask.flattenedSegments().map {
                    RenderMaskSegment(
                        start: RenderMaskPoint(x: $0.start.x, y: $0.start.y),
                        end: RenderMaskPoint(x: $0.end.x, y: $0.end.y)
                    )
                },
                mode: renderMaskMode(mask.mode),
                opacity: mask.opacity,
                featherPixels: mask.featherPixels,
                expansionPixels: mask.expansionPixels,
                inverted: mask.inverted,
                enabled: mask.enabled
            )
        }
        return try RenderMaskStack(masks: definitions).validated()
    }

    func renderColor(_ color: ProjectRGBAColor) -> RenderRGBAColor {
        RenderRGBAColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    func renderBlend(_ mode: LayerBlendMode) -> RenderBlendMode {
        switch mode {
        case .normal: .normal
        case .add: .add
        case .multiply: .multiply
        case .screen: .screen
        }
    }

    func renderMatte(_ mode: ProjectTrackMatteMode) -> RenderTrackMatteMode {
        switch mode {
        case .alpha: .alpha
        case .alphaInverted: .alphaInverted
        case .luma: .luma
        case .lumaInverted: .lumaInverted
        }
    }

    func renderMaskMode(_ mode: ProjectMaskMode) -> RenderMaskMode {
        switch mode {
        case .add: .add
        case .subtract: .subtract
        case .intersect: .intersect
        case .none: .none
        }
    }

    mutating func append(_ node: RenderNode) {
        renderNodes.append(node)
    }

    func required<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw CompositionError.graphCompilationFailed(message) }
        return value
    }
}
