import Foundation
import VertexAI

public struct RestorationModelPlan: Equatable, Sendable {
    public let modelIDs: [String]
    public let mixStrength: Float

    public static func resolve(
        recipe: RestorationRecipe,
        qualityTier: AIQualityTier
    ) throws -> RestorationModelPlan {
        _ = try recipe.validated()
        if recipe.deblur > 0 {
            throw AIError.unsupportedCapability(
                "AI Deblur is disabled until a dedicated deblur checkpoint passes the Phase 7 Core ML and quality gates."
            )
        }
        if recipe.faceRestoration {
            throw AIError.unsupportedCapability(
                "Face Restore is disabled until a dedicated face-restoration checkpoint passes the Phase 7 Core ML and quality gates."
            )
        }

        let denoiseStrength = max(recipe.denoise, recipe.artifactRemoval)
        let detailStrength = recipe.detailRecovery
        guard denoiseStrength > 0 || detailStrength > 0 else {
            throw AIError.invalidRecipe("Restoration requires at least one validated non-zero operation.")
        }

        var models: [String] = []
        if denoiseStrength > 0 {
            models.append("realesrgan-x4v3-denoise-f16")
        }
        if detailStrength > 0, denoiseStrength == 0 || qualityTier == .maxQuality {
            models.append("realesrgan-x4v3-f16")
        }
        let strength = max(denoiseStrength, detailStrength)
        return RestorationModelPlan(modelIDs: models, mixStrength: strength)
    }
}

#if canImport(CoreImage) && canImport(CoreML) && canImport(CoreVideo)
import CoreImage
@preconcurrency import CoreML
import CoreVideo

public final class RestorationInferenceEngine: @unchecked Sendable {
    private let registry: AIModelRegistry
    private let context: CIContext

    public init(
        registry: AIModelRegistry,
        context: CIContext = CIContext(options: [.cacheIntermediates: false])
    ) {
        self.registry = registry
        self.context = context
    }

    public func infer(
        pixelBuffer: CVPixelBuffer,
        recipe: RestorationRecipe,
        qualityTier: AIQualityTier,
        tileOverlap: Int = 32
    ) throws -> CVPixelBuffer {
        let restorationPlan = try RestorationModelPlan.resolve(recipe: recipe, qualityTier: qualityTier)
        let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
        var current = pixelBuffer

        for modelID in restorationPlan.modelIDs {
            current = try registry.withModel(for: modelID) { model in
                let geometry = try TiledSuperResolutionRunner.geometry(for: model)
                let oneXRecipe = UpscaleRecipe(
                    profile: .general,
                    scale: 1,
                    targetWidth: sourceWidth,
                    targetHeight: sourceHeight,
                    tileOverlap: tileOverlap
                )
                let plan = try UpscaleOutputPlan.resolve(
                    sourceWidth: CVPixelBufferGetWidth(current),
                    sourceHeight: CVPixelBufferGetHeight(current),
                    recipe: oneXRecipe,
                    nativeScale: geometry.nativeScale
                )
                return try TiledSuperResolutionRunner.run(
                    source: current,
                    model: model,
                    plan: plan,
                    overlap: tileOverlap,
                    context: context
                )
            }
        }

        guard restorationPlan.mixStrength < 0.999 else { return current }
        return try blend(
            original: pixelBuffer,
            restored: current,
            amount: restorationPlan.mixStrength
        )
    }

    private func blend(
        original: CVPixelBuffer,
        restored: CVPixelBuffer,
        amount: Float
    ) throws -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(original)
        let height = CVPixelBufferGetHeight(original)
        guard width == CVPixelBufferGetWidth(restored), height == CVPixelBufferGetHeight(restored) else {
            throw AIError.inferenceFailed("Restoration blend inputs must have matching dimensions.")
        }
        var output: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &output
        )
        guard status == kCVReturnSuccess, let output else {
            throw AIError.inferenceFailed("Could not allocate restoration blend buffer (\(status)).")
        }

        let originalImage = CIImage(cvPixelBuffer: original)
        let restoredImage = CIImage(cvPixelBuffer: restored)
        guard let filter = CIFilter(name: "CIDissolveTransition") else {
            throw AIError.inferenceFailed("Core Image dissolve filter is unavailable.")
        }
        filter.setValue(originalImage, forKey: kCIInputImageKey)
        filter.setValue(restoredImage, forKey: kCIInputTargetImageKey)
        filter.setValue(amount, forKey: kCIInputTimeKey)
        guard let image = filter.outputImage else {
            throw AIError.inferenceFailed("Restoration blend did not produce an output image.")
        }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.render(image, to: output, bounds: rect, colorSpace: CGColorSpaceCreateDeviceRGB())
        return output
    }
}

#endif
