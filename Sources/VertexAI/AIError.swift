import Foundation

public enum AIError: Error, Equatable, Sendable {
    case invalidManifest(String)
    case modelUnavailable(String)
    case checksumMismatch(modelID: String)
    case unsupportedCapability(String)
    case invalidRecipe(String)
    case invalidJobState(String)
    case inferenceFailed(String)
    case cancelled
    case outputVerificationFailed(String)
}

extension AIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidManifest(let message):
            "Invalid AI model manifest: \(message)"
        case .modelUnavailable(let modelID):
            "AI model is unavailable: \(modelID)"
        case .checksumMismatch(let modelID):
            "AI model checksum mismatch: \(modelID)"
        case .unsupportedCapability(let message):
            "Unsupported AI capability: \(message)"
        case .invalidRecipe(let message):
            "Invalid AI recipe: \(message)"
        case .invalidJobState(let message):
            "Invalid AI job state: \(message)"
        case .inferenceFailed(let message):
            "AI inference failed: \(message)"
        case .cancelled:
            "AI processing was cancelled."
        case .outputVerificationFailed(let message):
            "AI output verification failed: \(message)"
        }
    }
}
