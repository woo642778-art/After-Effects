#if canImport(Vision) && canImport(AVFoundation)
import Testing
import VertexCore
import VertexProject
@testable import VertexTrackingVision

@Test("Vision and project tracking rectangles round trip coordinate origins")
func trackingCoordinateRoundTrip() throws {
    let project = try ProjectTrackingRegion(x: 0.17, y: 0.23, width: 0.31, height: 0.29).validated()
    let vision = VisionMotionTracker.visionRegion(fromProject: project)
    #expect(abs(vision.origin.x - 0.17) < 1e-12)
    #expect(abs(vision.origin.y - 0.48) < 1e-12)
    let roundTrip = try VisionMotionTracker.projectRegion(fromVision: vision).validated()
    #expect(abs(roundTrip.x - project.x) < 1e-12)
    #expect(abs(roundTrip.y - project.y) < 1e-12)
    #expect(abs(roundTrip.width - project.width) < 1e-12)
    #expect(abs(roundTrip.height - project.height) < 1e-12)
}

@Test("Tracking source-time mapping matches layer start, source start, and source offset semantics")
func trackingSourceTimeMappingWithoutRemap() throws {
    let layer = ProjectLayer(
        compositionID: VertexID(rawValue: "14000000-0000-0000-0000-000000000010"),
        name: "Tracked Media",
        source: .media(
            mediaID: VertexID(rawValue: "14000000-0000-0000-0000-000000000011"),
            sourceStartTime: RationalTime(value: 2, timescale: 1)
        ),
        timing: LayerTiming(
            startTime: RationalTime(value: 5, timescale: 1),
            inPoint: RationalTime(value: 5, timescale: 1),
            outPoint: RationalTime(value: 8, timescale: 1),
            sourceOffset: RationalTime(value: 1, timescale: 1)
        )
    )
    let compositionTimes = [5, 6, 7].map { RationalTime(value: Int64($0), timescale: 1) }
    let sourceTimes = try TrackingSourceTimeMapper.sourceTimes(for: layer, compositionTimes: compositionTimes)
    #expect(sourceTimes == [
        RationalTime(value: 3, timescale: 1),
        RationalTime(value: 4, timescale: 1),
        RationalTime(value: 5, timescale: 1)
    ])
}

@Test("Tracking source-time mapping uses layer-local time remap and preserves composition sample times")
func trackingSourceTimeMappingWithRemap() throws {
    let remap = ProjectTimeRemap(keyframes: [
        .init(compositionTime: .zero, sourceTime: RationalTime(value: 10, timescale: 1)),
        .init(compositionTime: RationalTime(value: 2, timescale: 1), sourceTime: RationalTime(value: 14, timescale: 1))
    ])
    let layer = ProjectLayer(
        compositionID: VertexID(rawValue: "14000000-0000-0000-0000-000000000020"),
        name: "Remapped Media",
        source: .media(
            mediaID: VertexID(rawValue: "14000000-0000-0000-0000-000000000021"),
            sourceStartTime: RationalTime(value: 99, timescale: 1)
        ),
        timing: LayerTiming(
            startTime: RationalTime(value: 5, timescale: 1),
            inPoint: RationalTime(value: 5, timescale: 1),
            outPoint: RationalTime(value: 8, timescale: 1),
            sourceOffset: RationalTime(value: 7, timescale: 1),
            timeRemap: remap
        )
    )
    let compositionTimes = [5, 6, 7].map { RationalTime(value: Int64($0), timescale: 1) }
    let sourceTimes = try TrackingSourceTimeMapper.sourceTimes(for: layer, compositionTimes: compositionTimes)
    #expect(sourceTimes == [
        RationalTime(value: 10, timescale: 1),
        RationalTime(value: 12, timescale: 1),
        RationalTime(value: 14, timescale: 1)
    ])
    #expect(compositionTimes == [
        RationalTime(value: 5, timescale: 1),
        RationalTime(value: 6, timescale: 1),
        RationalTime(value: 7, timescale: 1)
    ])
}

@Test("Tracking decode timeline rejects mismatched and negative explicit source times")
func trackingDecodeTimelineValidation() throws {
    let compositionTimes = [.zero, RationalTime(value: 1, timescale: 1)]
    #expect(throws: Error.self) {
        try VisionMotionTracker.validatedDecodeTimes(
            compositionTimes: compositionTimes,
            sourceTimes: [.zero]
        )
    }
    #expect(throws: Error.self) {
        try VisionMotionTracker.validatedDecodeTimes(
            compositionTimes: compositionTimes,
            sourceTimes: [.zero, RationalTime(value: -1, timescale: 1)]
        )
    }
    #expect(try VisionMotionTracker.validatedDecodeTimes(
        compositionTimes: compositionTimes,
        sourceTimes: [RationalTime(value: 3, timescale: 1), RationalTime(value: 4, timescale: 1)]
    ) == [RationalTime(value: 3, timescale: 1), RationalTime(value: 4, timescale: 1)])
}
#endif
