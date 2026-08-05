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
        try Self.combine(self, other, operation: +)
    }

    public func subtracting(_ other: RationalTime) throws -> RationalTime {
        try Self.combine(self, other, operation: -)
    }

    public func rescaled(to newTimescale: Int32, rounding: TimeRoundingMode) throws -> RationalTime {
        guard newTimescale > 0 else { throw RationalTimeError.invalidTimescale(newTimescale) }

        let numerator = Int128(value) * Int128(newTimescale)
        let denominator = Int128(timescale)
        var quotient = numerator / denominator
        let remainder = numerator % denominator

        if remainder != 0 {
            let direction: Int128 = numerator < 0 ? -1 : 1
            switch rounding {
            case .towardZero:
                break
            case .awayFromZero:
                quotient += direction
            case .floor:
                if numerator < 0 { quotient -= 1 }
            case .ceiling:
                if numerator > 0 { quotient += 1 }
            case .nearest:
                if remainder.magnitude * 2 >= denominator.magnitude {
                    quotient += direction
                }
            }
        }

        guard quotient >= Int128(Int64.min), quotient <= Int128(Int64.max) else {
            throw RationalTimeError.overflow
        }
        return RationalTime(value: Int64(quotient), timescale: newTimescale)
    }

    public static func < (lhs: RationalTime, rhs: RationalTime) -> Bool {
        Int128(lhs.value) * Int128(rhs.timescale) < Int128(rhs.value) * Int128(lhs.timescale)
    }

    private static func combine(
        _ lhs: RationalTime,
        _ rhs: RationalTime,
        operation: (Int128, Int128) -> Int128
    ) throws -> RationalTime {
        let scaleGCD = greatestCommonDivisor(UInt64(lhs.timescale), UInt64(rhs.timescale))
        let lhsMultiplier = Int128(rhs.timescale) / Int128(scaleGCD)
        let rhsMultiplier = Int128(lhs.timescale) / Int128(scaleGCD)
        let numerator = operation(Int128(lhs.value) * lhsMultiplier, Int128(rhs.value) * rhsMultiplier)
        let denominator = Int128(lhs.timescale) * lhsMultiplier

        guard numerator >= Int128(Int64.min), numerator <= Int128(Int64.max),
              denominator > 0, denominator <= Int128(Int32.max) else {
            throw RationalTimeError.overflow
        }

        return RationalTime(value: Int64(numerator), timescale: Int32(denominator))
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
