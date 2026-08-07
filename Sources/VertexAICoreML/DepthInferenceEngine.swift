import Foundation
import VertexAI

public struct DepthFrame: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let values: [Float]

    public init(width: Int, height: Int, values: [Float]) throws {
        guard width > 0, height > 0, values.count == width * height,
              values.allSatisfy(\.isFinite) else {
            throw AIError.inferenceFailed("Depth frame dimensions or values are invalid.")
        }
        self.width = width
        self.height = height
        self.values = values
    }

    public var minimum: Float { values.min() ?? 0 }
    public var maximum: Float { values.max() ?? 0 }

    public func previewBytes() -> [UInt8] {
        values.map { UInt8((min(max($0, 0), 1) * 255).rounded()) }
    }
}

public enum DepthProcessing {
    public static func process(
        values: [Float],
        width: Int,
        height: Int,
        recipe: DepthRecipe,
        previous: DepthFrame? = nil
    ) throws -> DepthFrame {
        _ = try recipe.validated()
        guard values.count == width * height, width > 0, height > 0 else {
            throw AIError.inferenceFailed("Depth processing dimensions do not match the value buffer.")
        }
        let finite = values.filter(\.isFinite)
        guard let minimum = finite.min(), let maximum = finite.max(), maximum > minimum else {
            throw AIError.inferenceFailed("Depth prediction is constant or non-finite.")
        }
        let denominator = maximum - minimum
        var normalized = values.map { value -> Float in
            guard value.isFinite else { return 0 }
            return min(max((value - minimum) / denominator, 0), 1)
        }

        let range = recipe.farValue - recipe.nearValue
        normalized = normalized.map { value in
            var mapped = min(max((value - recipe.nearValue) / range, 0), 1)
            if recipe.invert { mapped = 1 - mapped }
            return mapped
        }

        if recipe.smoothing > 0 {
            let radius = max(1, Int((recipe.smoothing * 4).rounded()))
            normalized = boxBlur(normalized, width: width, height: height, radius: radius)
        }

        if recipe.edgeRefinement > 0 {
            let blurred = boxBlur(normalized, width: width, height: height, radius: 1)
            for index in normalized.indices {
                let sharpened = normalized[index] + recipe.edgeRefinement * (normalized[index] - blurred[index])
                normalized[index] = min(max(sharpened, 0), 1)
            }
        }

        if recipe.temporalSmoothing > 0, let previous,
           previous.width == width, previous.height == height {
            let keepPrevious = recipe.temporalSmoothing
            let keepCurrent = 1 - keepPrevious
            for index in normalized.indices {
                normalized[index] = previous.values[index] * keepPrevious + normalized[index] * keepCurrent
            }
        }
        return try DepthFrame(width: width, height: height, values: normalized)
    }

    public static func bilinearResize(
        _ input: [Float],
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int
    ) -> [Float] {
        guard sourceWidth != targetWidth || sourceHeight != targetHeight else { return input }
        var output = Array(repeating: Float.zero, count: targetWidth * targetHeight)
        let xScale = targetWidth > 1 ? Double(sourceWidth - 1) / Double(targetWidth - 1) : 0
        let yScale = targetHeight > 1 ? Double(sourceHeight - 1) / Double(targetHeight - 1) : 0
        for y in 0..<targetHeight {
            let sourceY = Double(y) * yScale
            let y0 = Int(sourceY.rounded(.down))
            let y1 = min(sourceHeight - 1, y0 + 1)
            let fy = Float(sourceY - Double(y0))
            for x in 0..<targetWidth {
                let sourceX = Double(x) * xScale
                let x0 = Int(sourceX.rounded(.down))
                let x1 = min(sourceWidth - 1, x0 + 1)
                let fx = Float(sourceX - Double(x0))
                let top = input[y0 * sourceWidth + x0] * (1 - fx) + input[y0 * sourceWidth + x1] * fx
                let bottom = input[y1 * sourceWidth + x0] * (1 - fx) + input[y1 * sourceWidth + x1] * fx
                output[y * targetWidth + x] = top * (1 - fy) + bottom * fy
            }
        }
        return output
    }

