import Foundation
import VertexCore

public struct ProjectTrackingAnalysisRequest: Codable, Equatable, Sendable {
    public var kind: ProjectTrackingKind
    public var region: ProjectTrackingRegion
    public var startTime: RationalTime
    public var endTime: RationalTime
    public var frameRate: RationalTime
    public var frameStride: Int
    public var minimumConfidence: Double
    public var maximumSamples: Int

    public init(
        kind: ProjectTrackingKind,
        region: ProjectTrackingRegion,
        startTime: RationalTime,
        endTime: RationalTime,
        frameRate: RationalTime,
        frameStride: Int = 1,
        minimumConfidence: Double = 0.25,
        maximumSamples: Int = 20_000
    ) {
        self.kind = kind
        self.region = region
        self.startTime = startTime
        self.endTime = endTime
        self.frameRate = frameRate
        self.frameStride = frameStride
        self.minimumConfidence = minimumConfidence
        self.maximumSamples = maximumSamples
    }

    public func validated() throws -> Self {
        _ = try region.validated()
        guard startTime >= .zero, endTime > startTime else {
            throw ProjectError.invalidValue("Tracking analysis requires a nonnegative start before the end time.")
        }
        guard frameRate.value > 0, frameRate.timescale > 0, frameRate.value <= Int64(Int32.max) else {
            throw ProjectError.invalidValue("Tracking frame rate cannot be represented exactly.")
        }
        guard (1...120).contains(frameStride),
              minimumConfidence.isFinite, (0...1).contains(minimumConfidence),
              (2...100_000).contains(maximumSamples) else {
            throw ProjectError.invalidValue("Tracking sampling configuration is outside supported ranges.")
        }
        let times = try sampleTimes()
        guard times.count >= 2 else {
            throw ProjectError.invalidValue("Tracking analysis must contain at least two sampled frames.")
        }
        guard times.count <= maximumSamples else {
            throw ProjectError.invalidValue("Tracking analysis exceeds its maximum sample count.")
        }
        return self
    }

    public func sampleTimes() throws -> [RationalTime] {
        guard frameRate.value > 0, frameRate.timescale > 0, frameRate.value <= Int64(Int32.max), frameStride > 0 else {
            throw ProjectError.invalidValue("Tracking sampling configuration cannot produce exact frame times.")
        }
        let numerator = Int64(frameRate.timescale).multipliedReportingOverflow(by: Int64(frameStride))
        guard !numerator.overflow else {
            throw ProjectError.invalidValue("Tracking frame stride overflowed exact time arithmetic.")
        }
        let step = RationalTime(value: numerator.partialValue, timescale: Int32(frameRate.value))
        guard step > .zero else {
            throw ProjectError.invalidValue("Tracking frame step must be positive.")
        }

        var result: [RationalTime] = []
        var time = startTime
        while time <= endTime {
            result.append(time)
            if result.count > maximumSamples {
                throw ProjectError.invalidValue("Tracking analysis exceeds its maximum sample count.")
            }
            do {
                time = try time.adding(step)
            } catch {
                throw ProjectError.invalidValue("Tracking sample time arithmetic overflowed.")
            }
        }
        if result.last != endTime, result.count < maximumSamples {
            result.append(endTime)
        }
        return result
    }
}

public struct ProjectRotoscopeRefinement: Codable, Equatable, Sendable {
    public var time: RationalTime
    public var path: ProjectBezierPath

    public init(time: RationalTime, path: ProjectBezierPath) {
        self.time = time
        self.path = path
    }

    public func validated() throws -> Self {
        guard time >= .zero else {
            throw ProjectError.invalidValue("Rotoscope refinement time must be nonnegative.")
        }
        _ = try path.validated(maximumVertices: 256)
        return self
    }
}

