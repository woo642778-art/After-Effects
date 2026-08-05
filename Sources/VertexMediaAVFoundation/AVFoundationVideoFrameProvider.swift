#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VertexCore
import VertexMedia

public actor AVFoundationVideoFrameProvider: VideoFrameProvider {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func frame(for request: VideoFrameRequest, cancellationToken: MediaCancellationToken) async throws -> VideoFrame {
        do {
            try await cancellationToken.throwIfCancelled()
            try Task.checkCancellation()

            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: request.targetSize.width, height: request.targetSize.height)

            switch request.tolerance {
            case .exact:
                generator.requestedTimeToleranceBefore = .zero
                generator.requestedTimeToleranceAfter = .zero
            case .nearest:
                generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 30)
                generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
            }

            var actualTime = CMTime.invalid
            let image = try generator.copyCGImage(
                at: AVFoundationMediaMapping.cmTime(request.time),
                actualTime: &actualTime
            )

            try await cancellationToken.throwIfCancelled()
            try Task.checkCancellation()

            let encoded = try Self.encodePNG(image)
            let portableImage = try PortableImage(
                data: encoded,
                format: .png,
                pixelSize: VertexSize(width: Double(image.width), height: Double(image.height))
            )
            return VideoFrame(
                requestedTime: request.time,
                actualTime: AVFoundationMediaMapping.rationalTime(actualTime),
                image: portableImage
            )
        } catch is CancellationError {
            throw MediaError.cancelled
        } catch let error as MediaError {
            throw error
        } catch {
            throw MediaError.decodeFailed(error.localizedDescription)
        }
    }

    private static func encodePNG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw MediaError.decodeFailed("Unable to create a PNG image destination.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw MediaError.decodeFailed("Unable to encode the decoded video frame as PNG.")
        }
        return data as Data
    }
}
#endif
