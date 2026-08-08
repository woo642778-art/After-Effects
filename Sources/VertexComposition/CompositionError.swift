import Foundation

public enum CompositionError: Error, Equatable, Sendable, LocalizedError {
    case missingComposition(String)
    case missingLayer(String)
    case missingMedia(String)
    case invalidLayerOrder(String)
    case invalidTimingRange(String)
    case invalidTransform(String)
    case unsupportedBlendMode(String)
    case nestedCompositionCycle([String])
    case nestingDepthExceeded(Int)
    case layerLimitExceeded(Int)
    case nodeLimitExceeded(Int)
    case frameResolutionFailed(String)
    case effectResolutionFailed(layerID: String, effectID: String, effectType: String, time: String, message: String)
    case graphCompilationFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .missingComposition(let id): "Composition is missing: \(id)"
        case .missingLayer(let id): "Layer is missing: \(id)"
        case .missingMedia(let id): "Participating media is missing: \(id)"
        case .invalidLayerOrder(let message): "Invalid layer order: \(message)"
        case .invalidTimingRange(let message): "Invalid layer timing: \(message)"
        case .invalidTransform(let message): "Invalid layer transform: \(message)"
        case .unsupportedBlendMode(let mode): "Unsupported blend mode: \(mode)"
        case .nestedCompositionCycle(let ids): "Nested composition cycle: \(ids.joined(separator: " → "))"
        case .nestingDepthExceeded(let value): "Nested composition depth exceeded: \(value)"
        case .layerLimitExceeded(let value): "Composition layer limit exceeded: \(value)"
        case .nodeLimitExceeded(let value): "Expanded render-node limit exceeded: \(value)"
        case .frameResolutionFailed(let message): "Media frame resolution failed: \(message)"
        case .effectResolutionFailed(let layerID, let effectID, let effectType, let time, let message):
            "Effect resolution failed on layer \(layerID), effect \(effectID) (\(effectType)) at \(time): \(message)"
        case .graphCompilationFailed(let message): "Composition graph compilation failed: \(message)"
        case .cancelled: "Composition compilation was cancelled."
        }
    }
}
