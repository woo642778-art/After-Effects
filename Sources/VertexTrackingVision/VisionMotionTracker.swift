#if canImport(AVFoundation) && canImport(Vision)
@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
@preconcurrency import Vision
import VertexCore
import VertexProject

public enum VisionMotionTrackingError: Error, Equatable, Sendable, LocalizedError {
    case frameUnavailable(String)
    case initialSubjectNotFound(ProjectTrackingKind)
    case trackingLost(ProjectTrackingKind, RationalTime)
    case unsupported(ProjectTrackingKind)

    public var errorDescription: String? {
        switch self {
        case .frameUnavailable(let message):
            return "Unable to decode a tracking frame: \(message)"
        case .initialSubjectNotFound(let kind):
            return "Vision could not locate the initial \(kind.rawValue) subject inside the requested region."
        case .trackingLost(let kind, let time):
            return "Vision lost the \(kind.rawValue) track at \(time.description)."
        case .unsupported(let kind):
            return "The requested tracking kind is not available in this Vision runtime: \(kind.rawValue)."
        }
    }
}

public actor VisionMotionTracker {
    public init() {}

    public func analyze(
        mediaURL: URL,
        request sourceRequest: ProjectTrackingAnalysisRequest,
        sourceTimes: [RationalTime]? = nil,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ProjectMotionTrack {
        let request = try sourceRequest.validated()
        let times = try request.sampleTimes()
        guard times.count >= 2 else {
            throw ProjectError.invalidValue("Tracking requires at least two exact sample times.")
        }
        let decodeTimes = try Self.validatedDecodeTimes(
            compositionTimes: times,
            sourceTimes: sourceTimes
        )

        let asset = AVURLAsset(url: mediaURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 1920, height: 1920)

        try Task.checkCancellation()
        let firstImage = try frameImage(generator: generator, at: decodeTimes[0])
        let initial = try initialObservation(
            kind: request.kind,
            requestedRegion: request.region,
            image: firstImage
        )

        var samples: [ProjectTrackingSample] = [
            ProjectTrackingSample(
                time: times[0],
                region: Self.projectRegion(fromVision: initial.region),
                rotationDegrees: initial.rotationDegrees,
                confidence: initial.confidence
            )
        ]
        progress?(1 / Double(times.count))

        switch request.kind {
        case .planar:
            guard let rectangle = initial.rectangle else {
                throw VisionMotionTrackingError.initialSubjectNotFound(.planar)
            }
            try await trackPlanar(
                rectangle: rectangle,
                compositionTimes: times,
                sourceTimes: decodeTimes,
                generator: generator,
                minimumConfidence: request.minimumConfidence,
                samples: &samples,
                progress: progress
            )
        case .point, .object, .face, .body:
            let observation = VNDetectedObjectObservation(boundingBox: initial.region)
            try await trackObject(
                kind: request.kind,
                observation: observation,
                compositionTimes: times,
                sourceTimes: decodeTimes,
                generator: generator,
                minimumConfidence: request.minimumConfidence,
                samples: &samples,
                progress: progress
            )
        }

        return try ProjectMotionTrack(
            name: Self.defaultTrackName(for: request.kind),
            kind: request.kind,
            samples: samples
        ).validated()
    }

    private func trackObject(
        kind: ProjectTrackingKind,
        observation initialObservation: VNDetectedObjectObservation,
        compositionTimes: [RationalTime],
        sourceTimes: [RationalTime],
        generator: AVAssetImageGenerator,
        minimumConfidence: Double,
        samples: inout [ProjectTrackingSample],
        progress: (@Sendable (Double) -> Void)?
    ) async throws {
        let sequence = VNSequenceRequestHandler()
        var previous = initialObservation

        for index in 1..<compositionTimes.count {
            try Task.checkCancellation()
            let image = try frameImage(generator: generator, at: sourceTimes[index])
            let tracking = VNTrackObjectRequest(detectedObjectObservation: previous)
            tracking.trackingLevel = .accurate
            try sequence.perform([tracking], on: image)
            guard let observation = tracking.results?.first,
                  let result = observation as? VNDetectedObjectObservation else {
                throw VisionMotionTrackingError.trackingLost(kind, compositionTimes[index])
            }
            let confidence = Double(result.confidence)
            guard confidence >= minimumConfidence else {
                throw VisionMotionTrackingError.trackingLost(kind, compositionTimes[index])
            }
            samples.append(ProjectTrackingSample(
                time: compositionTimes[index],
                region: Self.projectRegion(fromVision: result.boundingBox),
                rotationDegrees: 0,
                confidence: confidence
            ))
            previous = result
            progress?(Double(index + 1) / Double(compositionTimes.count))
        }
    }

    private func trackPlanar(
        rectangle initialRectangle: VNRectangleObservation,
        compositionTimes: [RationalTime],
        sourceTimes: [RationalTime],
        generator: AVAssetImageGenerator,
        minimumConfidence: Double,
        samples: inout [ProjectTrackingSample],
        progress: (@Sendable (Double) -> Void)?
    ) async throws {
        let sequence = VNSequenceRequestHandler()
        var previous = initialRectangle

        for index in 1..<compositionTimes.count {
            try Task.checkCancellation()
            let image = try frameImage(generator: generator, at: sourceTimes[index])
            let tracking = VNTrackRectangleRequest(rectangleObservation: previous)
            tracking.trackingLevel = .accurate
            try sequence.perform([tracking], on: image)
            guard let observation = tracking.results?.first,
                  let result = observation as? VNRectangleObservation else {
                throw VisionMotionTrackingError.trackingLost(.planar, compositionTimes[index])
            }
            let confidence = Double(result.confidence)
            guard confidence >= minimumConfidence else {
                throw VisionMotionTrackingError.trackingLost(.planar, compositionTimes[index])
            }
            samples.append(ProjectTrackingSample(
                time: compositionTimes[index],
                region: Self.projectRegion(fromVision: result.boundingBox),
                rotationDegrees: Self.projectRotationDegrees(for: result),
                confidence: confidence
            ))
            previous = result
            progress?(Double(index + 1) / Double(compositionTimes.count))
        }
    }

    private func frameImage(generator: AVAssetImageGenerator, at time: RationalTime) throws -> CGImage {
        do {
            var actualTime = CMTime.invalid
            return try generator.copyCGImage(
                at: CMTime(value: time.value, timescale: time.timescale),
                actualTime: &actualTime
            )
        } catch {
            throw VisionMotionTrackingError.frameUnavailable(error.localizedDescription)
        }
    }

    private struct InitialVisionObservation {
        var region: CGRect
        var confidence: Double
        var rotationDegrees: Double
        var rectangle: VNRectangleObservation?
    }

    private func initialObservation(
        kind: ProjectTrackingKind,
        requestedRegion: ProjectTrackingRegion,
        image: CGImage
    ) throws -> InitialVisionObservation {
        let visionRegion = Self.visionRegion(fromProject: requestedRegion)
        switch kind {
        case .point, .object:
            return InitialVisionObservation(
                region: visionRegion,
                confidence: 1,
                rotationDegrees: 0,
                rectangle: nil
            )

        case .planar:
            let minX = visionRegion.minX
            let maxX = visionRegion.maxX
            let minY = visionRegion.minY
            let maxY = visionRegion.maxY
            let rectangle = VNRectangleObservation(
                requestRevision: VNTrackRectangleRequestRevision1,
                topLeft: CGPoint(x: minX, y: maxY),
                topRight: CGPoint(x: maxX, y: maxY),
                bottomRight: CGPoint(x: maxX, y: minY),
                bottomLeft: CGPoint(x: minX, y: minY)
            )
            return InitialVisionObservation(
                region: rectangle.boundingBox,
                confidence: 1,
                rotationDegrees: Self.projectRotationDegrees(for: rectangle),
                rectangle: rectangle
            )

        case .face:
            let detection = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([detection])
            guard let candidate = Self.bestObservation(detection.results ?? [], near: visionRegion) else {
                throw VisionMotionTrackingError.initialSubjectNotFound(.face)
            }
            return InitialVisionObservation(
                region: candidate.boundingBox,
                confidence: Double(candidate.confidence),
                rotationDegrees: 0,
                rectangle: nil
            )

        case .body:
            let detection = VNDetectHumanRectanglesRequest()
            detection.upperBodyOnly = false
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([detection])
            guard let candidate = Self.bestObservation(detection.results ?? [], near: visionRegion) else {
                throw VisionMotionTrackingError.initialSubjectNotFound(.body)
            }
            return InitialVisionObservation(
                region: candidate.boundingBox,
                confidence: Double(candidate.confidence),
                rotationDegrees: 0,
                rectangle: nil
            )
        }
    }

    nonisolated static func validatedDecodeTimes(
        compositionTimes: [RationalTime],
        sourceTimes: [RationalTime]?
    ) throws -> [RationalTime] {
        let decoded = sourceTimes ?? compositionTimes
        guard decoded.count == compositionTimes.count else {
            throw ProjectError.invalidValue("Tracking source-time count must match the exact composition sample count.")
        }
        guard decoded.allSatisfy({ $0 >= .zero }) else {
            throw ProjectError.invalidValue("Tracking source decode times must be nonnegative.")
        }
        return decoded
    }

    public nonisolated static func visionRegion(fromProject region: ProjectTrackingRegion) -> CGRect {
        CGRect(
            x: region.x,
            y: 1 - region.y - region.height,
            width: region.width,
            height: region.height
        )
    }

    public nonisolated static func projectRegion(fromVision rect: CGRect) -> ProjectTrackingRegion {
        let x = min(max(Double(rect.minX), 0), 1)
        let y = min(max(1 - Double(rect.maxY), 0), 1)
        let width = min(max(Double(rect.width), 0.000_001), 1 - x)
        let height = min(max(Double(rect.height), 0.000_001), 1 - y)
        return ProjectTrackingRegion(x: x, y: y, width: width, height: height)
    }

    private nonisolated static func projectRotationDegrees(for rectangle: VNRectangleObservation) -> Double {
        let topLeft = CGPoint(x: rectangle.topLeft.x, y: 1 - rectangle.topLeft.y)
        let topRight = CGPoint(x: rectangle.topRight.x, y: 1 - rectangle.topRight.y)
        return atan2(topRight.y - topLeft.y, topRight.x - topLeft.x) * 180 / .pi
    }

    private nonisolated static func bestObservation<T: VNDetectedObjectObservation>(
        _ observations: [T],
        near requested: CGRect
    ) -> T? {
        observations.max { lhs, rhs in
            let leftScore = overlapScore(lhs.boundingBox, requested: requested) + Double(lhs.confidence) * 0.001
            let rightScore = overlapScore(rhs.boundingBox, requested: requested) + Double(rhs.confidence) * 0.001
            return leftScore < rightScore
        }
    }

    private nonisolated static func overlapScore(_ rect: CGRect, requested: CGRect) -> Double {
        let intersection = rect.intersection(requested)
        if !intersection.isNull, intersection.width > 0, intersection.height > 0 {
            let intersectionArea = intersection.width * intersection.height
            let unionArea = rect.width * rect.height + requested.width * requested.height - intersectionArea
            if unionArea > 0 { return Double(intersectionArea / unionArea) + 1 }
        }
        let dx = rect.midX - requested.midX
        let dy = rect.midY - requested.midY
        return -Double(dx * dx + dy * dy)
    }

    private nonisolated static func defaultTrackName(for kind: ProjectTrackingKind) -> String {
        switch kind {
        case .point: "Point Track"
        case .planar: "Planar Track"
        case .object: "Object Track"
        case .face: "Face Track"
        case .body: "Body Track"
        }
    }
}
#endif
