import Foundation
import VertexCore

public extension StableProjectSHA256 {
    static func digest(_ data: Data) -> [UInt8] {
        let hex = hexDigest(data)
        return stride(from: 0, to: hex.count, by: 2).compactMap { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let end = hex.index(start, offsetBy: 2)
            return UInt8(hex[start..<end], radix: 16)
        }
    }
}

public enum DeterministicVertexID {
    public static func derive(domain: String, components: [String]) throws -> VertexID {
        guard !domain.isEmpty else {
            throw ProjectError.invalidValue("Deterministic identity domain must not be empty.")
        }
        let payload = ([domain] + components).joined(separator: "\u{1f}")
        var bytes = Array(StableProjectSHA256.digest(Data(payload.utf8)).prefix(16))
        guard bytes.count == 16 else {
            throw ProjectError.deterministicEncodingFailure("SHA-256 did not produce a 16-byte identity prefix.")
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80

        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let firstEnd = hex.index(hex.startIndex, offsetBy: 8)
        let secondEnd = hex.index(firstEnd, offsetBy: 4)
        let thirdEnd = hex.index(secondEnd, offsetBy: 4)
        let fourthEnd = hex.index(thirdEnd, offsetBy: 4)
        let group1 = String(hex[hex.startIndex..<firstEnd])
        let group2 = String(hex[firstEnd..<secondEnd])
        let group3 = String(hex[secondEnd..<thirdEnd])
        let group4 = String(hex[thirdEnd..<fourthEnd])
        let group5 = String(hex[fourthEnd..<hex.endIndex])
        let raw = group1 + "-" + group2 + "-" + group3 + "-" + group4 + "-" + group5
        do {
            return try VertexID(parsing: raw)
        } catch {
            throw ProjectError.deterministicEncodingFailure("Derived UUID bytes were invalid.")
        }
    }
}
