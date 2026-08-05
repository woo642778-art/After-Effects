import Foundation

public enum MediaBackPressurePolicy: Equatable, Sendable {
    case latestWins
    case fifo(maxPending: Int)
    case rejectWhenBusy
}

public actor MediaCancellationToken {
    private var isCancelled = false

    public init() {}

    public func cancel() {
        isCancelled = true
    }

    public func throwIfCancelled() throws {
        if isCancelled {
            throw MediaError.cancelled
        }
    }
}

public protocol MediaAssetInspecting: Sendable {
    func inspect(url: URL, cancellationToken: MediaCancellationToken) async throws -> MediaAssetDescriptor
}

public protocol VideoFrameProvider: Sendable {
    func frame(for request: VideoFrameRequest, cancellationToken: MediaCancellationToken) async throws -> VideoFrame
}

public protocol AudioWaveformProvider: Sendable {
    func waveform(for request: AudioWaveformRequest, cancellationToken: MediaCancellationToken) async throws -> AudioWaveform
}
