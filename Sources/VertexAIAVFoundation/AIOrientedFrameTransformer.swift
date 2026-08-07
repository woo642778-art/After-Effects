import Foundation
@preconcurrency import AVFoundation
import VertexAI

#if canImport(CoreImage) && canImport(CoreVideo)
import CoreImage
import CoreVideo

final class AIOrientedFrameTransformer: @unchecked Sendable {
    let outputWidth: Int
    let outputHeight: Int
    private let preferredTransform: CGAffineTransform
    private let transformedOrigin: CGPoint
    private let context = CIContext(options: [.cacheIntermediates: false])

    init(naturalSize: CGSize, preferredTransform: CGAffineTransform) throws {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let width = Int(abs(rect.width).rounded())
        let height = Int(abs(rect.height).rounded())
        guard width > 0, height > 0 else {
            throw AIError.invalidJobState("Video preferred transform produced invalid oriented dimensions.")
        }
        self.outputWidth = width
        self.outputHeight = height
        self.preferredTransform = preferredTransform
        self.transformedOrigin = rect.origin
    }

    func transform(_ source: CVPixelBuffer) throws -> CVPixelBuffer {
        var destination: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            outputWidth,
            outputHeight,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                kCVPixelBufferMetalCompatibilityKey: true,
                kCVPixelBufferIOSurfacePropertiesKey: [:]
            ] as CFDictionary,
            &destination
        )
        guard status == kCVReturnSuccess, let destination else {
            throw AIError.inferenceFailed("Could not allocate oriented AI frame buffer (\(status)).")
        }
        let image = CIImage(cvPixelBuffer: source)
            .transformed(by: preferredTransform)
            .transformed(by: CGAffineTransform(
                translationX: -transformedOrigin.x,
                y: -transformedOrigin.y
            ))
        let bounds = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
        context.render(image, to: destination, bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
        return destination
    }
}

#endif
