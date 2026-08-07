import Foundation
import VertexAI

#if canImport(CoreImage) && canImport(CoreVideo)
import CoreImage
import CoreVideo

public final class AISceneBoundaryDetector: @unchecked Sendable {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var previousSignature: [UInt8]?
    public let threshold: Double

    public init(threshold: Double = 0.24) {
        self.threshold = min(max(threshold, 0.01), 1)
    }

    public func reset() {
        previousSignature = nil
    }

    public func isSceneBoundary(pixelBuffer: CVPixelBuffer) throws -> Bool {
        let signature = try makeSignature(pixelBuffer)
        defer { previousSignature = signature }
        guard let previousSignature else { return true }
        var sum = 0.0
        for index in signature.indices {
            sum += abs(Double(signature[index]) - Double(previousSignature[index])) / 255.0
        }
        return sum / Double(signature.count) >= threshold
    }

    private func makeSignature(_ pixelBuffer: CVPixelBuffer) throws -> [UInt8] {
        var tiny: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            16,
            16,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true
            ] as CFDictionary,
            &tiny
        )
        guard status == kCVReturnSuccess, let tiny else {
            throw AIError.inferenceFailed("Could not allocate scene-boundary signature buffer.")
        }
        let source = CIImage(cvPixelBuffer: pixelBuffer)
        let scale = CGAffineTransform(
            scaleX: 16 / source.extent.width,
            y: 16 / source.extent.height
        )
        context.render(
            source.transformed(by: scale),
            to: tiny,
            bounds: CGRect(x: 0, y: 0, width: 16, height: 16),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        CVPixelBufferLockBaseAddress(tiny, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(tiny, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(tiny) else {
            throw AIError.inferenceFailed("Scene-boundary signature buffer is unreadable.")
        }
        let rowBytes = CVPixelBufferGetBytesPerRow(tiny)
        var result = Array(repeating: UInt8.zero, count: 16 * 16)
        for y in 0..<16 {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
            for x in 0..<16 {
                let offset = x * 4
                let b = Double(row[offset])
                let g = Double(row[offset + 1])
                let r = Double(row[offset + 2])
                result[y * 16 + x] = UInt8(min(max((0.2126 * r + 0.7152 * g + 0.0722 * b).rounded(), 0), 255))
            }
        }
        return result
    }
}

#endif
