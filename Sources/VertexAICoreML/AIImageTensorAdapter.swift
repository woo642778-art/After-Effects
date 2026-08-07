import Foundation
import VertexAI

#if canImport(CoreML) && canImport(CoreVideo)
import CoreML
import CoreVideo

public enum AIImageTensorAdapter {
    public static func imageInputName(for model: MLModel) throws -> String {
        let candidates = model.modelDescription.inputDescriptionsByName.compactMap { key, description in
            description.type == .image ? key : nil
        }
        guard candidates.count == 1, let input = candidates.first else {
            throw AIError.inferenceFailed("Expected exactly one Core ML image input; found \(candidates.count).")
        }
        return input
    }

    public static func prediction(model: MLModel, pixelBuffer: CVPixelBuffer) throws -> MLFeatureProvider {
        let inputName = try imageInputName(for: model)
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            inputName: MLFeatureValue(pixelBuffer: pixelBuffer)
        ])
        do {
            return try model.prediction(from: provider)
        } catch {
            throw AIError.inferenceFailed("Core ML image prediction failed: \(error.localizedDescription)")
        }
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
}

#else

public enum AIImageTensorAdapter {}

#endif
