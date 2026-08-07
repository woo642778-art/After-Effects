import Testing
import VertexCore
@testable import VertexTimeline

@Test("Snap tie breaking is stable and independent of candidate input order")
func snapTieBreakingIsDeterministic() throws {
    let playhead = TimelineSnapCandidate(
        time: RationalTime(value: 49, timescale: 10),
        kind: .playhead,
        ownerID: nil
    )
    let layerOut = TimelineSnapCandidate(
        time: RationalTime(value: 51, timescale: 10),
        kind: .layerOut,
        ownerID: VertexID(rawValue: "93000000-0000-0000-0000-000000000001")
    )
    let proposed = RationalTime(value: 5, timescale: 1)
    let engine = TimelineSnapEngine()
    let a = try engine.snap(
        proposedTime: proposed,
        candidates: [layerOut, playhead],
        thresholdPoints: 20,
        secondsPerPoint: 0.01
    )
    let b = try engine.snap(
        proposedTime: proposed,
        candidates: [playhead, layerOut],
        thresholdPoints: 20,
        secondsPerPoint: 0.01
    )
    #expect(a == b)
    #expect(a.candidate == playhead)
    #expect(a.snappedTime == playhead.time)
}

@Test("Snap tolerance is derived only from supplied timeline scale")
func snapToleranceUsesSecondsPerPoint() throws {
    let candidate = TimelineSnapCandidate(
        time: RationalTime(value: 506, timescale: 100),
        kind: .marker,
        ownerID: nil
    )
    let proposed = RationalTime(value: 5, timescale: 1)
    let engine = TimelineSnapEngine()
    let narrow = try engine.snap(
        proposedTime: proposed,
        candidates: [candidate],
        thresholdPoints: 5,
        secondsPerPoint: 0.01
    )
    let wide = try engine.snap(
        proposedTime: proposed,
        candidates: [candidate],
        thresholdPoints: 5,
        secondsPerPoint: 0.02
    )
    #expect(narrow.candidate == nil)
    #expect(narrow.snappedTime == proposed)
    #expect(wide.candidate == candidate)
}

@Test("Invalid snap scale is rejected")
func invalidSnapScaleIsRejected() throws {
    #expect(throws: TimelineSnapError.self) {
        _ = try TimelineSnapEngine().snap(
            proposedTime: .zero,
            candidates: [],
            thresholdPoints: 5,
            secondsPerPoint: .nan
        )
    }
}
