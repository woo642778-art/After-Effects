import Foundation
import VertexAI

#if canImport(CoreImage) && canImport(CoreML) && canImport(CoreVideo)
import CoreImage
import CoreML
import CoreVideo

public enum AIImageTensorAdapter {
    public struct InputShape: Equatable, Sendable {
        public let width: Int
        public let height: Int
        public let kind: Kind

        public enum Kind: Equatable, Sendable {
            case image
            case nchwMultiArray
        }
    }

    public static func singleInputDescription(for model: MLModel) throws -> (String, MLFeatureDescription) {
        let descriptions = model.modelDescription.inputDescriptionsByName
        guard descriptions.count == 1, let pair = descriptions.first else {
            throw AIError.inferenceFailed("Expected exactly one Core ML input; found \(descriptions.count).")
        }
        return pair
    }

    public static func inputShape(for model: MLModel) throws -> InputShape {
        let (_, description) = try singleInputDescription(for: model)
        switch description.type {
        case .image:
            guard let constraint = description.imageConstraint,
                  constraint.pixelsWide > 0, constraint.pixelsHigh > 0 else {
                throw AIError.inferenceFailed("Core ML image input lacks fixed positive dimensions.")
            }
            return InputShape(width: constraint.pixelsWide, height: constraint.pixelsHigh, kind: .image)
        case .multiArray:
            guard let constraint = description.multiArrayConstraint else {
                throw AIError.inferenceFailed("Core ML multi-array input lacks a shape constraint.")
            }
            let shape = constraint.shape.map(\.intValue)
            guard shape.count == 4, shape[0] == 1, shape[1] == 3,
                  shape[2] > 0, shape[3] > 0 else {
                throw AIError.inferenceFailed("Only fixed NCHW RGB model input is supported; got \(shape).")
            }
            return InputShape(width: shape[3], height: shape[2], kind: .nchwMultiArray)
        default:
            throw AIError.inferenceFailed("Core ML input must be an image or NCHW multi-array.")
        }
    }

    public static func imageInputName(for model: MLModel) throws -> String {
        let (name, description) = try singleInputDescription(for: model)
        guard description.type == .image else {
            throw AIError.inferenceFailed("Core ML model input is not an image.")
        }
        return name
    }

    public static func prediction(model: MLModel, pixelBuffer: CVPixelBuffer) throws -> MLFeatureProvider {
        let (inputName, description) = try singleInputDescription(for: model)
        let value: MLFeatureValue
        switch description.type {
        case .image:
            value = MLFeatureValue(pixelBuffer: pixelBuffer)
        case .multiArray:
            value = MLFeatureValue(multiArray: try rgbMultiArray(pixelBuffer: pixelBuffer, for: model))
        default:
            throw AIError.inferenceFailed("Unsupported Core ML input feature type: \(description.type.rawValue)")
        }
        let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: value])
        do {
            return try model.prediction(from: provider)
        } catch {
            throw AIError.inferenceFailed("Core ML prediction failed: \(error.localizedDescription)")
        }
    }

    public static func rgbMultiArray(pixelBuffer: CVPixelBuffer, for model: MLModel) throws -> MLMultiArray {
        let shape = try inputShape(for: model)
        guard shape.kind == .nchwMultiArray else {
            throw AIError.inferenceFailed("Requested NCHW conversion for a non-multi-array model.")
        }
        let resized = try resizedBGRA(pixelBuffer: pixelBuffer, width: shape.width, height: shape.height)
        let array = try MLMultiArray(
            shape: [1, 3, NSNumber(value: shape.height), NSNumber(value: shape.width)],
            dataType: .float32
        )
        CVPixelBufferLockBaseAddress(resized, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(resized, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(resized) else {
            throw AIError.inferenceFailed("Could not access resized AI input pixels.")
        }
        let rowBytes = CVPixelBufferGetBytesPerRow(resized)
        let plane = shape.width * shape.height
        let pointer = array.dataPointer.bindMemory(to: Float32.self, capacity: plane * 3)
        for y in 0..<shape.height {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
            for x in 0..<shape.width {
                let pixel = x * 4
                let index = y * shape.width + x
                pointer[index] = Float32(row[pixel + 2]) / 255
                pointer[plane + index] = Float32(row[pixel + 1]) / 255
                pointer[plane * 2 + index] = Float32(row[pixel]) / 255
            }
        }
        return array
    }

    public static func firstMultiArrayOutput(from provider: MLFeatureProvider) throws -> MLMultiArray {
        for name in provider.featureNames.sorted() {
            if let value = provider.featureValue(for: name), value.type == .multiArray,
               let array = value.multiArrayValue {
                return array
            }
        }
        throw AIError.inferenceFailed("Core ML prediction did not contain a multi-array output.")
    }

    public static func firstImageOutput(from provider: MLFeatureProvider) throws -> CVPixelBuffer {
        for name in provider.featureNames.sorted() {
            if let value = provider.featureValue(for: name), value.type == .image,
               let buffer = value.imageBufferValue {
                return buffer
            }
        }
        throw AIError.inferenceFailed("Core ML prediction did not contain an image output.")
    }

    public static func rgbPixelBuffer(from array: MLMultiArray) throws -> CVPixelBuffer {
        let shape = array.shape.map(\.intValue)
        guard shape.count == 4, shape[0] == 1, shape[1] == 3,
              shape[2] > 0, shape[3] > 0 else {
            throw AIError.inferenceFailed("Only NCHW RGB output is supported; got \(shape).")
        }
        let height = shape[2], width = shape[3]
        var buffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else {
            throw AIError.inferenceFailed("Could not allocate AI output pixel buffer (\(status)).")
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw AIError.inferenceFailed("Could not access AI output pixels.")
        }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        let strides = array.strides.map(\.intValue)
        guard strides.count == 4 else { throw AIError.inferenceFailed("Unexpected output strides.") }
        func value(channel: Int, y: Int, x: Int) -> Float {
            let linear = channel * strides[1] + y * strides[2] + x * strides[3]
            return array[linear].floatValue
        }
        for y in 0..<height {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let offset = x * 4
                let r = min(max(value(channel: 0, y: y, x: x), 0), 1)
                let g = min(max(value(channel: 1, y: y, x: x), 0), 1)
                let b = min(max(value(channel: 2, y: y, x: x), 0), 1)
                row[offset] = UInt8((b * 255).rounded())
                row[offset + 1] = UInt8((g * 255).rounded())
                row[offset + 2] = UInt8((r * 255).rounded())
                row[offset + 3] = 255
            }
        }
        return buffer
    }

    private static func resizedBGRA(pixelBuffer: CVPixelBuffer, width: Int, height: Int) throws -> CVPixelBuffer {
        var destination: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &destination
        )
        guard status == kCVReturnSuccess, let destination else {
            throw AIError.inferenceFailed("Could not allocate resized AI input (\(status)).")
        }
        let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
        let image = CIImage(cvPixelBuffer: pixelBuffer)
            .transformed(by: CGAffineTransform(
                scaleX: Double(width) / Double(sourceWidth),
                y: Double(height) / Double(sourceHeight)
            ))
        CIContext(options: [.cacheIntermediates: false]).render(
            image,
            to: destination,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return destination
    }
}

#else

public enum AIImageTensorAdapter {}

#endif
