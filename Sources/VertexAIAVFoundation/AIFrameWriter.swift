import Foundation
@preconcurrency import AVFoundation
import VertexAI
import VertexAICoreML

#if canImport(CoreMedia) && canImport(CoreVideo)
import CoreMedia
import CoreVideo

final class AIFrameWriter: @unchecked Sendable {
    let outputURL: URL
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private var firstPTS: CMTime?
    private var appendedFrameCount: Int64 = 0

    init(outputURL: URL, width: Int, height: Int, recipe: AITaskRecipe) throws {
        guard width > 0, height > 0 else {
            throw AIError.outputVerificationFailed("AI video writer requires positive dimensions.")
        }
        self.outputURL = outputURL
        try? FileManager.default.removeItem(at: outputURL)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        } catch {
            throw AIError.outputVerificationFailed("Could not create AI video writer: \(error.localizedDescription)")
        }

        let codec: AVVideoCodecType
        switch recipe {
        case .cutout:
            codec = .hevcWithAlpha
        default:
            codec = .hevc
        }
        let pixels = max(1, width * height)
        let estimatedBitrate = min(120_000_000, max(8_000_000, pixels * 10))
        let settings: [String: Any] = [
            AVVideoCodecKey: codec.rawValue,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: estimatedBitrate,
                AVVideoExpectedSourceFrameRateKey: 60,
                AVVideoMaxKeyFrameIntervalKey: 120
            ]
        ]
        input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else {
            throw AIError.unsupportedCapability(
                recipe.isCutout
                    ? "This device cannot encode the required HEVC-with-alpha Cutout output."
                    : "This device cannot encode the required HEVC AI output."
            )
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw AIError.outputVerificationFailed(
                "AI video writer could not start: \(writer.error?.localizedDescription ?? "unknown error")"
            )
        }
        writer.startSession(atSourceTime: .zero)
    }

    func append(
        pixelBuffer: CVPixelBuffer,
        presentationTime: CMTime,
        duration: CMTime,
        shouldCancel: () -> Bool
    ) throws {
        guard presentationTime.isNumeric, duration.isNumeric, duration > .zero else {
            throw AIError.outputVerificationFailed("AI output frame requires numeric PTS and positive duration.")
        }
        if shouldCancel() { throw AIError.cancelled }
        if firstPTS == nil { firstPTS = presentationTime }
        let localPTS = CMTimeSubtract(presentationTime, firstPTS ?? .zero)
        var description: CMVideoFormatDescription?
        let descriptionStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &description
        )
        guard descriptionStatus == noErr, let description else {
            throw AIError.outputVerificationFailed("Could not create AI output video format description.")
        }
        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: localPTS,
            decodeTimeStamp: .invalid
        )
        var sample: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: description,
            sampleTiming: &timing,
            sampleBufferOut: &sample
        )
        guard sampleStatus == noErr, let sample else {
            throw AIError.outputVerificationFailed("Could not create AI output sample buffer.")
        }

        while !input.isReadyForMoreMediaData {
            if shouldCancel() { throw AIError.cancelled }
            if writer.status == .failed || writer.status == .cancelled {
                throw AIError.outputVerificationFailed(
                    "AI video writer stopped before accepting a frame: \(writer.error?.localizedDescription ?? "unknown error")"
                )
            }
            Thread.sleep(forTimeInterval: 0.002)
        }
        guard input.append(sample) else {
            throw AIError.outputVerificationFailed(
                "AI video writer rejected a frame: \(writer.error?.localizedDescription ?? "unknown error")"
            )
        }
        appendedFrameCount += 1
    }

    func finish() async throws {
        guard appendedFrameCount > 0 else {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            throw AIError.outputVerificationFailed("AI chunk contained no output frames.")
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw AIError.outputVerificationFailed(
                "AI video writer did not finish successfully: \(writer.error?.localizedDescription ?? "unknown error")"
            )
        }
        guard FileManager.default.fileExists(atPath: outputURL.path),
              (try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0 else {
            throw AIError.outputVerificationFailed("AI video writer produced no file bytes.")
        }
    }

    func cancelAndDelete() {
        input.markAsFinished()
        writer.cancelWriting()
        try? FileManager.default.removeItem(at: outputURL)
    }
}

private extension AITaskRecipe {
    var isCutout: Bool {
        if case .cutout = self { return true }
        return false
    }
}

final class AIDepthChunkWriter: @unchecked Sendable {
    let outputURL: URL
    private let handle: FileHandle
    private let width: Int
    private let height: Int
    private var frameCount: Int64 = 0

    init(outputURL: URL, width: Int, height: Int) throws {
        self.outputURL = outputURL
        self.width = width
        self.height = height
        try? FileManager.default.removeItem(at: outputURL)
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        do {
            handle = try FileHandle(forWritingTo: outputURL)
        } catch {
            throw AIError.outputVerificationFailed("Could not create high-precision depth sidecar: \(error.localizedDescription)")
        }
        var header = Data("VXDEPTH1".utf8)
        appendInteger(Int32(width), to: &header)
        appendInteger(Int32(height), to: &header)
        try handle.write(contentsOf: header)
    }

    deinit { try? handle.close() }

    func append(frame: DepthFrame, presentationTime: CMTime) throws {
        guard frame.width == width, frame.height == height,
              presentationTime.isNumeric, presentationTime.timescale > 0 else {
            throw AIError.outputVerificationFailed("Depth sidecar frame does not match its declared geometry/timing.")
        }
        var data = Data()
        appendInteger(presentationTime.value, to: &data)
        appendInteger(presentationTime.timescale, to: &data)
        appendInteger(Int32(frame.values.count), to: &data)
        data.reserveCapacity(data.count + frame.values.count * 4)
        for value in frame.values {
            var bits = value.bitPattern.littleEndian
            withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
        }
        do {
            try handle.write(contentsOf: data)
            frameCount += 1
        } catch {
            throw AIError.outputVerificationFailed("Could not write high-precision depth frame: \(error.localizedDescription)")
        }
    }

    func finish() throws {
        guard frameCount > 0 else {
            try? handle.close()
            try? FileManager.default.removeItem(at: outputURL)
            throw AIError.outputVerificationFailed("Depth sidecar contained no frames.")
        }
        try handle.synchronize()
        try handle.close()
    }

    func cancelAndDelete() {
        try? handle.close()
        try? FileManager.default.removeItem(at: outputURL)
    }
}

private func appendInteger<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}

#endif
