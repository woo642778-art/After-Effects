import Foundation

public enum VertexErrorDomain: String, Codable, CaseIterable, Sendable {
    case core
    case media
    case timeline
    case render
    case effects
    case audio
    case project
    case export
    case userInterface
}

public struct VertexError: Error, Codable, Equatable, Sendable, LocalizedError {
    public let domain: VertexErrorDomain
    public let code: String
    public let message: String
    public let context: [String: String]

    public init(domain: VertexErrorDomain, code: String, message: String, context: [String: String] = [:]) {
        precondition(!code.isEmpty, "VertexError code must not be empty")
        precondition(!message.isEmpty, "VertexError message must not be empty")
        self.domain = domain
        self.code = code
        self.message = message
        self.context = context
    }

    public var errorDescription: String? { message }
}