public extension ProjectMotionTrack {
    func propagatedRotoscope(
        name: String,
        referencePath: ProjectBezierPath,
        referenceTime: RationalTime? = nil,
        minimumConfidence: Double = 0,
        refinements: [ProjectRotoscopeRefinement] = []
    ) throws -> ProjectRotoscopeTrack {
        _ = try validated()
        _ = try referencePath.validated(maximumVertices: 256)
        guard minimumConfidence.isFinite, (0...1).contains(minimumConfidence) else {
            throw ProjectError.invalidValue("Rotoscope propagation confidence must be normalized.")
        }
        guard Set(refinements.map(\.time)).count == refinements.count else {
            throw ProjectError.invalidValue("Rotoscope refinements must have unique times.")
        }
        for refinement in refinements { _ = try refinement.validated() }

        let accepted = samples.filter { $0.confidence >= minimumConfidence }
        guard accepted.count >= 2 else {
            throw ProjectError.invalidValue("Rotoscope propagation requires at least two accepted tracking samples.")
        }
        let requestedReferenceTime = referenceTime ?? accepted[0].time
        let referenceSample = accepted.min { lhs, rhs in
            absoluteSeconds(lhs.time, from: requestedReferenceTime) < absoluteSeconds(rhs.time, from: requestedReferenceTime)
        }!
        let referenceCenter = referenceSample.region.center
        let referenceWidth = referenceSample.region.width
        let referenceHeight = referenceSample.region.height
        guard referenceWidth > 0, referenceHeight > 0 else {
            throw ProjectError.invalidValue("Rotoscope reference tracking region has invalid size.")
        }
        let refinementByTime = Dictionary(uniqueKeysWithValues: refinements.map { ($0.time, $0.path) })

        let keyframes = try accepted.map { sample -> ProjectRotoscopeKeyframe in
            if let refined = refinementByTime[sample.time] {
                return .init(time: sample.time, path: refined)
            }
            let scaleX = sample.region.width / referenceWidth
            let scaleY = sample.region.height / referenceHeight
            let radians = (sample.rotationDegrees - referenceSample.rotationDegrees) * .pi / 180
            let cosine = cos(radians)
            let sine = sin(radians)
            let currentCenter = sample.region.center
            let vertices = referencePath.vertices.map { vertex in
                let transformedAnchor = transform(
                    vertex.anchor,
                    referenceCenter: referenceCenter,
                    currentCenter: currentCenter,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    cosine: cosine,
                    sine: sine,
                    isTangent: false
                )
                let transformedIncoming = transform(
                    vertex.incomingTangent,
                    referenceCenter: .init(x: 0, y: 0),
                    currentCenter: .init(x: 0, y: 0),
                    scaleX: scaleX,
                    scaleY: scaleY,
                    cosine: cosine,
                    sine: sine,
                    isTangent: true
                )
                let transformedOutgoing = transform(
                    vertex.outgoingTangent,
                    referenceCenter: .init(x: 0, y: 0),
                    currentCenter: .init(x: 0, y: 0),
                    scaleX: scaleX,
                    scaleY: scaleY,
                    cosine: cosine,
                    sine: sine,
                    isTangent: true
                )
                return ProjectBezierVertex(
                    anchor: transformedAnchor,
                    incomingTangent: transformedIncoming,
                    outgoingTangent: transformedOutgoing
                )
            }
            return .init(time: sample.time, path: ProjectBezierPath(vertices: vertices, closed: referencePath.closed))
        }
        return try ProjectRotoscopeTrack(name: name, keyframes: keyframes).validated()
    }

    private func absoluteSeconds(_ lhs: RationalTime, from rhs: RationalTime) -> Double {
        abs(lhs.seconds - rhs.seconds)
    }

    private func transform(
        _ point: ProjectVector2,
        referenceCenter: ProjectVector2,
        currentCenter: ProjectVector2,
        scaleX: Double,
        scaleY: Double,
        cosine: Double,
        sine: Double,
        isTangent: Bool
    ) -> ProjectVector2 {
        let originX = isTangent ? 0 : referenceCenter.x
        let originY = isTangent ? 0 : referenceCenter.y
        let x = (point.x - originX) * scaleX
        let y = (point.y - originY) * scaleY
        let rotatedX = x * cosine - y * sine
        let rotatedY = x * sine + y * cosine
        if isTangent {
            return .init(x: rotatedX, y: rotatedY)
        }
        return .init(x: currentCenter.x + rotatedX, y: currentCenter.y + rotatedY)
    }
}
