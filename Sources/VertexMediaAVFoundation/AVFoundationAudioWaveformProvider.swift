#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import VertexMedia

public actor AVFoundationAudioWaveformProvider: AudioWaveformProvider {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func waveform(for request: AudioWaveformRequest, cancellationToken: MediaCancellationToken) async throws -> AudioWaveform {
        do {
            try await cancellationToken.throwIfCancelled()
            try Task.checkCancellation()

            let asset = AVURLAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else { throw MediaError.missingAudioStream }

            let formatDescriptions = try await track.load(.formatDescriptions)
            let audio = AVFoundationMediaMapping.audioProperties(from: formatDescriptions.first)
            guard audio.sampleRate > 0, audio.channels > 0 else {
                throw MediaError.decodeFailed("The audio stream format is unavailable.")
            }

            let reader = try AVAssetReader(asset: asset)
            reader.timeRange = CMTimeRange(
                start: AVFoundationMediaMapping.cmTime(request.timeRange.start),
                duration: AVFoundationMediaMapping.cmTime(request.timeRange.duration)
            )
            let output = AVAssetReaderTrackOutput(
                track: track,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
            )
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else {
                throw MediaError.decodeFailed("AVAssetReader rejected the audio output configuration.")
            }
            reader.add(output)

            let estimatedFrames = max(
                request.bucketCount,
                Int(ceil(request.timeRange.duration.seconds * audio.sampleRate))
            )
            var accumulator = try WaveformAccumulator(
                totalFrames: estimatedFrames,
                channelCount: audio.channels,
                bucketCount: request.bucketCount
            )

            guard reader.startReading() else {
                throw MediaError.decodeFailed(reader.error?.localizedDescription ?? "AVAssetReader did not start.")
            }

            while let sampleBuffer = output.copyNextSampleBuffer() {
                do {
                    try Task.checkCancellation()
                    try await cancellationToken.throwIfCancelled()
                } catch {
                    reader.cancelReading()
                    throw MediaError.cancelled
                }

                let samples = try Self.floatSamples(from: sampleBuffer)
                if !samples.isEmpty {
                    try accumulator.append(interleavedSamples: samples)
                }
            }

            if reader.status == .failed {
                throw MediaError.decodeFailed(reader.error?.localizedDescription ?? "Audio decoding failed.")
            }
            if reader.status == .cancelled {
                throw MediaError.cancelled
            }
            return try accumulator.finalize()
        } catch is CancellationError {
            throw MediaError.cancelled
        } catch let error as MediaError {
            throw error
        } catch {
            throw MediaError.decodeFailed(error.localizedDescription)
        }
    }

    private static func floatSamples(from sampleBuffer: CMSampleBuffer) throws -> [Float] {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return [] }

        var lengthAtOffset = 0
        var totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )
        guard status == kCMBlockBufferNoErr, let dataPointer else {
            throw MediaError.decodeFailed("Unable to read decoded PCM sample bytes.")
        }

        let sampleCount = totalLength / MemoryLayout<Float>.stride
        let floatPointer = UnsafeRawPointer(dataPointer).assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: floatPointer, count: sampleCount))
    }
}
#endif
