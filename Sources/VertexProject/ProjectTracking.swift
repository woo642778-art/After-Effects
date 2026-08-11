import Foundation
import VertexCore

public enum ProjectTrackingKind: String, Codable, CaseIterable, Sendable {
    case point
    case planar
    case object
    case face
    case body
}

public enum ProjectTrackingApplicationMode: String, Codable, CaseIterable, Sendable {
    case follow
    case stabilize
}

public struct ProjectTrackingRegion: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func validated() throws -> Self {
        let values = [x, y, width, height]
        guard values.allSatisfy(\.isFinite), width > 0, height > 0,
              x >= 0, y >= 0, x + width <= 1, y + height <= 1 else {
            throw ProjectError.invalidValue("Tracking regions must be finite normalized rectangles inside the source frame.")
        }
        return self
    }

    public var center: ProjectVector2 {
        .init(x: x + width / 2, y: y + height / 2)
    }
}

public struct ProjectTrackingSample: Codable, Equatable, Sendable, Identifiable {
    public var id: String { time.description }
    public var time: RationalTime
    public var region: ProjectTrackingRegion
    public var rotationDegrees: Double
    public var confidence: Double

    public init(
        time: RationalTime,
        region: ProjectTrackingRegion,
        rotationDegrees: Double = 0,
        confidence: Double
    ) {
        self.time = time
        self.region = region
        self.rotationDegrees = rotationDegrees
        self.confidence = confidence
    }

    public func validated() throws -> Self {
        guard time >= .zero, rotationDegrees.isFinite, confidence.isFinite, (0...1).contains(confidence) else {
            throw ProjectError.invalidValue("Tracking samples require nonnegative time, finite rotation and normalized confidence.")
        }
        _ = try region.validated()
        return self
    }
}

public struct ProjectMotionTrack: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var name: String
    public var kind: ProjectTrackingKind
    public var samples: [ProjectTrackingSample]

    public init(id: VertexID = VertexID(), name: String, kind: ProjectTrackingKind, samples: [ProjectTrackingSample]) {
        self.id = id
        self.name = name
        self.kind = kind
        self.samples = samples
    }

    public func validated() throws -> Self {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.invalidValue("Motion track name must not be empty.")
        }
        guard samples.count >= 2, samples.count <= 100_000 else {
            throw ProjectError.invalidValue("Motion tracks require 2...100000 samples.")
        }
        for sample in samples { _ = try sample.validated() }
        guard zip(samples, samples.dropFirst()).allSatisfy({ $0.time < $1.time }) else {
            throw ProjectError.invalidValue("Motion track samples must be strictly increasing in exact project time.")
        }
        return self
    }

    public var averageConfidence: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0) { $0 + $1.confidence } / Double(samples.count)
    }

    public func transformChannels(
        mode: ProjectTrackingApplicationMode,
        basePosition: ProjectVector2,
        minimumConfidence: Double = 0
    ) throws -> [ProjectAnimationChannel] {
        _ = try validated()
        guard basePosition.x.isFinite, basePosition.y.isFinite,
              minimumConfidence.isFinite, (0...1).contains(minimumConfidence) else {
            throw ProjectError.invalidValue("Tracking solve configuration is invalid.")
        }
        let accepted = samples.filter { $0.confidence >= minimumConfidence }
        guard accepted.count >= 2, let reference = accepted.first else {
            throw ProjectError.invalidValue("Tracking solve requires at least two samples above the confidence threshold.")
        }
        func solved(_ sample: ProjectTrackingSample) -> ProjectVector2 {
            let dx = sample.region.center.x - reference.region.center.x
            let dy = sample.region.center.y - reference.region.center.y
            switch mode {
            case .follow:
                return .init(x: basePosition.x + dx, y: basePosition.y + dy)
            case .stabilize:
                return .init(x: basePosition.x - dx, y: basePosition.y - dy)
            }
        }
        let x = ProjectAnimationChannel(
            property: .layer(.positionX),
            keyframes: accepted.map { sample in
                .init(time: sample.time, value: .scalar(solved(sample).x), interpolation: .linear)
            }
        )
        let y = ProjectAnimationChannel(
            property: .layer(.positionY),
            keyframes: accepted.map { sample in
                .init(time: sample.time, value: .scalar(solved(sample).y), interpolation: .linear)
            }
        )
        return [try x.validated(), try y.validated()]
    }

    public func planarTransformChannels(
        mode: ProjectTrackingApplicationMode,
        basePosition: ProjectVector2,
        baseScale: Double,
        baseRotationDegrees: Double,
        minimumConfidence: Double = 0
    ) throws -> [ProjectAnimationChannel] {
        var channels = try transformChannels(mode: mode, basePosition: basePosition, minimumConfidence: minimumConfidence)
        let accepted = samples.filter { $0.confidence >= minimumConfidence }
        guard let reference = accepted.first else { return channels }
        let referenceWidth = reference.region.width
        guard referenceWidth > 0, baseScale.isFinite, baseScale > 0, baseRotationDegrees.isFinite else {
            throw ProjectError.invalidValue("Planar tracking solve has invalid scale or rotation input.")
        }
        let scaleFrames = accepted.map { sample -> ProjectKeyframe in
            let ratio = sample.region.width / referenceWidth
            let value = mode == .follow ? baseScale * ratio : baseScale / max(ratio, 0.000_001)
            return .init(time: sample.time, value: .scalar(value), interpolation: .linear)
        }
        let rotationFrames = accepted.map { sample -> ProjectKeyframe in
            let delta = sample.rotationDegrees - reference.rotationDegrees
            let value = mode == .follow ? baseRotationDegrees + delta : baseRotationDegrees - delta
            return .init(time: sample.time, value: .scalar(value), interpolation: .linear)
        }
        channels.append(try ProjectAnimationChannel(property: .layer(.scaleX), keyframes: scaleFrames).validated())
        channels.append(try ProjectAnimationChannel(property: .layer(.scaleY), keyframes: scaleFrames).validated())
        channels.append(try ProjectAnimationChannel(property: .layer(.rotationDegrees), keyframes: rotationFrames).validated())
        return channels
    }

    public func cameraMotionSummary() throws -> ProjectCameraMotionSummary {
        _ = try validated()
        guard let first = samples.first, let last = samples.last else {
            throw ProjectError.invalidValue("Camera motion summary requires tracking samples.")
        }
        return ProjectCameraMotionSummary(
            translationX: last.region.center.x - first.region.center.x,
            translationY: last.region.center.y - first.region.center.y,
            zoomRatio: last.region.width / max(first.region.width, 0.000_001),
            rotationDegrees: last.rotationDegrees - first.rotationDegrees,
            confidence: averageConfidence
        )
    }
}

