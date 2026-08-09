@preconcurrency import AVFoundation
import Foundation
import VertexComposition
import VertexCore
import VertexMedia
import VertexMediaAVFoundation
import VertexProject
import VertexProjectPersistence

actor CompositionMediaFrameResolver: CompositionInterpolatingFrameResolver {
    private let project: ProjectDocument
    private let packageURL: URL?
    private let embeddedStore = EmbeddedMediaStore()
    private let bookmarkStore = BookmarkSidecarStore()
    private let interpolator = AppleFrameInterpolator()

    init(project: ProjectDocument, packageURL: URL?) {
        self.project = project
        self.packageURL = packageURL
    }

    func resolve(
        mediaID: VertexID,
        exactSourceTime: RationalTime,
        targetSize: VertexSize
    ) async throws -> CompositionFrameResolution {
        try await resolve(
            mediaID: mediaID,
            exactSourceTime: exactSourceTime,
            targetSize: targetSize,
            interpolation: .nearest
        )
    }

    func resolve(
        mediaID: VertexID,
        exactSourceTime: RationalTime,
        targetSize: VertexSize,
        interpolation: ProjectFrameInterpolationMode
    ) async throws -> CompositionFrameResolution {
        let url = try resolvedURL(mediaID: mediaID)
        let hasScope = url.startAccessingSecurityScopedResource()
        defer { if hasScope { url.stopAccessingSecurityScopedResource() } }

        do {
            let provider = AVFoundationVideoFrameProvider(url: url)
            switch interpolation {
            case .nearest:
                let request = try VideoFrameRequest(time: exactSourceTime, targetSize: targetSize, tolerance: .exact)
                return .frame(try await provider.frame(for: request, cancellationToken: MediaCancellationToken()).image)

            case .frameMix, .opticalFlow:
                let frameDuration = try await exactFrameDuration(url: url)
                let frameIndex = try floorFrameIndex(time: exactSourceTime, frameDuration: frameDuration)
                let leftTime = try multiply(frameDuration, by: frameIndex)
                let rightTime = try leftTime.adding(frameDuration)
                let elapsed = try exactSourceTime.subtracting(leftTime)
                let progress = min(max(elapsed.seconds / frameDuration.seconds, 0), 1)
                if progress <= 1e-12 {
                    let request = try VideoFrameRequest(time: leftTime, targetSize: targetSize, tolerance: .exact)
                    return .frame(try await provider.frame(for: request, cancellationToken: MediaCancellationToken()).image)
                }
                let leftRequest = try VideoFrameRequest(time: leftTime, targetSize: targetSize, tolerance: .exact)
                let rightRequest = try VideoFrameRequest(time: rightTime, targetSize: targetSize, tolerance: .exact)
                let left = try await provider.frame(for: leftRequest, cancellationToken: MediaCancellationToken()).image
                let right = try await provider.frame(for: rightRequest, cancellationToken: MediaCancellationToken()).image
                switch interpolation {
                case .frameMix:
                    return .frame(try interpolator.frameMix(from: left, to: right, progress: progress))
                case .opticalFlow:
                    return .frame(try interpolator.opticalFlow(from: left, to: right, progress: progress))
                case .nearest:
                    return .frame(left)
                }
            }
        } catch MediaError.cancelled {
            throw CompositionError.cancelled
        } catch let error as FrameInterpolationError {
            throw CompositionError.frameResolutionFailed(error.localizedDescription)
        } catch let error as CompositionError {
            throw error
        } catch {
            throw CompositionError.frameResolutionFailed(error.localizedDescription)
        }
    }

    private func resolvedURL(mediaID: VertexID) throws -> URL {
        guard let reference = project.mediaRegistry.first(where: { $0.id == mediaID }) else {
            throw CompositionError.missingMedia(mediaID.rawValue)
        }
        guard let packageURL else { throw CompositionError.missingMedia(mediaID.rawValue) }
        let url: URL
        if let embedded = try embeddedStore.resolve(reference: reference, packageURL: packageURL) {
            url = embedded
        } else if let external = try bookmarkStore.resolveAndRefreshIfNeeded(mediaID: mediaID, in: packageURL) {
            url = external
        } else {
            throw CompositionError.missingMedia(mediaID.rawValue)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CompositionError.missingMedia(mediaID.rawValue)
        }
        return url
    }

    private func exactFrameDuration(url: URL) async throws -> RationalTime {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw CompositionError.frameResolutionFailed("Media has no video track.")
        }
        var duration = try await track.load(.minFrameDuration)
        if !duration.isValid || duration.value <= 0 {
            let rate = try await track.load(.nominalFrameRate)
            guard rate.isFinite, rate > 0 else {
                throw CompositionError.frameResolutionFailed("Video frame rate is unavailable.")
            }
            duration = CMTime(seconds: 1 / Double(rate), preferredTimescale: 60_000)
        }
        guard duration.isValid, duration.value > 0, duration.timescale > 0 else {
            throw CompositionError.frameResolutionFailed("Video frame duration is invalid.")
        }
        return RationalTime(value: duration.value, timescale: duration.timescale)
    }

    private func floorFrameIndex(time: RationalTime, frameDuration: RationalTime) throws -> Int64 {
        guard time >= .zero, frameDuration > .zero else { return 0 }
        let lhs = time.value.multipliedReportingOverflow(by: Int64(frameDuration.timescale))
        let rhs = Int64(time.timescale).multipliedReportingOverflow(by: frameDuration.value)
        guard !lhs.overflow, !rhs.overflow, rhs.partialValue > 0 else {
            throw CompositionError.frameResolutionFailed("Frame index overflowed exact timing range.")
        }
        return lhs.partialValue / rhs.partialValue
    }

    private func multiply(_ time: RationalTime, by value: Int64) throws -> RationalTime {
        let product = time.value.multipliedReportingOverflow(by: value)
        guard !product.overflow else {
            throw CompositionError.frameResolutionFailed("Frame timestamp overflowed exact timing range.")
        }
        return RationalTime(value: product.partialValue, timescale: time.timescale)
    }
}
