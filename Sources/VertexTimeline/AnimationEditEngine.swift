import Foundation
import VertexCore
import VertexProject

public enum ProjectKeyframeEaseCommand: String, Codable, CaseIterable, Sendable {
    case easyEase
    case easeIn
    case easeOut
    case linear
    case hold
}

public struct AnimationEditEngine: Sendable {
    public init() {}

    public func addKeyframe(
        _ keyframe: ProjectKeyframe,
        to channel: ProjectAnimationChannel
    ) throws -> ProjectAnimationChannel {
        var result = channel
        guard !result.keyframes.contains(where: { $0.id == keyframe.id }) else {
            throw ProjectError.duplicateIdentity("keyframe")
        }
        guard !result.keyframes.contains(where: { $0.time == keyframe.time }) else {
            throw ProjectError.invalidOperation("A channel cannot contain two keyframes at the same exact time.")
        }
        result.keyframes.append(keyframe)
        result.keyframes.sort { $0.time < $1.time }
        return try result.validated()
    }

    public func removeKeyframes(
        ids: Set<VertexID>,
        from channel: ProjectAnimationChannel
    ) throws -> ProjectAnimationChannel {
        guard !ids.isEmpty else { return try channel.validated() }
        var result = channel
        result.keyframes.removeAll { ids.contains($0.id) }
        guard !result.keyframes.isEmpty else {
            throw ProjectError.invalidOperation("Removing keyframes cannot leave an animation channel empty.")
        }
        return try result.validated()
    }

    public func moveKeyframes(
        ids: Set<VertexID>,
        by delta: RationalTime,
        in channel: ProjectAnimationChannel
    ) throws -> ProjectAnimationChannel {
        guard !ids.isEmpty else { return try channel.validated() }
        var result = channel
        var found = Set<VertexID>()
        for index in result.keyframes.indices where ids.contains(result.keyframes[index].id) {
            let next = try result.keyframes[index].time.adding(delta)
            guard next >= .zero else {
                throw ProjectError.invalidOperation("Keyframes cannot move before composition time zero.")
            }
            result.keyframes[index].time = next
            found.insert(result.keyframes[index].id)
        }
        guard found == ids else {
            throw ProjectError.invalidOperation("Keyframe edit references a missing keyframe.")
        }
        result.keyframes.sort { $0.time < $1.time }
        return try result.validated()
    }

    public func scaleKeyframeTimes(
        ids: Set<VertexID>,
        anchor: RationalTime,
        factor: Double,
        in channel: ProjectAnimationChannel
    ) throws -> ProjectAnimationChannel {
        guard factor.isFinite, factor > 0 else {
            throw ProjectError.invalidValue("Keyframe time scale must be finite and positive.")
        }
        guard !ids.isEmpty else { return try channel.validated() }
        var result = channel
        var found = Set<VertexID>()
        for index in result.keyframes.indices where ids.contains(result.keyframes[index].id) {
            let offset = try result.keyframes[index].time.subtracting(anchor)
            let scaledSeconds = offset.seconds * factor
            guard scaledSeconds.isFinite else {
                throw ProjectError.invalidOperation("Scaled keyframe time overflowed.")
            }
            let scaled = try rational(seconds: scaledSeconds, preferredTimescale: offset.timescale)
            let next = try anchor.adding(scaled)
            guard next >= .zero else {
                throw ProjectError.invalidOperation("Scaled keyframes cannot move before composition time zero.")
            }
            result.keyframes[index].time = next
            found.insert(result.keyframes[index].id)
        }
        guard found == ids else {
            throw ProjectError.invalidOperation("Keyframe edit references a missing keyframe.")
        }
        result.keyframes.sort { $0.time < $1.time }
        return try result.validated()
    }

    public func applyEase(
        _ ease: ProjectKeyframeEaseCommand,
        keyframeIDs: Set<VertexID>,
        in channel: ProjectAnimationChannel
    ) throws -> ProjectAnimationChannel {
        guard !keyframeIDs.isEmpty else { return try channel.validated() }
        var result = channel
        var found = Set<VertexID>()
        let influence = 100.0 / 3.0

        for index in result.keyframes.indices where keyframeIDs.contains(result.keyframes[index].id) {
            found.insert(result.keyframes[index].id)
            switch ease {
            case .linear:
                result.keyframes[index].interpolation = .linear
                result.keyframes[index].incomingTemporalHandle = nil
                result.keyframes[index].outgoingTemporalHandle = nil
                result.keyframes[index].incomingVelocity = nil
                result.keyframes[index].outgoingVelocity = nil
            case .hold:
                result.keyframes[index].interpolation = .hold
                result.keyframes[index].incomingTemporalHandle = nil
                result.keyframes[index].outgoingTemporalHandle = nil
                result.keyframes[index].incomingVelocity = nil
                result.keyframes[index].outgoingVelocity = nil
                result.keyframes[index].isRoving = false
            case .easyEase:
                result.keyframes[index].interpolation = .cubicBezier
                result.keyframes[index].incomingTemporalHandle = ProjectBezierHandle(x: 2.0 / 3.0, y: 1)
                result.keyframes[index].outgoingTemporalHandle = ProjectBezierHandle(x: 1.0 / 3.0, y: 0)
                result.keyframes[index].incomingVelocity = ProjectKeyframeVelocity(valuePerSecond: 0, influence: influence)
                result.keyframes[index].outgoingVelocity = ProjectKeyframeVelocity(valuePerSecond: 0, influence: influence)
            case .easeIn:
                result.keyframes[index].interpolation = .cubicBezier
                result.keyframes[index].incomingTemporalHandle = ProjectBezierHandle(x: 2.0 / 3.0, y: 1)
                result.keyframes[index].incomingVelocity = ProjectKeyframeVelocity(valuePerSecond: 0, influence: influence)
            case .easeOut:
                result.keyframes[index].interpolation = .cubicBezier
                result.keyframes[index].outgoingTemporalHandle = ProjectBezierHandle(x: 1.0 / 3.0, y: 0)
                result.keyframes[index].outgoingVelocity = ProjectKeyframeVelocity(valuePerSecond: 0, influence: influence)
            }
        }
        guard found == keyframeIDs else {
            throw ProjectError.invalidOperation("Keyframe ease references a missing keyframe.")
        }
        return try result.validated()
    }

    private func rational(seconds: Double, preferredTimescale: Int32) throws -> RationalTime {
        let scale = max(1, preferredTimescale)
        let scaled = (seconds * Double(scale)).rounded()
        guard scaled >= Double(Int64.min), scaled <= Double(Int64.max) else {
            throw ProjectError.invalidOperation("Keyframe time conversion overflowed.")
        }
        return RationalTime(value: Int64(scaled), timescale: scale)
    }
}
