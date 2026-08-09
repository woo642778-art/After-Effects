import Testing
import VertexCore
import VertexProject
@testable import VertexTimeline

private func phase11ScalarChannel() -> ProjectAnimationChannel {
    ProjectAnimationChannel(
        id: VertexID(rawValue: "c1000000-0000-0000-0000-000000000001"),
        property: .layer(.opacity),
        keyframes: [
            ProjectKeyframe(
                id: VertexID(rawValue: "c1000000-0000-0000-0000-000000000011"),
                time: RationalTime(value: 0, timescale: 30),
                value: .scalar(0),
                interpolation: .linear
            ),
            ProjectKeyframe(
                id: VertexID(rawValue: "c1000000-0000-0000-0000-000000000012"),
                time: RationalTime(value: 30, timescale: 30),
                value: .scalar(1),
                interpolation: .linear
            )
        ]
    )
}

@Test("Phase 11 keyframe velocity validates influence as 0 through 100")
func phase11VelocityValidation() throws {
    #expect(try ProjectKeyframeVelocity(valuePerSecond: 2, influence: 33).validated().influence == 33)
    #expect(throws: ProjectError.self) {
        _ = try ProjectKeyframeVelocity(valuePerSecond: 2, influence: 101).validated()
    }
}

@Test("Animation edit engine moves selected keys exactly and keeps order")
func phase11MoveKeyframesExactly() throws {
    let channel = phase11ScalarChannel()
    let moved = try AnimationEditEngine().moveKeyframes(
        ids: [channel.keyframes[1].id],
        by: RationalTime(value: 15, timescale: 30),
        in: channel
    )

    #expect(moved.keyframes[0].time == RationalTime(value: 0, timescale: 30))
    #expect(moved.keyframes[1].time == RationalTime(value: 45, timescale: 30))
}

@Test("Easy Ease writes canonical cubic bezier velocity metadata")
func phase11EasyEaseIsCanonicalMetadata() throws {
    let channel = phase11ScalarChannel()
    let eased = try AnimationEditEngine().applyEase(
        .easyEase,
        keyframeIDs: Set(channel.keyframes.map(\.id)),
        in: channel
    )

    #expect(eased.keyframes.allSatisfy { $0.interpolation == .cubicBezier })
    #expect(eased.keyframes.allSatisfy { $0.incomingVelocity?.influence == 33.333333333333336 })
    #expect(eased.keyframes.allSatisfy { $0.outgoingVelocity?.influence == 33.333333333333336 })
}

@Test("Graph curve math samples the same canonical evaluator")
func phase11GraphValueMatchesCanonicalEvaluator() throws {
    let channel = phase11ScalarChannel()
    let time = RationalTime(value: 15, timescale: 30)
    let graph = try GraphCurveMath().value(channel: channel, at: time)
    let canonical = try channel.evaluatedValue(at: time)

    #expect(graph == canonical)
}
