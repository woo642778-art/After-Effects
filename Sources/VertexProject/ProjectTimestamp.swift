import Foundation

public extension ProjectDateCodec {
    static func normalized(_ date: Date) -> Date {
        let milliseconds = (date.timeIntervalSince1970 * 1_000).rounded(.towardZero)
        return Date(timeIntervalSince1970: milliseconds / 1_000)
    }
}
