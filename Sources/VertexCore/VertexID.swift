import Foundation

public enum VertexIDError: Error, Equatable, Sendable {
    case invalidFormat(String)
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

    public var description: String { rawValue }
}
