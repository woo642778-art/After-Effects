import Foundation

public enum VertexIDError: Error, Equatable, Sendable {
    case invalidFormat(String)
    case invalidByteCount(Int)
}

public struct VertexID: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init() {
        self.rawValue = UUID().uuidString.lowercased()
    }

    public init(rawValue: String) {
        precondition(UUID(uuidString: rawValue) != nil, "VertexID must be a UUID string")
        self.rawValue = rawValue.lowercased()
    }

    public init(parsing value: String) throws {
        guard let uuid = UUID(uuidString: value) else {
            throw VertexIDError.invalidFormat(value)
        }
        self.rawValue = uuid.uuidString.lowercased()
    }

    public init(uuidBytes bytes: [UInt8]) throws {
        guard bytes.count == 16 else { throw VertexIDError.invalidByteCount(bytes.count) }
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        self.rawValue = uuid.uuidString.lowercased()
    }

    public var description: String { rawValue }
}
