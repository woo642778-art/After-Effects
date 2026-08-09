import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VertexCore
import VertexExport

public enum AppleExportWriterError: Error, LocalizedError {
    case unsupportedFormat(ExportFormat)
    case unsupportedCodec(ExportVideoCodec)
    case cannotAddVideoInput
    case pixelBufferCreationFailed(OSStatus)
    case pixelBufferAppendFailed
    case imageCreationFailed
    case imageDestinationFailed
    case writerFailed(String)
    case frameCountInvalid

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format): "Unsupported export format: \(format.rawValue)"
        case .unsupportedCodec(let codec): "Unsupported video codec: \(codec.rawValue)"
        case .cannotAddVideoInput: "AVAssetWriter cannot add the requested video input."
        case .pixelBufferCreationFailed(let status): "CVPixelBuffer creation failed with OSStatus \(status)."
        case .pixelBufferAppendFailed: "AVAssetWriter failed to append a rendered frame."
        case .imageCreationFailed: "Could not convert rendered RGBA data into a CGImage."
        case .imageDestinationFailed: "Could not create or finalize the image export destination."
        case .writerFailed(let message): message
        case .frameCountInvalid: "Export frame count must be positive."
        }
    }
}

public actor AppleExportWriter {
    public typealias FrameProvider = @Sendable (Int64) async throws -> ExportRGBAFrame
    public typealias ProgressHandler = @Sendable (ExportProgressSnapshot) -> Void

    public init() {}

    @discardableResult
    public func export(
        job requestedJob: ExportJob,
        frameCount: Int64,
        frameProvider: @escaping FrameProvider,
        progress: @escaping ProgressHandler = { _ in },
        cancellation: ExportCancellationToken = ExportCancellationToken()
    ) async throws -> URL {
        let job = try requestedJob.validated()
        guard frameCount > 0 else { throw AppleExportWriterError.frameCountInvalid }
        let finalURL = job.outputURL
        try FileManager.default.createDirectory(at: finalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporaryURL = temporarySibling(of: finalURL, directory: job.format.isImageSequence)
        try removeIfExists(temporaryURL)
        do {
            let produced: URL
            switch job.format {
            case .mov, .mp4:
                produced = try await writeVideo(job: job, frameCount: frameCount, destination: temporaryURL, frameProvider: frameProvider, progress: progress, cancellation: cancellation)
            case .gif:
                produced = try await writeGIF(job: job, frameCount: frameCount, destination: temporaryURL, frameProvider: frameProvider, progress: progress, cancellation: cancellation)
            case .pngSequence, .jpegSequence:
                produced = try await writeImageSequence(job: job, frameCount: frameCount, directory: temporaryURL, frameProvider: frameProvider, progress: progress, cancellation: cancellation)
            }
            try await cancellation.throwIfCancelled()
            try removeIfExists(finalURL)
            try FileManager.default.moveItem(at: produced, to: finalURL)
            return finalURL
        } catch {
            try? removeIfExists(temporaryURL)
            throw error
        }
    }

    private func writeVideo(
        job: ExportJob,
        frameCount: Int64,
        destination: URL,
        frameProvider: @escaping FrameProvider,
        progress: @escaping ProgressHandler,
        cancellation: ExportCancellationToken
    ) async throws -> URL {
        let fileType: AVFileType = job.format == .mp4 ? .mp4 : .mov
        let writer = try AVAssetWriter(outputURL: destination, fileType: fileType)
        let codec = try codecType(job.codec)
        var compression: [String: Any] = [:]
        if job.codec == .h264 || job.codec == .hevc {
            compression[AVVideoAverageBitRateKey] = job.quality.targetBitRate(width: job.width, height: job.height, fps: job.fps)
            compression[AVVideoExpectedSourceFrameRateKey] = Int(job.fps.rounded())
            compression[AVVideoMaxKeyFrameIntervalKey] = max(1, Int(job.fps.rounded() * 2))
        }
        let settings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: job.width,
            AVVideoHeightKey: job.height,
            AVVideoCompressionPropertiesKey: compression
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { throw AppleExportWriterError.cannotAddVideoInput }
        writer.add(input)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: job.width,
                kCVPixelBufferHeightKey as String: job.height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
        )
        guard writer.startWriting() else {
            throw AppleExportWriterError.writerFailed(writer.error?.localizedDescription ?? "AVAssetWriter failed to start.")
        }
        writer.startSession(atSourceTime: .zero)

        do {
            for index in 0..<frameCount {
                try Task.checkCancellation()
                try await cancellation.throwIfCancelled()
                while !input.isReadyForMoreMediaData {
                    try Task.checkCancellation()
                    try await cancellation.throwIfCancelled()
                    if writer.status == .failed {
                        throw AppleExportWriterError.writerFailed(writer.error?.localizedDescription ?? "Video writer failed while waiting for input readiness.")
                    }
                    try await Task.sleep(for: .milliseconds(2))
                }
                let frame = try await frameProvider(index)
                guard frame.width == job.width, frame.height == job.height else {
                    throw ExportValidationError.frameSizeMismatch(expected: job.width * job.height * 4, actual: frame.rgba8.count)
                }
                let pixelBuffer = try makeBGRAPixelBuffer(frame)
                let exact = try job.exactPresentationTime(frameIndex: index)
                let time = CMTime(value: exact.value, timescale: exact.timescale)
                guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                    throw AppleExportWriterError.writerFailed(writer.error?.localizedDescription ?? AppleExportWriterError.pixelBufferAppendFailed.localizedDescription)
                }
                progress(ExportProgressSnapshot(completedFrames: index + 1, totalFrames: frameCount))
            }
            input.markAsFinished()
            await writer.finishWriting()
            guard writer.status == .completed else {
                throw AppleExportWriterError.writerFailed(writer.error?.localizedDescription ?? "AVAssetWriter did not complete successfully.")
            }
            return destination
        } catch {
            input.markAsFinished()
            writer.cancelWriting()
            try? removeIfExists(destination)
            throw error
        }
    }

    private func writeGIF(
        job: ExportJob,
        frameCount: Int64,
        destination: URL,
        frameProvider: @escaping FrameProvider,
        progress: @escaping ProgressHandler,
        cancellation: ExportCancellationToken
    ) async throws -> URL {
        guard let destinationRef = CGImageDestinationCreateWithURL(destination as CFURL, UTType.gif.identifier as CFString, Int(frameCount), nil) else {
            throw AppleExportWriterError.imageDestinationFailed
        }
        let delay = 1.0 / job.fps
        let fileProperties: [CFString: Any] = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(destinationRef, fileProperties as CFDictionary)
        for index in 0..<frameCount {
            try Task.checkCancellation()
            try await cancellation.throwIfCancelled()
            let frame = try await frameProvider(index)
            let image = try makeCGImage(frame)
            let frameProperties: [CFString: Any] = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]]
            CGImageDestinationAddImage(destinationRef, image, frameProperties as CFDictionary)
            progress(ExportProgressSnapshot(completedFrames: index + 1, totalFrames: frameCount))
        }
        guard CGImageDestinationFinalize(destinationRef) else { throw AppleExportWriterError.imageDestinationFailed }
        return destination
    }

    private func writeImageSequence(
        job: ExportJob,
        frameCount: Int64,
        directory: URL,
        frameProvider: @escaping FrameProvider,
        progress: @escaping ProgressHandler,
        cancellation: ExportCancellationToken
    ) async throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let type = job.format == .pngSequence ? UTType.png : UTType.jpeg
        let extensionName = job.format == .pngSequence ? "png" : "jpg"
        for index in 0..<frameCount {
            try Task.checkCancellation()
            try await cancellation.throwIfCancelled()
            let frame = try await frameProvider(index)
            let image = try makeCGImage(frame)
            let fileURL = directory.appendingPathComponent(String(format: "frame_%06lld.%@", index + 1, extensionName))
            guard let destinationRef = CGImageDestinationCreateWithURL(fileURL as CFURL, type.identifier as CFString, 1, nil) else {
                throw AppleExportWriterError.imageDestinationFailed
            }
            let options: [CFString: Any] = job.format == .jpegSequence ? [kCGImageDestinationLossyCompressionQuality: job.quality.jpegQuality] : [:]
            CGImageDestinationAddImage(destinationRef, image, options as CFDictionary)
            guard CGImageDestinationFinalize(destinationRef) else { throw AppleExportWriterError.imageDestinationFailed }
            progress(ExportProgressSnapshot(completedFrames: index + 1, totalFrames: frameCount))
        }
        return directory
    }

    private func codecType(_ codec: ExportVideoCodec?) throws -> AVVideoCodecType {
        guard let codec else { throw ExportValidationError.codecRequired }
        switch codec {
        case .h264: return .h264
        case .hevc: return .hevc
        case .proRes422: return .proRes422
        case .proRes4444: return .proRes4444
        }
    }

    private func makeBGRAPixelBuffer(_ frame: ExportRGBAFrame) throws -> CVPixelBuffer {
        var optional: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, frame.width, frame.height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &optional)
        guard status == kCVReturnSuccess, let pixelBuffer = optional else { throw AppleExportWriterError.pixelBufferCreationFailed(status) }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { throw AppleExportWriterError.pixelBufferCreationFailed(kCVReturnInvalidArgument) }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        frame.rgba8.withUnsafeBytes { source in
            guard let src = source.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let dst = base.assumingMemoryBound(to: UInt8.self)
            for y in 0..<frame.height {
                let srcRow = src.advanced(by: y * frame.width * 4)
                let dstRow = dst.advanced(by: y * bytesPerRow)
                for x in 0..<frame.width {
                    let s = srcRow.advanced(by: x * 4)
                    let d = dstRow.advanced(by: x * 4)
                    d[0] = s[2]
                    d[1] = s[1]
                    d[2] = s[0]
                    d[3] = s[3]
                }
            }
        }
        return pixelBuffer
    }

    private func makeCGImage(_ frame: ExportRGBAFrame) throws -> CGImage {
        guard let provider = CGDataProvider(data: frame.rgba8 as CFData),
              let image = CGImage(
                width: frame.width,
                height: frame.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: frame.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else { throw AppleExportWriterError.imageCreationFailed }
        return image
    }

    private func temporarySibling(of finalURL: URL, directory: Bool) -> URL {
        let suffix = UUID().uuidString
        if directory {
            return finalURL.deletingLastPathComponent().appendingPathComponent(".\(finalURL.lastPathComponent).\(suffix).partial", isDirectory: true)
        }
        let ext = finalURL.pathExtension
        let stem = finalURL.deletingPathExtension().lastPathComponent
        return finalURL.deletingLastPathComponent().appendingPathComponent(".\(stem).\(suffix).partial.\(ext)")
    }

    private func removeIfExists(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
