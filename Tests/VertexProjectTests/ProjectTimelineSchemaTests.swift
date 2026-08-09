import Foundation
import Testing
import VertexCore
@testable import VertexProject

@Suite("Schema 5 timeline primitives")
struct ProjectTimelineSchemaTests {
    @Test func layerTimingSeparatesCompositionPlacementFromSourceOffset() throws {
        let timing = LayerTiming(
            startTime: RationalTime(value: 30, timescale: 30),
            inPoint: RationalTime(value: 30, timescale: 30),
            outPoint: RationalTime(value: 90, timescale: 30),
            sourceOffset: RationalTime(value: 15, timescale: 30)
        )
        #expect(timing.startTime == RationalTime(value: 1, timescale: 1))
        #expect(timing.sourceOffset == RationalTime(value: 1, timescale: 2))
    }

    @Test func workAreaRequiresOrderedCompositionTimes() throws {
        #expect(throws: ProjectError.self) {
            _ = try ProjectWorkArea(
                start: RationalTime(value: 5, timescale: 1),
                end: RationalTime(value: 4, timescale: 1)
            ).validated(compositionDuration: RationalTime(value: 10, timescale: 1))
        }
    }

    @Test func markerMustRemainInsideComposition() throws {
        #expect(throws: ProjectError.self) {
            _ = try ProjectMarker(
                time: RationalTime(value: 10, timescale: 1),
                name: "End"
            ).validated(compositionDuration: RationalTime(value: 10, timescale: 1))
        }
    }

    @Test func parentCycleIsRejected() throws {
        var document = try ProjectDocument.makeFixture(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            media: []
        )
        let composition = try #require(document.compositionRegistry.first)
        let timing = LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 5, timescale: 1))
        let aID = VertexID(rawValue: "91000000-0000-0000-0000-000000000001")
        let bID = VertexID(rawValue: "91000000-0000-0000-0000-000000000002")
        let a = ProjectLayer(id: aID, compositionID: composition.id, name: "A", source: .null, timing: timing, parentLayerID: bID)
        let b = ProjectLayer(id: bID, compositionID: composition.id, name: "B", source: .null, timing: timing, parentLayerID: aID)
        document.layerRegistry = [a, b]
        document.compositionRegistry[0].layerIDs = [aID, bID]
        #expect(throws: ProjectError.self) { _ = try document.validated() }
    }
}
