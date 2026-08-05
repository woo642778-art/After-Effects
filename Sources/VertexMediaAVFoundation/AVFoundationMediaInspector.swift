#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import Foundation
import VertexCore
import VertexMedia

public actor AVFoundationMediaInspector: MediaAssetInspecting {
    public init() {}

    public func inspect(url: URL, cancellationToken: MediaCancellationToken) async throws -> MediaAssetDescriptor {
        try await cancellationToken.throwIfCancelled()
        try Task.checkCancellation()

        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            guard duration.isNumeric, duration.value >= 0 else {
                throw MediaError.unsupportedAsset("The asset duration is invalid or indefinite.")
            }

            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            try await cancellationToken.throwIfCancelled()
            try Task.checkCancellation()

            var videoDescriptors: [VideoStreamDescriptor] = []
            for (index, track) in videoTracks.enumerated() {
                let naturalSize = try await track.load(.naturalSize)
                let transform = try await track.load(.preferredTransform)
                let nominalFrameRate = try await track.load(.nominalFrameRate)
                let minimumFrameDuration = try await track.load(.minFrameDuration)
                let formatDescriptions = try await track.load(.formatDescriptions)
                let formatDescription = formatDescriptions.first
                let color = AVFoundationMediaMapping.colorProperties(from: formatDescription)

                videoDescriptors.append(
                    VideoStreamDescriptor(
                        streamIndex: index,
                        pixelSize: AVFoundationMediaMapping.displayedSize(
                            naturalSize: naturalSize,
                            preferredTransform: transform
                        ),
                        nominalFrameRate: Double(nominalFrameRate),
                        variableFrameRateStatus: AVFoundationMediaMapping.variableFrameRateStatus(
                            nominalFrameRate: nominalFrameRate,
                            minimumFrameDuration: minimumFrameDuration
                        ),
                        codec: AVFoundationMediaMapping.codecName(from: formatDescription),
                        color: color.descriptor,
                        isHDR: color.isHDR,
                        hasAlpha: color.hasAlpha,
                        rotationDegrees: AVFoundationMediaMapping.rotationDegrees(transform)
                    )
                )
            }

            var audioDescriptors: [AudioStreamDescriptor] = []
            for (index, track) in audioTracks.enumerated() {
                let formatDescriptions = try await track.load(.formatDescriptions)
                let estimatedDataRate = try await track.load(.estimatedDataRate)
                let formatDescription = formatDescriptions.first
                let audio = AVFoundationMediaMapping.audioProperties(from: formatDescription)

                audioDescriptors.append(
                    AudioStreamDescriptor(
                        streamIndex: index,
                        sampleRate: audio.sampleRate,
                        channelCount: audio.channels,
                        codec: AVFoundationMediaMapping.codecName(from: formatDescription),
                        estimatedBitRate: estimatedDataRate > 0 ? estimatedDataRate : nil
                    )
                )
            }

            return try MediaAssetDescriptor(
                filename: url.lastPathComponent,
                duration: AVFoundationMediaMapping.rationalTime(duration),
                containerHint: url.pathExtension.isEmpty ? nil : url.pathExtension.lowercased(),
                videoStreams: videoDescriptors,
                audioStreams: audioDescriptors
            ).validated()
        } catch is CancellationError {
            throw MediaError.cancelled
        } catch let error as MediaError {
            throw error
        } catch {
            throw MediaError.ioFailure(error.localizedDescription)
        }
    }
}
#endif
