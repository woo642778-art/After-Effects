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