    private static func boxBlur(_ input: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        guard radius > 0 else { return input }
        var horizontal = Array(repeating: Float.zero, count: input.count)
        var output = Array(repeating: Float.zero, count: input.count)
        for y in 0..<height {
            for x in 0..<width {
                let lower = max(0, x - radius)
                let upper = min(width - 1, x + radius)
                var sum: Float = 0
                for sampleX in lower...upper { sum += input[y * width + sampleX] }
                horizontal[y * width + x] = sum / Float(upper - lower + 1)
            }
        }
        for y in 0..<height {
            let lower = max(0, y - radius)
            let upper = min(height - 1, y + radius)
            for x in 0..<width {
                var sum: Float = 0
                for sampleY in lower...upper { sum += horizontal[sampleY * width + x] }
                output[y * width + x] = sum / Float(upper - lower + 1)
            }
        }
        return output
    }
}

#if canImport(CoreML) && canImport(CoreVideo)
@preconcurrency import CoreML
import CoreVideo

public final class DepthInferenceEngine: @unchecked Sendable {
    public static let defaultModelID = "depth-anything-v2-small-f16"

    private let registry: AIModelRegistry
    private let modelID: String

    public init(registry: AIModelRegistry, modelID: String = defaultModelID) {
        self.registry = registry
        self.modelID = modelID
    }

    public func infer(
        pixelBuffer: CVPixelBuffer,
        recipe: DepthRecipe,
        previousFrame: DepthFrame? = nil
    ) throws -> DepthFrame {
        _ = try recipe.validated()
        return try registry.withModel(for: modelID) { model in
            let preprocessed = try AIImagePreprocessor.aspectFit(pixelBuffer: pixelBuffer, for: model)
            let prediction = try AIImageTensorAdapter.prediction(model: model, pixelBuffer: preprocessed.buffer)
            let raw = try Self.extractDepth(provider: prediction)
            let aligned = try Self.align(
                values: raw.values,
                width: raw.width,
                height: raw.height,
                transform: preprocessed.transform
            )
            return try DepthProcessing.process(
                values: aligned,
                width: preprocessed.transform.sourceWidth,
                height: preprocessed.transform.sourceHeight,
                recipe: recipe,
                previous: previousFrame
            )
        }
    }

    static func extractDepth(provider: MLFeatureProvider) throws -> (width: Int, height: Int, values: [Float]) {
        if let namedDepth = provider.featureValue(for: "depth"),
           namedDepth.type == .image,
           let buffer = namedDepth.imageBufferValue {
            return try depthValues(from: buffer)
        }

        for name in provider.featureNames.sorted() {
            if let value = provider.featureValue(for: name),
               value.type == .image,
               let buffer = value.imageBufferValue {
                return try depthValues(from: buffer)
            }
        }

        for name in provider.featureNames.sorted() {
            if let value = provider.featureValue(for: name),
               value.type == .multiArray,
               let array = value.multiArrayValue {
                return try depthValues(from: array)
            }
        }

        let outputs = provider.featureNames.sorted().map { name -> String in
            guard let value = provider.featureValue(for: name) else { return "\(name):missing" }
            return "\(name):\(value.type.rawValue)"
        }.joined(separator: ", ")
        throw AIError.inferenceFailed("Core ML depth prediction contained no supported image or multi-array output. Features: [\(outputs)]")
    }

    static func depthValues(from array: MLMultiArray) throws -> (width: Int, height: Int, values: [Float]) {
        let shape = array.shape.map(\.intValue)
        guard shape.count >= 2, let width = shape.last, let height = shape.dropLast().last,
              width > 0, height > 0 else {
            throw AIError.inferenceFailed("Depth output shape is unsupported: \(shape)")
        }
        let prefixCount = shape.count - 2
        var result = Array(repeating: Float.zero, count: width * height)
        var indices = Array(repeating: NSNumber(value: 0), count: shape.count)
        for y in 0..<height {
            indices[prefixCount] = NSNumber(value: y)
            for x in 0..<width {
                indices[prefixCount + 1] = NSNumber(value: x)
                result[y * width + x] = array[indices].floatValue
            }
        }
        guard result.contains(where: \.isFinite) else {
            throw AIError.inferenceFailed("Depth model returned no finite values.")
        }
        return (width, height, result)
    }

