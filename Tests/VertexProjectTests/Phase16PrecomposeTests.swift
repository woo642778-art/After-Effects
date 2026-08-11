import Foundation
import Testing
import VertexCore
@testable import VertexProject

private func makePrecomposeFixture() throws -> (ProjectDocument, ProjectComposition, ProjectLayer, ProjectLayer) {
    var document = try ProjectDocument.makeFixture(timestamp: Date(timeIntervalSince1970: 1_700_000_000), media: [])
    let media = MediaReference.fixture(id: "66000000-0000-0000-0000-000000000010")
    document.mediaRegistry = [media]
    var composition = document.compositionRegistry[0]
    composition.duration = RationalTime(value: 12, timescale: 1)

    let first = ProjectLayer(
        id: VertexID(rawValue: "66000000-0000-0000-0000-000000000021"),
        compositionID: composition.id,
        name: "First",
        source: .media(mediaID: media.id, sourceStartTime: .zero),
        timing: LayerTiming(
            startTime: RationalTime(value: 2, timescale: 1),
            inPoint: RationalTime(value: 2, timescale: 1),
            outPoint: RationalTime(value: 6, timescale: 1)
        )
    )
    let second = ProjectLayer(
        id: VertexID(rawValue: "66000000-0000-0000-0000-000000000022"),
        compositionID: composition.id,
        name: "Second",
        source: .media(mediaID: media.id, sourceStartTime: RationalTime(value: 1, timescale: 1)),
        timing: LayerTiming(
            startTime: RationalTime(value: 4, timescale: 1),
            inPoint: RationalTime(value: 4, timescale: 1),
            outPoint: RationalTime(value: 8, timescale: 1)
        )
    )
    composition.layerIDs = [first.id, second.id]
    document.compositionRegistry = [composition]
    document.layerRegistry = [first, second]
    document.activeCompositionID = composition.id
    document.selectedLayerID = first.id
    return (try document.validated(), composition, first, second)
}

@Test("Precompose planner preserves selected Z-order and exact relative timing")
func phase16PrecomposePreservesOrderingAndTiming() throws {
    let (document, composition, first, second) = try makePrecomposeFixture()
    let newCompositionID = VertexID(rawValue: "66000000-0000-0000-0000-000000000100")
    let plan = try ProjectPrecomposePlanner.plan(
        document: document,
        compositionID: composition.id,
        layerIDs: [first.id, second.id],
        newCompositionID: newCompositionID,
        name: "Pre-comp 1"
    )

    #expect(plan.sourceLayerIDs == [first.id, second.id])
    #expect(plan.insertionIndex == 0)
    #expect(plan.childComposition.id == newCompositionID)
    #expect(plan.childComposition.layerIDs == plan.childLayers.map(\.id))
    #expect(plan.childLayers.map(\.name) == ["First", "Second"])
    #expect(plan.childLayers[0].timing.startTime == .zero)
    #expect(plan.childLayers[1].timing.startTime == RationalTime(value: 2, timescale: 1))
    #expect(plan.childLayers[0].timing.inPoint == .zero)
    #expect(plan.childLayers[1].timing.inPoint == RationalTime(value: 2, timescale: 1))
    #expect(plan.childLayers[1].timing.outPoint == RationalTime(value: 6, timescale: 1))
    #expect(plan.nestedLayer.timing.startTime == RationalTime(value: 2, timescale: 1))
    #expect(plan.nestedLayer.timing.inPoint == RationalTime(value: 2, timescale: 1))
    #expect(plan.nestedLayer.timing.outPoint == RationalTime(value: 8, timescale: 1))
    #expect(plan.childComposition.duration == RationalTime(value: 6, timescale: 1))
    #expect(plan.nestedLayer.source == .composition(compositionID: newCompositionID, sourceStartTime: .zero))
}

@Test("Precompose rejects external parenting dependencies but remaps internal parents")
func phase16PrecomposeRejectsUnsafeDependencies() throws {
    var (document, composition, first, second) = try makePrecomposeFixture()
    second.parentLayerID = first.id
    document.layerRegistry = [first, second]
    document = try document.validated()

    let safePlan = try ProjectPrecomposePlanner.plan(
        document: document,
        compositionID: composition.id,
        layerIDs: [first.id, second.id],
        newCompositionID: VertexID(rawValue: "66000000-0000-0000-0000-000000000101"),
        name: "Safe Parent Precomp"
    )
    #expect(safePlan.childLayers[1].parentLayerID == safePlan.childLayers[0].id)

    #expect(throws: ProjectError.self) {
        _ = try ProjectPrecomposePlanner.plan(
            document: document,
            compositionID: composition.id,
            layerIDs: [second.id],
            newCompositionID: VertexID(rawValue: "66000000-0000-0000-0000-000000000102"),
            name: "Unsafe External Parent"
        )
    }
}
