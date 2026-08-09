import Foundation
import Testing
import VertexCore
import VertexProject
@testable import VertexTimeline

private func phase12TimelineFixture(childUsesDeletedLayerAsParent: Bool = false) throws -> (ProjectDocument, ProjectComposition, ProjectLayer, ProjectLayer, ProjectLayer) {
    let media = MediaReference.fixture(id: "12000000-0000-0000-0000-000000000010")
    var project = try ProjectDocument.makeFixture(
        timestamp: Date(timeIntervalSince1970: 1_700_500_000),
        media: [media]
    )
    var composition = project.compositionRegistry[0]
    composition.duration = RationalTime(value: 10, timescale: 1)

    let first = ProjectLayer(
        id: VertexID(rawValue: "12000000-0000-0000-0000-000000000020"),
        compositionID: composition.id,
        name: "First",
        source: .media(mediaID: media.id, sourceStartTime: .zero),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 2, timescale: 1))
    )
    let deleted = ProjectLayer(
        id: VertexID(rawValue: "12000000-0000-0000-0000-000000000030"),
        compositionID: composition.id,
        name: "Delete",
        source: .media(mediaID: media.id, sourceStartTime: .zero),
        timing: LayerTiming(
            startTime: RationalTime(value: 2, timescale: 1),
            inPoint: RationalTime(value: 2, timescale: 1),
            outPoint: RationalTime(value: 5, timescale: 1)
        )
    )
    let later = ProjectLayer(
        id: VertexID(rawValue: "12000000-0000-0000-0000-000000000040"),
        compositionID: composition.id,
        name: "Later",
        source: .media(mediaID: media.id, sourceStartTime: .zero),
        timing: LayerTiming(
            startTime: RationalTime(value: 5, timescale: 1),
            inPoint: RationalTime(value: 5, timescale: 1),
            outPoint: RationalTime(value: 8, timescale: 1)
        ),
        parentLayerID: childUsesDeletedLayerAsParent ? deleted.id : first.id
    )

    composition.layerIDs = [first.id, deleted.id, later.id]
    project.compositionRegistry = [composition]
    project.layerRegistry = [first, deleted, later]
    return (try project.validated(), composition, first, deleted, later)
}

@Test("Ripple delete removes the target and closes its duration atomically")
func phase12RippleDeleteClosesGapAndPreservesHierarchy() throws {
    let fixture = try phase12TimelineFixture()
    let result = try TimelineEngine().apply(
        .rippleDelete(layerID: fixture.3.id, affectedLayerIDs: [fixture.4.id]),
        to: fixture.0,
        compositionID: fixture.1.id
    )

    #expect(result.removedLayerIDs == [fixture.3.id])
    #expect(result.resultingLayerOrder == [fixture.2.id, fixture.4.id])
    let shifted = try #require(result.updatedLayers.first(where: { $0.id == fixture.4.id }))
    #expect(shifted.timing.startTime == RationalTime(value: 2, timescale: 1))
    #expect(shifted.timing.inPoint == RationalTime(value: 2, timescale: 1))
    #expect(shifted.timing.outPoint == RationalTime(value: 5, timescale: 1))
    #expect(shifted.parentLayerID == fixture.2.id)
}

@Test("Ripple delete refuses to orphan parenting relationships")
func phase12RippleDeleteRejectsReferencedParent() throws {
    let fixture = try phase12TimelineFixture(childUsesDeletedLayerAsParent: true)
    #expect(throws: ProjectError.self) {
        _ = try TimelineEngine().apply(
            .rippleDelete(layerID: fixture.3.id, affectedLayerIDs: [fixture.4.id]),
            to: fixture.0,
            compositionID: fixture.1.id
        )
    }
}
