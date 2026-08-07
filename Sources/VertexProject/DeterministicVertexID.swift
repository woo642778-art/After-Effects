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
        return try VertexID(uuidBytes: bytes)
    }
}
