import Foundation

public enum TimeRoundingMode: String, Codable, CaseIterable, Sendable {
    case towardZero
    case awayFromZero
    case floor
    case ceiling
    case nearest
}

public enum RationalTimeError: Error, Equatable, Sendable {
    case invalidTimescale(Int32)
    case overflow
}

public struct RationalTime: Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let value: Int64
    public let timescale: Int32

    public static let zero = RationalTime(value: 0, timescale: 1)

    public init(value: Int64, timescale: Int32) {
        precondition(timescale > 0, "RationalTime timescale must be positive")
        let divisor = Self.greatestCommonDivisor(value.magnitude, UInt64(timescale))
        self.value = value / Int64(divisor)
        self.timescale = timescale / Int32(divisor)
    }

    public init(validatingValue value: Int64, timescale: Int32) throws {
        guard timescale > 0 else { throw RationalTimeError.invalidTimescale(timescale) }
        self.init(value: value, timescale: timescale)
    }

    public var seconds: Double {
        Double(value) / Double(timescale)
    }

    public var description: String {
        "\(value)/\(timescale)s"
    }

    public func adding(_ other: RationalTime) throws -> RationalTime {
        try Self.combine(self, other, subtract: false)
    }

    public func subtracting(_ other: RationalTime) throws -> RationalTime {
        try Self.combine(self, other, subtract: true)
    }

    public func rescaled(to newTimescale: Int32, rounding: TimeRoundingMode) throws -> RationalTime {
        guard newTimescale > 0 else { throw RationalTimeError.invalidTimescale(newTimescale) }

        let scaleGCD = Self.greatestCommonDivisor(UInt64(timescale), UInt64(newTimescale))
        let multiplier = Int64(newTimescale) / Int64(scaleGCD)
        let divisor = Int64(timescale) / Int64(scaleGCD)

        let integralPart = value / divisor
        let fractionalPart = value % divisor

        let (integralProduct, integralOverflow) = integralPart.multipliedReportingOverflow(by: multiplier)
        let (fractionalProduct, fractionalOverflow) = fractionalPart.multipliedReportingOverflow(by: multiplier)
        guard !integralOverflow, !fractionalOverflow else { throw RationalTimeError.overflow }

        let fractionalQuotient = fractionalProduct / divisor
        let remainder = fractionalProduct % divisor
        let (unrounded, quotientOverflow) = integralProduct.addingReportingOverflow(fractionalQuotient)
        guard !quotientOverflow else { throw RationalTimeError.overflow }

        let rounded = try Self.applyRounding(
            to: unrounded,
            remainder: remainder,
            divisor: divisor,
            mode: rounding
        )
        return RationalTime(value: rounded, timescale: newTimescale)
    }

    public static func < (lhs: RationalTime, rhs: RationalTime) -> Bool {
        if lhs.value < 0, rhs.value >= 0 { return true }
        if lhs.value >= 0, rhs.value < 0 { return false }

        let comparison = comparePositiveFractions(
            lhsNumerator: lhs.value.magnitude,
            lhsDenominator: UInt64(lhs.timescale),
            rhsNumerator: rhs.value.magnitude,
            rhsDenominator: UInt64(rhs.timescale)
        )

        return lhs.value < 0 ? comparison > 0 : comparison < 0
    }

    private static func combine(_ lhs: RationalTime, _ rhs: RationalTime, subtract: Bool) throws -> RationalTime {
        let scaleGCD = greatestCommonDivisor(UInt64(lhs.timescale), UInt64(rhs.timescale))
        let lhsMultiplier = Int64(rhs.timescale) / Int64(scaleGCD)
        let rhsMultiplier = Int64(lhs.timescale) / Int64(scaleGCD)

        let (lhsTerm, lhsOverflow) = lhs.value.multipliedReportingOverflow(by: lhsMultiplier)
        let (rhsTerm, rhsOverflow) = rhs.value.multipliedReportingOverflow(by: rhsMultiplier)
        guard !lhsOverflow, !rhsOverflow else { throw RationalTimeError.overflow }

        let numeratorResult = subtract
            ? lhsTerm.subtractingReportingOverflow(rhsTerm)
            : lhsTerm.addingReportingOverflow(rhsTerm)
        guard !numeratorResult.overflow else { throw RationalTimeError.overflow }

        let (denominator, denominatorOverflow) = Int64(lhs.timescale).multipliedReportingOverflow(by: lhsMultiplier)
        guard !denominatorOverflow, denominator > 0 else { throw RationalTimeError.overflow }

        let reduction = greatestCommonDivisor(numeratorResult.partialValue.magnitude, UInt64(denominator))
        let reducedNumerator = numeratorResult.partialValue / Int64(reduction)
        let reducedDenominator = denominator / Int64(reduction)
        guard reducedDenominator <= Int64(Int32.max) else { throw RationalTimeError.overflow }

        return RationalTime(value: reducedNumerator, timescale: Int32(reducedDenominator))
    }

    private static func applyRounding(
        to quotient: Int64,
        remainder: Int64,
        divisor: Int64,
        mode: TimeRoundingMode
    ) throws -> Int64 {
        guard remainder != 0 else { return quotient }
        let direction: Int64 = remainder < 0 ? -1 : 1
        let shouldAdjust: Bool

        switch mode {
        case .towardZero:
            shouldAdjust = false
        case .awayFromZero:
            shouldAdjust = true
        case .floor:
            shouldAdjust = remainder < 0
        case .ceiling:
            shouldAdjust = remainder > 0
        case .nearest:
            let threshold = UInt64(divisor) / 2 + UInt64(divisor) % 2
            shouldAdjust = remainder.magnitude >= threshold
        }

        guard shouldAdjust else { return quotient }
        let result = quotient.addingReportingOverflow(direction)
        guard !result.overflow else { throw RationalTimeError.overflow }
        return result.partialValue
    }

    /// Returns -1 when lhs < rhs, 0 when equal, and 1 when lhs > rhs.
    /// Uses continued fractions so cross multiplication cannot overflow.
    private static func comparePositiveFractions(
        lhsNumerator: UInt64,
        lhsDenominator: UInt64,
        rhsNumerator: UInt64,
        rhsDenominator: UInt64
    ) -> Int {
        var lhsN = lhsNumerator
        var lhsD = lhsDenominator
        var rhsN = rhsNumerator
        var rhsD = rhsDenominator
        var isInverted = false

        while true {
            let lhsQuotient = lhsN / lhsD
            let rhsQuotient = rhsN / rhsD
            if lhsQuotient != rhsQuotient {
                let comparison = lhsQuotient < rhsQuotient ? -1 : 1
                return isInverted ? -comparison : comparison
            }

            let lhsRemainder = lhsN % lhsD
            let rhsRemainder = rhsN % rhsD
            if lhsRemainder == 0 || rhsRemainder == 0 {
                if lhsRemainder == rhsRemainder { return 0 }
                let comparison = lhsRemainder == 0 ? -1 : 1
                return isInverted ? -comparison : comparison
            }

            lhsN = lhsD
            lhsD = lhsRemainder
            rhsN = rhsD
            rhsD = rhsRemainder
            isInverted.toggle()
        }
    }

    private static func greatestCommonDivisor(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        var a = lhs
        var b = rhs
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return max(a, 1)
    }
}
