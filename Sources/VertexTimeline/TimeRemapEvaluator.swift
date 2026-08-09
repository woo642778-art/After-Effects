import Foundation
import VertexCore
import VertexProject

public struct TimeRemapEvaluator: Sendable {
    public init() {}

    public func sourceTime(
        mapping: ProjectTimeRemap,
        compositionTime: RationalTime
    ) throws -> RationalTime {
        let mapping = try mapping.validated()
        guard let first = mapping.keyframes.first, let last = mapping.keyframes.last else {
            throw ProjectError.invalidOperation("Time Remap contains no keyframes.")
        }
        if compositionTime <= first.compositionTime { return first.sourceTime }
        if compositionTime >= last.compositionTime { return last.sourceTime }

        var low = 0
        var high = mapping.keyframes.count - 1
        while low + 1 < high {
            let middle = (low + high) / 2
            if mapping.keyframes[middle].compositionTime <= compositionTime { low = middle }
            else { high = middle }
        }

        let left = mapping.keyframes[low]
        let right = mapping.keyframes[high]
        if compositionTime == left.compositionTime { return left.sourceTime }
        if compositionTime == right.compositionTime { return right.sourceTime }
        if left.interpolation == .hold { return left.sourceTime }

        let compositionOffset = try compositionTime.subtracting(left.compositionTime)
        let compositionSpan = try right.compositionTime.subtracting(left.compositionTime)
        let sourceSpan = try right.sourceTime.subtracting(left.sourceTime)
        let scaled = try multiplyDividing(sourceSpan, by: compositionOffset, dividingBy: compositionSpan)
        return try left.sourceTime.adding(scaled)
    }

    private func multiplyDividing(
        _ lhs: RationalTime,
        by rhs: RationalTime,
        dividingBy divisor: RationalTime
    ) throws -> RationalTime {
        guard divisor.value != 0 else {
            throw ProjectError.invalidOperation("Time-remap segment has zero duration.")
        }

        let negativeCount = [lhs.value < 0, rhs.value < 0, divisor.value < 0]
            .reduce(into: 0) { count, isNegative in
                if isNegative { count += 1 }
            }
        let sign: Int64 = negativeCount.isMultiple(of: 2) ? 1 : -1
        var numerators: [UInt64] = [lhs.value.magnitude, rhs.value.magnitude, UInt64(divisor.timescale)]
        var denominators: [UInt64] = [UInt64(lhs.timescale), UInt64(rhs.timescale), divisor.value.magnitude]

        for nIndex in numerators.indices {
            for dIndex in denominators.indices {
                let factor = gcd(numerators[nIndex], denominators[dIndex])
                numerators[nIndex] /= factor
                denominators[dIndex] /= factor
            }
        }

        var numerator: UInt64 = 1
        for value in numerators {
            let product = numerator.multipliedReportingOverflow(by: value)
            guard !product.overflow else { throw RationalTimeError.overflow }
            numerator = product.partialValue
        }
        var denominator: UInt64 = 1
        for value in denominators {
            let product = denominator.multipliedReportingOverflow(by: value)
            guard !product.overflow else { throw RationalTimeError.overflow }
            denominator = product.partialValue
        }

        let reduction = gcd(numerator, denominator)
        numerator /= reduction
        denominator /= reduction
        guard numerator <= UInt64(Int64.max), denominator > 0, denominator <= UInt64(Int32.max) else {
            throw RationalTimeError.overflow
        }
        return RationalTime(value: Int64(numerator) * sign, timescale: Int32(denominator))
    }

    private func gcd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        var a = lhs
        var b = rhs
        while b != 0 {
            let r = a % b
            a = b
            b = r
        }
        return max(a, 1)
    }
}
