import Foundation
@preconcurrency import AVFoundation
import VertexAI

final class AIVideoFinalizer: @unchecked Sendable {
    func finalize(
        sourceURL: URL,
        chunkManifests: [AIChunkArtifactManifest],
        jobRoot: URL,
        destinationURL: URL,
        preserveAudio: Bool
    ) async throws {
        guard !chunkManifests.isEmpty else {
            throw AIError.outputVerificationFailed("Cannot finalize an AI video without completed chunks.")
        }
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AIError.outputVerificationFailed("Could not create final AI video track.")
        }

        var cursor = CMTime.zero
        for manifest in chunkManifests.sorted(by: { $0.chunkIndex < $1.chunkIndex }) {
            let chunkURL = jobRoot.appendingPathComponent(manifest.videoFilename)
            let chunkAsset = AVURLAsset(url: chunkURL)
            let tracks = try await chunkAsset.loadTracks(withMediaType: .video)
            guard let sourceTrack = tracks.first else {
                throw AIError.outputVerificationFailed("Completed AI chunk \(manifest.chunkIndex) has no video track.")
            }
            let duration = try await chunkAsset.load(.duration)
            guard duration.isNumeric, duration > .zero else {
                throw AIError.outputVerificationFailed("Completed AI chunk \(manifest.chunkIndex) has invalid duration.")
            }
            do {
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: sourceTrack,
                    at: cursor
                )
            } catch {
                throw AIError.outputVerificationFailed("Could not assemble AI video chunk \(manifest.chunkIndex): \(error.localizedDescription)")
            }
            cursor = CMTimeAdd(cursor, duration)
        }

        if preserveAudio {
            let sourceAsset = AVURLAsset(url: sourceURL)
            let audioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)
            if let originalAudio = audioTracks.first,
               let audioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                let sourceDuration = try await sourceAsset.load(.duration)
                let duration = CMTimeMinimum(sourceDuration, cursor)
                if duration > .zero {
                    do {
                        try audioTrack.insertTimeRange(
                            CMTimeRange(start: .zero, duration: duration),
                            of: originalAudio,
                            at: .zero
                        )
                    } catch {
                        throw AIError.outputVerificationFailed("Could not preserve source audio: \(error.localizedDescription)")
                    }
                }
            }
        }

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw AIError.outputVerificationFailed("Could not create passthrough final AI exporter.")
        }
        exporter.outputURL = destinationURL
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = false
        await export(exporter)
        guard exporter.status == .completed else {
            throw AIError.outputVerificationFailed(
                "Final AI video export failed: \(exporter.error?.localizedDescription ?? "unknown error")"
            )
        }
        guard FileManager.default.fileExists(atPath: destinationURL.path),
              (try destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0 else {
            throw AIError.outputVerificationFailed("Final AI video export produced no file bytes.")
        }
    }

    private func export(_ session: AVAssetExportSession) async {
        await withCheckedContinuation { continuation in
            session.exportAsynchronously {
                continuation.resume()
            }
        }
    }
}
