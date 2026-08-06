import Foundation

public enum MediaError: Error, Equatable, Sendable, LocalizedError {
    case unsupportedAsset(String)
    case missingVideoStream
    case missingAudioStream
    case invalidRequest(String)
    case cancelled
    case decodeFailed(String)
    case permissionDenied(String)
    case ioFailure(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedAsset(let reason): "Unsupported media: \(reason)"
        case .missingVideoStream: "The asset has no video stream."
        case .missingAudioStream: "The asset has no audio stream."
        case .invalidRequest(let reason): "Invalid media request: \(reason)"
        case .cancelled: "The media request was cancelled."
        case .decodeFailed(let reason): "Media decoding failed: \(reason)"
        case .permissionDenied(let reason): "Media access was denied: \(reason)"
        case .ioFailure(let reason): "Media I/O failed: \(reason)"
        }
    }
}
