#if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreVideo) && canImport(ImageIO) && canImport(UniformTypeIdentifiers) && canImport(Vision)
import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VertexCore
import VertexMedia
import Vision

public enum FrameInterpolationError: LocalizedError, Equatable, Sendable {
    case invalidProgress
    case imageDecodeFailed
    case dimensionMismatch
    case motionEstimationFailed
    case unsupportedFlowFormat
    case imageEncodeFailed

    public var errorDescription: String? {
        switch self {
        case .invalidProgress: "Frame interpolation progress must be within 0...1."
        case .imageDecodeFailed: "An interpolation source frame could not be decoded."
        case .dimensionMismatch: "Optical-flow frames must have identical dimensions."
        case .motionEstimationFailed: "Vision could not produce a usable optical-flow field."
        case .unsupportedFlowFormat: "Vision returned an unsupported optical-flow pixel format."
        case .imageEncodeFailed: "The interpolated frame could not be encoded."
        }
    }
}

public struct AppleFrameInterpolator: Sendable {
    public init() {}

    public func frameMix(
        from first: PortableImage,
        to second: PortableImage,
        progress: Double
    ) throws -> PortableImage {
        let progress = try validatedProgress(progress)
        let a = try decode(first)
        let b = try decode(second)
        guard a.width == b.width, a.height == b.height else { throw FrameInterpolationError.dimensionMismatch }
        let rgbaA = try rgba(a)
        let rgbaB = try rgba(b)
        let lhs = [UInt8](rgbaA)
        let rhs = [UInt8](rgbaB)
        let inverseProgress = 1 - progress
        var result = [UInt8](repeating: 0, count: lhs.count)
        for index in result.indices {
            let blended = Double(lhs[index]) * inverseProgress + Double(rhs[index]) * progress
            result[index] = UInt8(clamping: Int(blended.rounded()))
        }
        return try encodeRGBA(Data(result), width: a.width, height: a.height)
    }

    public func opticalFlow(
        from first: PortableImage,
        to second: PortableImage,
        progress: Double,
        accuracy: VNGenerateOpticalFlowRequest.ComputationAccuracy = .high
    ) throws -> PortableImage {
        let progress = try validatedProgress(progress)
        if progress == 0 { return first }
        if progress == 1 { return second }
        let a = try decode(first)
        let b = try decode(second)
        guard a.width == b.width, a.height == b.height else { throw FrameInterpolationError.dimensionMismatch }

        let request = VNGenerateOpticalFlowRequest(targetedCGImage: b, options: [:])
        request.computationAccuracy = accuracy
        request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float
        request.keepNetworkOutput = false
        do {
            try VNImageRequestHandler(cgImage: a, options: [:]).perform([request])
        } catch {
            throw FrameInterpolationError.motionEstimationFailed
        }
        guard let flow = request.results?.first?.pixelBuffer else {
            throw FrameInterpolationError.motionEstimationFailed
        }
        guard CVPixelBufferGetPixelFormatType(flow) == kCVPixelFormatType_TwoComponent32Float else {
            throw FrameInterpolationError.unsupportedFlowFormat
        }
        guard CVPixelBufferGetWidth(flow) == a.width, CVPixelBufferGetHeight(flow) == a.height else {
            throw FrameInterpolationError.motionEstimationFailed
        }

        let rgbaA = try rgba(a)
        let rgbaB = try rgba(b)
        var result = Data(count: a.width * a.height * 4)
        CVPixelBufferLockBaseAddress(flow, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(flow, .readOnly) }
        guard let flowBase = CVPixelBufferGetBaseAddress(flow) else {
            throw FrameInterpolationError.motionEstimationFailed
        }
        let flowRowBytes = CVPixelBufferGetBytesPerRow(flow)

        result.withUnsafeMutableBytes { destination in
            rgbaA.withUnsafeBytes { lhs in
                rgbaB.withUnsafeBytes { rhs in
                    let d = destination.bindMemory(to: UInt8.self)
                    let l = lhs.bindMemory(to: UInt8.self)
                    let r = rhs.bindMemory(to: UInt8.self)
                    for y in 0..<a.height {
                        let flowRow = flowBase.advanced(by: y * flowRowBytes).assumingMemoryBound(to: Float.self)
                        for x in 0..<a.width {
                            let dx = Double(flowRow[x * 2])
                            let dy = Double(flowRow[x * 2 + 1])
                            let fromX = Double(x) - dx * progress
                            let fromY = Double(y) - dy * progress
                            let toX = Double(x) + dx * (1 - progress)
                            let toY = Double(y) + dy * (1 - progress)
                            let aPixel = bilinear(l, width: a.width, height: a.height, x: fromX, y: fromY)
                            let bPixel = bilinear(r, width: b.width, height: b.height, x: toX, y: toY)
                            let output = (y * a.width + x) * 4
                            for channel in 0..<4 {
                                d[output + channel] = UInt8(clamping: Int((Double(aPixel[channel]) * (1 - progress) + Double(bPixel[channel]) * progress).rounded()))
                            }
                        }
                    }
                }
            }
        }
        return try encodeRGBA(result, width: a.width, height: a.height)
    }

    private func validatedProgress(_ value: Double) throws -> Double {
        guard value.isFinite, (0...1).contains(value) else { throw FrameInterpolationError.invalidProgress }
        return value
    }

    private func decode(_ image: PortableImage) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(image.data as CFData, nil),
              let result = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw FrameInterpolationError.imageDecodeFailed
        }
        return result
    }

    private func rgba(_ image: CGImage) throws -> Data {
        var data = Data(count: image.width * image.height * 4)
        let success = data.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: image.width,
                    height: image.height,
                    bitsPerComponent: 8,
                    bytesPerRow: image.width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard success else { throw FrameInterpolationError.imageDecodeFailed }
        return data
    }

    private func encodeRGBA(_ rgba: Data, width: Int, height: Int) throws -> PortableImage {
        guard let provider = CGDataProvider(data: rgba as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else { throw FrameInterpolationError.imageEncodeFailed }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw FrameInterpolationError.imageEncodeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw FrameInterpolationError.imageEncodeFailed }
        return try PortableImage(data: data as Data, format: .png, pixelSize: VertexSize(width: Double(width), height: Double(height)))
    }

    private func bilinear(_ bytes: UnsafeBufferPointer<UInt8>, width: Int, height: Int, x: Double, y: Double) -> [UInt8] {
        let clampedX = min(max(x, 0), Double(width - 1))
        let clampedY = min(max(y, 0), Double(height - 1))
        let x0 = Int(floor(clampedX)), y0 = Int(floor(clampedY))
        let x1 = min(width - 1, x0 + 1), y1 = min(height - 1, y0 + 1)
        let fx = clampedX - Double(x0), fy = clampedY - Double(y0)
        var output = [UInt8](repeating: 0, count: 4)
        for channel in 0..<4 {
            let p00 = Double(bytes[(y0 * width + x0) * 4 + channel])
            let p10 = Double(bytes[(y0 * width + x1) * 4 + channel])
            let p01 = Double(bytes[(y1 * width + x0) * 4 + channel])
            let p11 = Double(bytes[(y1 * width + x1) * 4 + channel])
            let top = p00 + (p10 - p00) * fx
            let bottom = p01 + (p11 - p01) * fx
            output[channel] = UInt8(clamping: Int((top + (bottom - top) * fy).rounded()))
        }
        return output
    }
}
#endif
