import Foundation
import VertexCore

public enum ProjectFrameInterpolationMode: String, Codable, CaseIterable, Sendable {
    case nearest
    case frameMix
    case opticalFlow
}

public enum ProjectTimeRemapInterpolation: String, Codable, CaseIterable, Sendable {
    case linear
    case hold
}

public struct ProjectTimeRemapKeyframe: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var compositionTime: RationalTime
    public var sourceTime: RationalTime
    public var interpolation: ProjectTimeRemapInterpolation

    public init(
        id: VertexID = VertexID(),
        compositionTime: RationalTime,
        sourceTime: RationalTime,
        interpolation: ProjectTimeRemapInterpolation = .linear
    ) {
        self.id = id
        self.compositionTime = compositionTime
        self.sourceTime = sourceTime
        self.interpolation = interpolation
    }

    public func validated() throws -> Self {
        guard compositionTime >= .zero, sourceTime >= .zero else {
            throw ProjectError.invalidValue("Time-remap keyframes must use nonnegative exact times.")
        }
        return self
    }
}

public struct ProjectTimeRemap: Codable, Equatable, Sendable {
    public var keyframes: [ProjectTimeRemapKeyframe]
    public var frameInterpolation: ProjectFrameInterpolationMode
    public var preserveAudioPitch: Bool

    public init(
        keyframes: [ProjectTimeRemapKeyframe],
        frameInterpolation: ProjectFrameInterpolationMode = .nearest,
        preserveAudioPitch: Bool = true
    ) {
        self.keyframes = keyframes
        self.frameInterpolation = frameInterpolation
        self.preserveAudioPitch = preserveAudioPitch
    }

    public func validated() throws -> Self {
        guard !keyframes.isEmpty else {
            throw ProjectError.invalidValue("Time Remap requires at least one keyframe.")
        }
        guard Set(keyframes.map(\.id)).count == keyframes.count else {
            throw ProjectError.duplicateIdentity("time-remap keyframe")
        }
        for keyframe in keyframes { _ = try keyframe.validated() }
        for pair in zip(keyframes, keyframes.dropFirst()) {
            guard pair.0.compositionTime < pair.1.compositionTime else {
                throw ProjectError.invalidValue("Time-remap composition times must be strictly increasing.")
            }
        }
        return self
    }

    public static func identity(
        compositionDuration: RationalTime,
        sourceStart: RationalTime = .zero
    ) throws -> ProjectTimeRemap {
        let sourceEnd = try sourceStart.adding(compositionDuration)
        return try ProjectTimeRemap(keyframes: [
            ProjectTimeRemapKeyframe(compositionTime: .zero, sourceTime: sourceStart),
            ProjectTimeRemapKeyframe(compositionTime: compositionDuration, sourceTime: sourceEnd)
        ]).validated()
    }

    public static func freeze(
        compositionDuration: RationalTime,
        sourceTime: RationalTime,
        frameInterpolation: ProjectFrameInterpolationMode = .nearest,
        preserveAudioPitch: Bool = true
    ) throws -> ProjectTimeRemap {
        try ProjectTimeRemap(
            keyframes: [
                ProjectTimeRemapKeyframe(compositionTime: .zero, sourceTime: sourceTime, interpolation: .hold),
                ProjectTimeRemapKeyframe(compositionTime: compositionDuration, sourceTime: sourceTime, interpolation: .hold)
            ],
            frameInterpolation: frameInterpolation,
            preserveAudioPitch: preserveAudioPitch
        ).validated()
    }

    public static func reverse(
        compositionDuration: RationalTime,
        sourceStart: RationalTime,
        sourceDuration: RationalTime,
        frameInterpolation: ProjectFrameInterpolationMode = .nearest,
        preserveAudioPitch: Bool = true
    ) throws -> ProjectTimeRemap {
        try ProjectTimeRemap(
            keyframes: [
                ProjectTimeRemapKeyframe(compositionTime: .zero, sourceTime: try sourceStart.adding(sourceDuration)),
                ProjectTimeRemapKeyframe(compositionTime: compositionDuration, sourceTime: sourceStart)
            ],
            frameInterpolation: frameInterpolation,
            preserveAudioPitch: preserveAudioPitch
        ).validated()
    }
}
