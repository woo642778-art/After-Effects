import Foundation
@preconcurrency import AVFoundation
import VertexAI
import VertexCore

public struct AIVideoSourceInfo: Codable, Equatable, Sendable {
    public let frameCount: Int64
    public let duration: RationalTime
    public let width: Int
    public let height: Int
    public let hasAudio: Bool
    public let sourceRangeDigest: String

    public init(
        frameCount: Int64,
        duration: RationalTime,
        width: Int,
        height: Int,
        hasAudio: Bool
    ) throws {
        guard frameCount > 0, duration > .zero, width > 0, height > 0 else {
            throw AIError.invalidJobState("Video source must contain positive frames, duration, and dimensions.")
        }
        self.frameCount = frameCount
        self.duration = duration
        self.width = width
        self.height = height
        self.hasAudio = hasAudio
        let identity = "\(frameCount)|\(duration.value)|\(duration.timescale)|\(width)x\(height)|audio:\(hasAudio)"
        self.sourceRangeDigest = AIDigest.sha256(Data(identity.utf8))
    }
}

public enum AIVideoSourceInspector {
    public static func inspect(url: URL) async throws -> AIVideoSourceInfo {
        let asset = AVURLAsset(url: url)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = videoTracks.first else {
            throw AIError.invalidJobState("AI video source contains no video track.")
        }
        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let duration = try await asset.load(.duration)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let orientedRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let width = Int(abs(orientedRect.width).rounded())
        let height = Int(abs(orientedRect.height).rounded())
        let rationalDuration = try rationalTime(duration)
        let frameCount = try countFrames(asset: asset, track: track)
        return try AIVideoSourceInfo(
            frameCount: frameCount,
            duration: rationalDuration,
            width: width,
            height: height,
            hasAudio: !audioTracks.isEmpty
        )
    }

    private static func countFrames(asset: AVAsset, track: AVAssetTrack) throws -> Int64 {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw AIError.invalidJobState("AVFoundation cannot attach a video frame counter to this source.")
        }
        reader.add(output)
        guard reader.startReading() else {
            throw AIError.invalidJobState("AVFoundation could not start frame inspection: \(reader.error?.localizedDescription ?? "unknown error")")
        }
        var count: Int64 = 0
        while output.copyNextSampleBuffer() != nil { count += 1 }
        guard reader.status == .completed else {
            throw AIError.invalidJobState("Video frame inspection failed: \(reader.error?.localizedDescription ?? "unknown error")")
        }
        return count
    }

    private static func rationalTime(_ time: CMTime) throws -> RationalTime {
        guard time.isNumeric, time.value > 0, time.timescale > 0 else {
            throw AIError.invalidJobState("Video source duration is invalid.")
        }
        return RationalTime(value: time.value, timescale: time.timescale)
    }
}
