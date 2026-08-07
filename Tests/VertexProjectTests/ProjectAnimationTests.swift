import Testing
import VertexCore
@testable import VertexProject

private func scalarKey(
    _ id: String,
    frame: Int64,
    value: Double,
    interpolation: ProjectKeyframeInterpolation,
    incoming: ProjectBezierHandle? = nil,
    outgoing: ProjectBezierHandle? = nil
) -> ProjectKeyframe {
    ProjectKeyframe(
        id: VertexID(rawValue: id),
        time: RationalTime(value: frame, timescale: 30),
        value: .scalar(value),
        interpolation: interpolation,
        incomingTemporalHandle: incoming,
        outgoingTemporalHandle: outgoing
    )
}

@Test("Scalar animation evaluates exact endpoints and linear midpoint")
func scalarAnimationLinearEvaluation() throws {
    let channel = try ProjectAnimationChannel(
        id: VertexID(rawValue: "81000000-0000-0000-0000-000000000001"),
        property: .layer(.positionX),
        keyframes: [
            scalarKey("81000000-0000-0000-0000-000000000011", frame: 0, value: 0.2, interpolation: .linear),
            scalarKey("81000000-0000-0000-0000-000000000012", frame: 30, value: 0.8, interpolation: .linear)
        ]
    ).validated()

    #expect(try channel.evaluatedValue(at: RationalTime(value: 0, timescale: 30)) == .scalar(0.2))
    #expect(try channel.evaluatedValue(at: RationalTime(value: 15, timescale: 30)) == .scalar(0.5))
    #expect(try channel.evaluatedValue(at: RationalTime(value: 30, timescale: 30)) == .scalar(0.8))
    #expect(try channel.evaluatedValue(at: RationalTime(value: 60, timescale: 30)) == .scalar(0.8))
}

@Test("Hold animation preserves previous value until next exact key")
func scalarAnimationHoldEvaluation() throws {
    let channel = try ProjectAnimationChannel(
        id: VertexID(rawValue: "81000000-0000-0000-0000-000000000002"),
        property: .layer(.opacity),
        keyframes: [
            scalarKey("81000000-0000-0000-0000-000000000021", frame: 0, value: 0.25, interpolation: .hold),
            scalarKey("81000000-0000-0000-0000-000000000022", frame: 10, value: 1, interpolation: .hold)
        ]
    ).validated()

    #expect(try channel.evaluatedValue(at: RationalTime(value: 9, timescale: 30)) == .scalar(0.25))
    #expect(try channel.evaluatedValue(at: RationalTime(value: 10, timescale: 30)) == .scalar(1))
}

@Test("Cubic temporal animation respects eased handles and remains bounded")
func scalarAnimationBezierEvaluation() throws {
    let channel = try ProjectAnimationChannel(
        id: VertexID(rawValue: "81000000-0000-0000-0000-000000000003"),
        property: .layer(.rotationDegrees),
        keyframes: [
            scalarKey(
                "81000000-0000-0000-0000-000000000031",
                frame: 0,
                value: 0,
                interpolation: .cubicBezier,
                outgoing: ProjectBezierHandle(x: 0.42, y: 0)
            ),
            scalarKey(
                "81000000-0000-0000-0000-000000000032",
                frame: 30,
                value: 100,
                interpolation: .linear,
                incoming: ProjectBezierHandle(x: 0.58, y: 1)
            )
        ]
    ).validated()

    guard case .scalar(let value) = try channel.evaluatedValue(at: RationalTime(value: 7, timescale: 30)) else {
        Issue.record("Expected scalar result")
        return
    }
    #expect(value >= 0 && value <= 100)
    #expect(value < 23.5)
}

