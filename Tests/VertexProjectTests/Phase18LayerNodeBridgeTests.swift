import Foundation
import Testing
import VertexCore
@testable import VertexProject

@Test("V18 layer stacks convert to deterministic editable node graphs")
func v18LayerStackBridgeIsDeterministic() throws {
    var project = try ProjectDocument.makeFixture(timestamp: Date(timeIntervalSince1970: 1_700_000_000), media: [])
    let compositionID = try #require(project.activeCompositionID)
    let mediaA = MediaReference.fixture(id: "81000000-0000-0000-0000-000000000001", name: "A.mov")
    let mediaB = MediaReference.fixture(id: "81000000-0000-0000-0000-000000000002", name: "B.mov")
    project.mediaRegistry = [mediaA, mediaB]
    let bottom = ProjectLayer(
        id: VertexID(rawValue: "81000000-0000-0000-0000-000000000010"),
        compositionID: compositionID,
        name: "Bottom",
        source: .media(mediaID: mediaA.id, sourceStartTime: .zero),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 10, timescale: 1)),
        effects: [ProjectEffect.makeDefault(.exposure)]
    )
    var top = ProjectLayer(
        id: VertexID(rawValue: "81000000-0000-0000-0000-000000000011"),
        compositionID: compositionID,
        name: "Top",
        source: .media(mediaID: mediaB.id, sourceStartTime: .zero),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 10, timescale: 1))
    )
    top.blendMode = .screen
    project.layerRegistry = [bottom, top]
    let index = try #require(project.compositionRegistry.firstIndex(where: { $0.id == compositionID }))
    project.compositionRegistry[index].layerIDs = [top.id, bottom.id]
    project = try project.validated()

    let first = try ProjectNodeGraph.makeFromLayerStack(project: project, compositionID: compositionID)
    let second = try ProjectNodeGraph.makeFromLayerStack(project: project, compositionID: compositionID)
    #expect(first == second)
    _ = try first.validatedStructure()
    #expect(first.nodes.contains { if case .effect(let effect) = $0.kind { return effect.type == .exposure }; return false })
    #expect(first.nodes.contains { if case .merge(.screen) = $0.kind { return true }; return false })
    #expect(first.nodes.last.map { if case .output = $0.kind { return true }; return false } == true)
}
