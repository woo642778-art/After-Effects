import Testing
@testable import VertexProject

@Test("Tracking request produces exact project frame sampling including requested end")
func trackingRequestSampleTimes() throws {
    let request = ProjectTrackingAnalysisRequest(
        kind: .object,
        region: .init(x: 0.2, y: 0.2, width: 0.3, height: 0.3),
        startTime: .zero,
        endTime: RationalTime(value: 1, timescale: 10),
        frameRate: RationalTime(value: 30, timescale: 1),
        frameStride: 2
    )
    let times = try request.sampleTimes()
    #expect(times == [
        .zero,
        RationalTime(value: 1, timescale: 15),
        RationalTime(value: 1, timescale: 10)
    ])
    _ = try request.validated()
}

@Test("Rotoscope propagation follows translation scale and refinement overrides")
func rotoscopePropagationAndRefinement() throws {
    let track = ProjectMotionTrack(name: "Planar", kind: .planar, samples: [
        .init(
            time: .zero,
            region: .init(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
            confidence: 1
        ),
        .init(
            time: RationalTime(value: 1, timescale: 1),
            region: .init(x: 0.3, y: 0.25, width: 0.4, height: 0.4),
            confidence: 1
        )
    ])
    let reference = ProjectBezierPath.rectangle(x: 0.2, y: 0.2, width: 0.2, height: 0.2)
    let refinementPath = ProjectBezierPath.rectangle(x: 0.1, y: 0.1, width: 0.1, height: 0.1)

    let propagated = try track.propagatedRotoscope(name: "Subject", referencePath: reference)
    let last = try #require(propagated.keyframes.last)
    let firstVertex = try #require(last.path.vertices.first)
    #expect(abs(firstVertex.anchor.x - 0.2) < 1e-12)
    #expect(abs(firstVertex.anchor.y - 0.15) < 1e-12)

    let refined = try track.propagatedRotoscope(
        name: "Subject",
        referencePath: reference,
        refinements: [.init(time: RationalTime(value: 1, timescale: 1), path: refinementPath)]
    )
    #expect(refined.keyframes.last?.path == refinementPath)
}

@Test("Tracking request rejects runaway sample counts instead of silently truncating")
func trackingRequestMaximumSamples() {
    let request = ProjectTrackingAnalysisRequest(
        kind: .point,
        region: .init(x: 0.1, y: 0.1, width: 0.1, height: 0.1),
        startTime: .zero,
        endTime: RationalTime(value: 10, timescale: 1),
        frameRate: RationalTime(value: 60, timescale: 1),
        maximumSamples: 10
    )
    #expect(throws: Error.self) { try request.validated() }
}
