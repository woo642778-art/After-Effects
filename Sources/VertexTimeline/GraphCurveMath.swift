import Foundation
import VertexCore
import VertexProject

public struct GraphCurveMath: Sendable {
    public init() {}

    public func value(
        channel: ProjectAnimationChannel,
        at time: RationalTime
    ) throws -> ProjectAnimatableValue {
        try channel.evaluatedValue(at: time)
    }

    public func scalarSpeed(
        channel: ProjectAnimationChannel,
        at time: RationalTime
    ) throws -> Double {
        guard channel.property.expectedValueKind == .scalar else {
            throw ProjectError.invalidOperation("Speed Graph currently requires a scalar channel.")
        }
        _ = try channel.validated()
        guard channel.keyframes.count >= 2 else { return 0 }

        let surrounding = try derivativeTimes(channel: channel, around: time)
        guard surrounding.left != surrounding.right else { return 0 }
        guard case .scalar(let lhs) = try channel.evaluatedValue(at: surrounding.left),
              case .scalar(let rhs) = try channel.evaluatedValue(at: surrounding.right) else {
            throw ProjectError.invalidOperation("Scalar speed evaluation received a non-scalar value.")
        }
        let duration = try surrounding.right.subtracting(surrounding.left).seconds
        guard duration.isFinite, duration > 0 else { return 0 }
        let speed = (rhs - lhs) / duration
        guard speed.isFinite else {
            throw ProjectError.invalidValue("Graph speed evaluation produced a non-finite value.")
        }
        return speed
    }

    private func derivativeTimes(
        channel: ProjectAnimationChannel,
        around time: RationalTime
    ) throws -> (left: RationalTime, right: RationalTime) {
        let first = channel.keyframes[0].time
        let last = channel.keyframes[channel.keyframes.count - 1].time
        if time <= first {
            return (first, channel.keyframes[1].time)
        }
        if time >= last {
            return (channel.keyframes[channel.keyframes.count - 2].time, last)
        }

        var left = first
        var right = last
        for pair in zip(channel.keyframes, channel.keyframes.dropFirst()) {
            if time >= pair.0.time, time <= pair.1.time {
                left = pair.0.time
                right = pair.1.time
                break
            }
        }

        let duration = try right.subtracting(left)
        let epsilonTimescale = max(Int32(1_000), duration.timescale)
        let epsilon = RationalTime(value: 1, timescale: epsilonTimescale)
        let proposedLeft = (try? time.subtracting(epsilon)) ?? left
        let proposedRight = (try? time.adding(epsilon)) ?? right
        return (
            proposedLeft < left ? left : proposedLeft,
            proposedRight > right ? right : proposedRight
        )
    }
}
