import Foundation

public enum RenderError: Error, Codable, Equatable, Sendable, LocalizedError {
    case invalidGraph(String)
    case missingNode(String)
    case cycle([String])
    case invalidRequest(String)
    case unsupportedImage(String)
    case metalUnavailable
    case shaderFailure(String)
    case textureAllocationFailure(String)
    case commandFailure(String)
    case outputEncodingFailure(String)
    case cancelled
    case staleResult

    public var errorDescription: String? {
        switch self {
        case .invalidGraph(let message): return "Invalid render graph: \(message)"
        case .missingNode(let id): return "Render node is missing: \(id)"
        case .cycle(let ids): return "Render graph contains a cycle: \(ids.joined(separator: " → "))"
        case .invalidRequest(let message): return "Invalid render request: \(message)"
        case .unsupportedImage(let message): return "Unsupported source image: \(message)"
        case .metalUnavailable: return "Metal is unavailable on this device."
        case .shaderFailure(let message): return "Metal shader failure: \(message)"
        case .textureAllocationFailure(let message): return "Metal texture allocation failed: \(message)"
        case .commandFailure(let message): return "Metal command failed: \(message)"
        case .outputEncodingFailure(let message): return "Rendered image encoding failed: \(message)"
        case .cancelled: return "The render was cancelled."
        case .staleResult: return "A newer render request replaced this result."
        }
    }
}