public struct ProjectCameraMotionSummary: Codable, Equatable, Sendable {
    public var translationX: Double
    public var translationY: Double
    public var zoomRatio: Double
    public var rotationDegrees: Double
    public var confidence: Double

    public init(translationX: Double, translationY: Double, zoomRatio: Double, rotationDegrees: Double, confidence: Double) {
        self.translationX = translationX
        self.translationY = translationY
        self.zoomRatio = zoomRatio
        self.rotationDegrees = rotationDegrees
        self.confidence = confidence
    }
}

public struct ProjectRotoscopeKeyframe: Codable, Equatable, Sendable {
    public var time: RationalTime
    public var path: ProjectBezierPath

    public init(time: RationalTime, path: ProjectBezierPath) {
        self.time = time
        self.path = path
    }
}

public struct ProjectRotoscopeTrack: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var name: String
    public var keyframes: [ProjectRotoscopeKeyframe]

    public init(id: VertexID = VertexID(), name: String, keyframes: [ProjectRotoscopeKeyframe]) {
        self.id = id
        self.name = name
        self.keyframes = keyframes
    }

    public func validated() throws -> Self {
        guard !name.isEmpty, keyframes.count >= 1 else {
            throw ProjectError.invalidValue("Rotoscope tracks require a name and at least one path keyframe.")
        }
        for keyframe in keyframes {
            guard keyframe.time >= .zero else { throw ProjectError.invalidValue("Rotoscope keyframe time must be nonnegative.") }
            _ = try keyframe.path.validated(maximumVertices: 256)
        }
        guard zip(keyframes, keyframes.dropFirst()).allSatisfy({ $0.time < $1.time }) else {
            throw ProjectError.invalidValue("Rotoscope keyframes must be strictly increasing.")
        }
        return self
    }

    public func maskAnimationChannel(maskID: VertexID) throws -> ProjectAnimationChannel {
        _ = try validated()
        return try ProjectAnimationChannel(
            property: .mask(maskID: maskID, property: .path),
            keyframes: keyframes.map { .init(time: $0.time, value: .bezierPath($0.path), interpolation: .linear) }
        ).validated()
    }
}
