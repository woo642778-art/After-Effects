import Foundation
import Testing
import VertexComposition
import VertexCore
import VertexMedia
import VertexProject
import VertexRender

private actor V18NodeFrameResolver: CompositionFrameResolver {
    let image: PortableImage
    init() throws { image = try PortableImage(data: Data([1]), format: .png, pixelSize: VertexSize(width: 16, height: 16)) }
    func resolve(mediaID: VertexID, exactSourceTime: RationalTime, targetSize: VertexSize) async throws -> CompositionFrameResolution { .frame(image) }
}

@Test("V18 solid and transform nodes lower into shared RenderGraph")
func v18NodeGraphUsesSharedRenderGraph() async throws {
    var project = try ProjectDocument.makeFixture(timestamp: Date(timeIntervalSince1970: 1_700_000_000), media: [])
    let compositionID = try #require(project.activeCompositionID)
    let solid = ProjectNode(name: "Solid", kind: .solidColor(.black), position: .zero)
    let transform = ProjectNode(name: "Transform", kind: .transform(.identity), position: .init(x: 220, y: 0))
    let output = ProjectNode(name: "Output", kind: .output, position: .init(x: 440, y: 0))
    let graph = ProjectNodeGraph(compositionID: compositionID, nodes: [solid, transform, output], connections: [
        .init(from: .init(nodeID: solid.id, portID: "image"), to: .init(nodeID: transform.id, portID: "image")),
        .init(from: .init(nodeID: transform.id, portID: "image"), to: .init(nodeID: output.id, portID: "image"))
    ])
    let index = try #require(project.compositionRegistry.firstIndex(where: { $0.id == compositionID }))
    project.compositionRegistry[index].nodeGraph = graph
    project = try project.validated()
    let rendered = try await NodeCompositorCompiler().compile(CompositionRenderRequest(project: project, compositionID: compositionID, time: .zero, output: try RenderOutputSpecification(width: 16, height: 16)), resolver: V18NodeFrameResolver(), cancellationToken: RenderCancellationToken())
    let kinds = try rendered.graph.evaluationPlan().orderedNodes.map(\.kind)
    #expect(kinds.contains { if case .solidColor = $0 { return true }; return false })
    #expect(kinds.contains { if case .operations = $0 { return true }; return false })
    #expect(kinds.last.map { if case .output = $0 { return true }; return false } == true)
}
