import Testing
import VertexCore
import VertexTimeline
@testable import Vertex

@Test("Timeline drag quantizes to an exact frame delta")
func timelineDragUsesExactTime() throws {
    let id = VertexID(rawValue: "70000000-0000-0000-0000-000000000011")
    let edit = try AETimelineInteractionModel.moveEdit(
        layerIDs: [id],
        dragPoints: 60,
        pixelsPerSecond: 120,
        frameRate: RationalTime(value: 30, timescale: 1)
    )
    #expect(edit == .move(layerIDs: [id], delta: RationalTime(value: 1, timescale: 2)))
}

@Test("Timeline snapping delegates to deterministic snap engine semantics")
func timelineSnapIsDeterministic() throws {
    let owner = VertexID(rawValue: "70000000-0000-0000-0000-000000000012")
    let result = try AETimelineInteractionModel.snappedTime(
        proposed: RationalTime(value: 49, timescale: 100),
        candidates: [.init(time: RationalTime(value: 1, timescale: 2), kind: .layerIn, ownerID: owner)],
        pixelsPerSecond: 100,
        thresholdPoints: 8
    )
    #expect(result == RationalTime(value: 1, timescale: 2))
}

@Test("Split command always uses canonical playhead time")
func timelineSplitUsesPlayhead() {
    let id = VertexID(rawValue: "70000000-0000-0000-0000-000000000013")
    let playhead = RationalTime(value: 37, timescale: 30)
    #expect(AETimelineInteractionModel.splitEdit(layerID: id, playhead: playhead) == .split(layerID: id, at: playhead))
}
