import Foundation
import VertexCore
import VertexProject

public struct GestureMotionSample: Equatable, Sendable {
    public var time: RationalTime
    public var value: ProjectVector2

    public init(time: RationalTime, value: ProjectVector2) {
        self.time = time
        self.value = value
    }
}

public struct GestureKeyframeReducer: Sendable {
    public init() {}

    public func reduce(
        samples: [GestureMotionSample],
        tolerance: Double = 0.0025,
        maximumKeyframes: Int = 180
    ) throws -> [ProjectKeyframe] {
        guard tolerance.isFinite, tolerance >= 0, maximumKeyframes >= 2 else {
            throw ProjectError.invalidValue("Gesture reduction parameters are invalid.")
        }
        guard !samples.isEmpty else { return [] }
        for sample in samples { _ = try sample.value.validated() }
        for pair in zip(samples, samples.dropFirst()) where pair.0.time >= pair.1.time {
            throw ProjectError.invalidValue("Gesture samples must have strictly increasing timestamps.")
        }

        let smoothed = smooth(samples)
        var kept = douglasPeucker(smoothed, tolerance: tolerance)
        if kept.count > maximumKeyframes {
            let stride = Double(kept.count - 1) / Double(maximumKeyframes - 1)
            kept = (0..<maximumKeyframes).map { index in
                kept[min(kept.count - 1, Int((Double(index) * stride).rounded()))]
            }
        }

        return kept.map { sample in
            ProjectKeyframe(
                time: sample.time,
                value: .vector2(sample.value),
                interpolation: .cubicBezier,
                incomingTemporalHandle: ProjectBezierHandle(x: 2.0 / 3.0, y: 2.0 / 3.0),
                outgoingTemporalHandle: ProjectBezierHandle(x: 1.0 / 3.0, y: 1.0 / 3.0),
                spatialInterpolation: .autoBezier
            )
        }
    }

    private func smooth(_ samples: [GestureMotionSample]) -> [GestureMotionSample] {
        guard samples.count >= 3 else { return samples }
        var output = samples
        for index in 1..<(samples.count - 1) {
            output[index].value = ProjectVector2(
                x: (samples[index - 1].value.x + 2 * samples[index].value.x + samples[index + 1].value.x) / 4,
                y: (samples[index - 1].value.y + 2 * samples[index].value.y + samples[index + 1].value.y) / 4
            )
        }
        return output
    }

    private func douglasPeucker(_ samples: [GestureMotionSample], tolerance: Double) -> [GestureMotionSample] {
        guard samples.count > 2 else { return samples }
        let first = samples[0].value
        let last = samples[samples.count - 1].value
        var maxDistance = 0.0
        var index = 0
        for candidate in 1..<(samples.count - 1) {
            let distance = perpendicularDistance(samples[candidate].value, lineStart: first, lineEnd: last)
            if distance > maxDistance { maxDistance = distance; index = candidate }
        }
        guard maxDistance > tolerance else { return [samples[0], samples[samples.count - 1]] }
        let left = douglasPeucker(Array(samples[0...index]), tolerance: tolerance)
        let right = douglasPeucker(Array(samples[index...]), tolerance: tolerance)
        return Array(left.dropLast()) + right
    }

    private func perpendicularDistance(_ point: ProjectVector2, lineStart: ProjectVector2, lineEnd: ProjectVector2) -> Double {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 1e-18 else { return hypot(point.x - lineStart.x, point.y - lineStart.y) }
        let t = min(max(((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared, 0), 1)
        return hypot(point.x - (lineStart.x + t * dx), point.y - (lineStart.y + t * dy))
    }
}
