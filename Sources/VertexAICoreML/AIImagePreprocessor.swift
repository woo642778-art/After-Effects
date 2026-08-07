import Foundation
import VertexAI

#if canImport(CoreImage) && canImport(CoreML) && canImport(CoreVideo)
import CoreImage
import CoreML
import CoreVideo

public struct AIImageTransform: Equatable, Sendable {
    public let sourceWidth: Int
    public let sourceHeight: Int
    public let modelWidth: Int
    public let modelHeight: Int
    public let contentX: Double
    public let contentY: Double
    public let contentWidth: Double
    public let contentHeight: Double
}

public enum AIImagePreprocessor {
    public static func aspectFit(
        pixelBuffer: CVPixelBuffer,
        for model: MLModel,
        context: CIContext = CIContext(options: [.cacheIntermediates: false])
    ) throws -> (buffer: CVPixelBuffer, transform: AIImageTransform) {
        let inputName = try AIImageTensorAdapter.imageInputName(for: model)
        guard let description = model.modelDescription.inputDescriptionsByName[inputName],
              let constraint = description.imageConstraint else {
            throw AIError.inferenceFailed("Core ML image input lacks an image constraint.")
        }

        let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
        let modelWidth = constraint.pixelsWide
        let modelHeight = constraint.pixelsHigh
        guard sourceWidth > 0, sourceHeight > 0, modelWidth > 0, modelHeight > 0 else {
            throw AIError.inferenceFailed("Source/model image dimensions are invalid.")
        }

        let scale = min(Double(modelWidth) / Double(sourceWidth), Double(modelHeight) / Double(sourceHeight))
        let contentWidth = Double(sourceWidth) * scale
        let contentHeight = Double(sourceHeight) * scale
        let contentX = (Double(modelWidth) - contentWidth) / 2
        let contentY = (Double(modelHeight) - contentHeight) / 2

        var destination: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            modelWidth,
            modelHeight,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &destination
        )
        guard status == kCVReturnSuccess, let destination else {
            throw AIError.inferenceFailed("Could not allocate Core ML preprocessing pixel buffer (\(status)).")
        }

        let targetRect = CGRect(x: 0, y: 0, width: modelWidth, height: modelHeight)
        context.render(CIImage(color: .black).cropped(to: targetRect), to: destination)

        let source = CIImage(cvPixelBuffer: pixelBuffer)
        let transformed = source
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: contentX, y: contentY))
        context.render(transformed, to: destination, bounds: targetRect, colorSpace: CGColorSpaceCreateDeviceRGB())

        return (
            destination,
            AIImageTransform(
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                modelWidth: modelWidth,
                modelHeight: modelHeight,
                contentX: contentX,
                contentY: contentY,
                contentWidth: contentWidth,
                contentHeight: contentHeight
            )
        )
    }
}

#endif
