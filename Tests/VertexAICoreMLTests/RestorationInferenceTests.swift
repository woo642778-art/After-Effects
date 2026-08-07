import Testing
import VertexAI
@testable import VertexAICoreML

@Test("Balanced denoise uses the dedicated denoise restoration model")
func balancedDenoisePlan() throws {
    let plan = try RestorationModelPlan.resolve(
        recipe: RestorationRecipe(denoise: 0.7),
        qualityTier: .balanced
    )
    #expect(plan.modelIDs == ["realesrgan-x4v3-denoise-f16"])
    #expect(plan.mixStrength == 0.7)
}

@Test("Detail-only restoration uses the general reconstruction model")
func detailOnlyPlan() throws {
    let plan = try RestorationModelPlan.resolve(
        recipe: RestorationRecipe(detailRecovery: 0.65),
        qualityTier: .balanced
    )
    #expect(plan.modelIDs == ["realesrgan-x4v3-f16"])
    #expect(plan.mixStrength == 0.65)
}

@Test("Max Quality can run denoise then detail reconstruction as two verified passes")
func maxQualityMultiPassPlan() throws {
    let plan = try RestorationModelPlan.resolve(
        recipe: RestorationRecipe(denoise: 0.5, artifactRemoval: 0.4, detailRecovery: 0.6),
        qualityTier: .maxQuality
    )
    #expect(plan.modelIDs == ["realesrgan-x4v3-denoise-f16", "realesrgan-x4v3-f16"])
    #expect(plan.mixStrength == 0.6)
}

@Test("Balanced combined restoration avoids an unbounded multi-pass workload")
func balancedCombinedPlan() throws {
    let plan = try RestorationModelPlan.resolve(
        recipe: RestorationRecipe(denoise: 0.5, artifactRemoval: 0.4, detailRecovery: 0.6),
        qualityTier: .balanced
    )
    #expect(plan.modelIDs == ["realesrgan-x4v3-denoise-f16"])
}

@Test("Deblur is not mislabeled until a dedicated deblur model passes native validation")
func deblurFailsClosed() {
    #expect(throws: AIError.self) {
        _ = try RestorationModelPlan.resolve(
            recipe: RestorationRecipe(deblur: 0.5),
            qualityTier: .maxQuality
        )
    }
}

@Test("Face restore is not mislabeled until a dedicated face model passes native validation")
func faceRestoreFailsClosed() {
    #expect(throws: AIError.self) {
        _ = try RestorationModelPlan.resolve(
            recipe: RestorationRecipe(faceRestoration: true),
            qualityTier: .maxQuality
        )
    }
}

@Test("Empty restoration is rejected as a no-op")
func emptyRestorationRejected() {
    #expect(throws: AIError.self) {
        _ = try RestorationModelPlan.resolve(recipe: RestorationRecipe(), qualityTier: .balanced)
    }
}

#if canImport(CoreImage) && canImport(CoreML) && canImport(CoreVideo)
import CoreImage
import CoreML
import CoreVideo

@Test("Bundled Real-ESRGAN denoise model performs real local restoration inference when CI provides the model root")
func bundledRealESRGANDenoiseInference() throws {
    guard let root = preparedAIModelRoot() else { return }
    let manifest = try preparedAIManifest(root: root)
    guard manifest.models.contains(where: { $0.modelID == "realesrgan-x4v3-denoise-f16" }) else {
        Issue.record("VERTEX_AI_MODEL_ROOT was supplied but the Real-ESRGAN denoise model is missing")
        return
    }

    let registry = try AIModelRegistry(resourceRoot: root, manifest: manifest)
    let engine = RestorationInferenceEngine(registry: registry)
    let input = try syntheticBGRA(width: 12, height: 8)
    let output = try engine.infer(
        pixelBuffer: input,
        recipe: RestorationRecipe(denoise: 1),
        qualityTier: .balanced,
        tileOverlap: 8
    )

    #expect(CVPixelBufferGetWidth(output) == 12)
    #expect(CVPixelBufferGetHeight(output) == 8)
    #expect(try pixelVariance(output) > 0)
}
#endif