@Test("Animation rejects duplicate times, duplicate IDs, non-finite values and invalid handles")
func animationValidationFailures() {
    let sharedID = VertexID(rawValue: "81000000-0000-0000-0000-000000000041")
    let duplicateTimes = ProjectAnimationChannel(
        id: VertexID(rawValue: "81000000-0000-0000-0000-000000000004"),
        property: .layer(.positionY),
        keyframes: [
            ProjectKeyframe(id: sharedID, time: .zero, value: .scalar(0), interpolation: .linear),
            ProjectKeyframe(id: VertexID(rawValue: "81000000-0000-0000-0000-000000000042"), time: .zero, value: .scalar(1), interpolation: .linear)
        ]
    )
    #expect(throws: ProjectError.self) { try duplicateTimes.validated() }

    let nonFinite = ProjectAnimationChannel(
        id: VertexID(rawValue: "81000000-0000-0000-0000-000000000005"),
        property: .layer(.positionY),
        keyframes: [ProjectKeyframe(id: sharedID, time: .zero, value: .scalar(.infinity), interpolation: .linear)]
    )
    #expect(throws: ProjectError.self) { try nonFinite.validated() }

    let invalidHandle = ProjectAnimationChannel(
        id: VertexID(rawValue: "81000000-0000-0000-0000-000000000006"),
        property: .layer(.positionY),
        keyframes: [
            ProjectKeyframe(
                id: sharedID,
                time: .zero,
                value: .scalar(0),
                interpolation: .cubicBezier,
                outgoingTemporalHandle: ProjectBezierHandle(x: 1.2, y: 0.5)
            )
        ]
    )
    #expect(throws: ProjectError.self) { try invalidHandle.validated() }
}

@Test("Bezier path animation interpolates matching topology and rejects mismatch")
func bezierPathAnimationTopology() throws {
    let pathA = ProjectBezierPath.rectangle(x: 0.1, y: 0.1, width: 0.4, height: 0.4)
    let pathB = ProjectBezierPath.rectangle(x: 0.3, y: 0.2, width: 0.4, height: 0.4)
    let channel = try ProjectAnimationChannel(
        id: VertexID(rawValue: "81000000-0000-0000-0000-000000000007"),
        property: .mask(
            maskID: VertexID(rawValue: "81000000-0000-0000-0000-000000000071"),
            property: .path
        ),
        keyframes: [
            ProjectKeyframe(
                id: VertexID(rawValue: "81000000-0000-0000-0000-000000000072"),
                time: .zero,
                value: .bezierPath(pathA),
                interpolation: .linear
            ),
            ProjectKeyframe(
                id: VertexID(rawValue: "81000000-0000-0000-0000-000000000073"),
                time: RationalTime(value: 30, timescale: 30),
                value: .bezierPath(pathB),
                interpolation: .linear
            )
        ]
    ).validated()

    guard case .bezierPath(let midpoint) = try channel.evaluatedValue(at: RationalTime(value: 15, timescale: 30)) else {
        Issue.record("Expected path result")
        return
    }
    #expect(abs(midpoint.vertices[0].anchor.x - 0.2) < 0.000_001)

    let triangle = ProjectBezierPath(
        vertices: [
            .init(anchor: .init(x: 0, y: 0)),
            .init(anchor: .init(x: 1, y: 0)),
            .init(anchor: .init(x: 0.5, y: 1))
        ],
        closed: true
    )
    let mismatch = ProjectAnimationChannel(
        id: VertexID(rawValue: "81000000-0000-0000-0000-000000000008"),
        property: .mask(maskID: VertexID(rawValue: "81000000-0000-0000-0000-000000000081"), property: .path),
        keyframes: [
            ProjectKeyframe(id: VertexID(rawValue: "81000000-0000-0000-0000-000000000082"), time: .zero, value: .bezierPath(pathA), interpolation: .linear),
            ProjectKeyframe(id: VertexID(rawValue: "81000000-0000-0000-0000-000000000083"), time: RationalTime(value: 1, timescale: 1), value: .bezierPath(triangle), interpolation: .linear)
        ]
    )
    #expect(throws: ProjectError.self) { try mismatch.validated() }
}