    static func depthValues(from pixelBuffer: CVPixelBuffer) throws -> (width: Int, height: Int, values: [Float]) {
        let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
        let width = planeCount > 0 ? CVPixelBufferGetWidthOfPlane(pixelBuffer, 0) : CVPixelBufferGetWidth(pixelBuffer)
        let height = planeCount > 0 ? CVPixelBufferGetHeightOfPlane(pixelBuffer, 0) : CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0 else {
            throw AIError.inferenceFailed("Depth image output has invalid dimensions \(width)x\(height).")
        }

        let status = CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        guard status == kCVReturnSuccess else {
            throw AIError.inferenceFailed("Could not lock depth image output (\(status)).")
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let baseAddress = planeCount > 0
            ? CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
            : CVPixelBufferGetBaseAddress(pixelBuffer)
        let rowBytes = planeCount > 0
            ? CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            : CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let baseAddress, rowBytes > 0 else {
            throw AIError.inferenceFailed("Could not access depth image output bytes.")
        }

        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        var values = Array(repeating: Float.zero, count: width * height)

        let isFloat32 = pixelFormat == kCVPixelFormatType_OneComponent32Float
            || pixelFormat == kCVPixelFormatType_DepthFloat32
            || pixelFormat == kCVPixelFormatType_DisparityFloat32
        let isFloat16 = pixelFormat == kCVPixelFormatType_OneComponent16Half
            || pixelFormat == kCVPixelFormatType_DepthFloat16
            || pixelFormat == kCVPixelFormatType_DisparityFloat16

        if isFloat32 {
            guard rowBytes >= width * MemoryLayout<Float32>.stride else {
                throw AIError.inferenceFailed("Depth Float32 row stride is smaller than the image width.")
            }
            for y in 0..<height {
                let row = baseAddress.advanced(by: y * rowBytes).assumingMemoryBound(to: Float32.self)
                for x in 0..<width {
                    values[y * width + x] = Float(row[x])
                }
            }
        } else if isFloat16 {
            guard rowBytes >= width * MemoryLayout<Float16>.stride else {
                throw AIError.inferenceFailed("Depth Float16 row stride is smaller than the image width.")
            }
            for y in 0..<height {
                let row = baseAddress.advanced(by: y * rowBytes).assumingMemoryBound(to: Float16.self)
                for x in 0..<width {
                    values[y * width + x] = Float(row[x])
                }
            }
        } else {
            let fourCC = String(bytes: [
                UInt8((pixelFormat >> 24) & 0xff),
                UInt8((pixelFormat >> 16) & 0xff),
                UInt8((pixelFormat >> 8) & 0xff),
                UInt8(pixelFormat & 0xff)
            ].map { (32...126).contains($0) ? $0 : 46 }, encoding: .ascii) ?? "????"
            throw AIError.inferenceFailed(
                "Depth image output pixel format \(pixelFormat) ('\(fourCC)') is not a high-precision Float16/Float32 single-channel format."
            )
        }

        guard values.allSatisfy(\.isFinite) else {
            throw AIError.inferenceFailed("Depth image output contained non-finite values.")
        }
        guard let minimum = values.min(), let maximum = values.max(), maximum > minimum else {
            throw AIError.inferenceFailed("Depth image output is constant.")
        }
        return (width, height, values)
    }

    private static func align(
        values: [Float],
        width: Int,
        height: Int,
        transform: AIImageTransform
    ) throws -> [Float] {
        guard values.count == width * height else {
            throw AIError.inferenceFailed("Depth alignment received an invalid buffer.")
        }
        let scaleX = Double(width) / Double(transform.modelWidth)
        let scaleY = Double(height) / Double(transform.modelHeight)
        let cropX = max(0, min(width - 1, Int((transform.contentX * scaleX).rounded(.down))))
        let cropY = max(0, min(height - 1, Int((transform.contentY * scaleY).rounded(.down))))
        let cropMaxX = max(cropX + 1, min(width, Int(((transform.contentX + transform.contentWidth) * scaleX).rounded(.up))))
        let cropMaxY = max(cropY + 1, min(height, Int(((transform.contentY + transform.contentHeight) * scaleY).rounded(.up))))
        let cropWidth = cropMaxX - cropX
        let cropHeight = cropMaxY - cropY
        var cropped = Array(repeating: Float.zero, count: cropWidth * cropHeight)
        for y in 0..<cropHeight {
            let sourceStart = (cropY + y) * width + cropX
            let destinationStart = y * cropWidth
            cropped.replaceSubrange(destinationStart..<(destinationStart + cropWidth), with: values[sourceStart..<(sourceStart + cropWidth)])
        }
        return DepthProcessing.bilinearResize(
            cropped,
            sourceWidth: cropWidth,
            sourceHeight: cropHeight,
            targetWidth: transform.sourceWidth,
            targetHeight: transform.sourceHeight
        )
    }
}

#endif
