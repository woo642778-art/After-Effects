import Foundation
import Testing
import VertexComposition
import VertexCore
import VertexMedia
import VertexProject
import VertexRender

private actor Phase8FrameResolver: CompositionFrameResolver {
    private(set) var countValue = 0

    func resolve(
        mediaID: VertexID,
        exactSourceTime: RationalTime,
        targetSize: VertexSize
    ) async throws -> CompositionFrameResolution {
        countValue += 1
        return .frame(try PortableImage(
            data: Data([1]),
            format: .png,
            pixelSize: targetSize
        ))
    }
}

private func phase8Project() throws -> (ProjectDocument, ProjectComposition, ProjectLayer, ProjectLayer) {
    var project = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "84000000-0000-0000-0000-000000000001"),
        name: "Phase 8 Graph",
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let mediaA = MediaReference.fixture(id: "84000000-0000-0000-0000-000000000010", name: "target.mov")
    let mediaB = MediaReference.fixture(id: "84000000-0000-0000-0000-000000000011", name: "matte.mov")
    project.mediaRegistry = [mediaA, mediaB]
    var composition = project.compositionRegistry[0]
    composition.width = 16
    composition.height = 16
    let timing = LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration)
    var target = ProjectLayer(
        id: VertexID(rawValue: "84000000-0000-0000-0000-000000000021"),
        compositionID: composition.id,
        name: "Target",
        source: .media(mediaID: mediaA.id, sourceStartTime: .zero),
        timing: timing,
        masks: [
            ProjectMask(
                id: VertexID(rawValue: "84000000-0000-0000-0000-000000000031"),
                name: "Rectangle",
                path: .rectangle(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
            )
        ]
    )
    let matte = ProjectLayer(
        id: VertexID(rawValue: "84000000-0000-0000-0000-000000000022"),
        compositionID: composition.id,
        name: "Matte",
        source: .media(mediaID: mediaB.id, sourceStartTime: .zero),
        timing: timing
    )
    target.trackMatte = ProjectTrackMatte(sourceLayerID: matte.id, mode: .alpha)
    composition.layerIDs = [target.id, matte.id]
    project.compositionRegistry = [composition]
    project.layerRegistry = [target, matte]
    project.selectedLayerID = target.id
    project.selectedMediaID = mediaA.id
    return (try project.validated(), composition, target, matte)
}

@Test("A track matte compiles exactly once and matte source is not separately composited")
func trackMatteCompilesExactlyOnce() async throws {
    let (project, composition, _, _) = try phase8Project()
    let resolver = Phase8FrameResolver()
    let request = try CompositionRenderRequest(
        project: project,
        compositionID: composition.id,
        time: .zero,
        output: RenderOutputSpecification(width: 16, height: 16)
    )
    let render = try await CompositionGraphCompiler().compile(
        request,
        resolver: resolver,
        cancellationToken: RenderCancellationToken()
    )
    let plan = try render.graph.evaluationPlan()
    let matteNodes = plan.orderedNodes.filter { if case .matte = $0.kind { return true }; return false }
    let composites = plan.orderedNodes.filter { if case .composite = $0.kind { return true }; return false }
    #expect(matteNodes.count == 1)
    #expect(composites.count == 1)
}

@Test("Mask node is evaluated before target transform operations")
func maskPrecedesTransformOperations() async throws {
    let (project, composition, _, _) = try phase8Project()
    let request = try CompositionRenderRequest(
        project: project,
        compositionID: composition.id,
        time: .zero,
        output: RenderOutputSpecification(width: 16, height: 16)
    )
    let render = try await CompositionGraphCompiler().compile(
        request,
        resolver: Phase8FrameResolver(),
        cancellationToken: RenderCancellationToken()
    )
    let ordered = try render.graph.evaluationPlan().orderedNodes
    let maskIndex = try #require(ordered.firstIndex { if case .mask = $0.kind { return true }; return false })
    let operationsIndex = try #require(ordered.firstIndex { if case .operations = $0.kind { return true }; return false })
    #expect(maskIndex < operationsIndex)
}
