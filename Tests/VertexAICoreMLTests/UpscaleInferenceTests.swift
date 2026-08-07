import Testing
import VertexAI
@testable import VertexAICoreML

@Test("2x upscale plan uses native 4x inference then resolves exact requested output")
func twoXOutputPlan() throws {
    let plan = try UpscaleOutputPlan.resolve(
        sourceWidth: 640,
        sourceHeight: 360,
        recipe: UpscaleRecipe(scale: 2),
        nativeScale: 4
    )
    #expect(plan.nativeWidth == 2560)
    #expect(plan.nativeHeight == 1440)
    #expect(plan.finalWidth == 1280)
    #expect(plan.finalHeight == 720)
    #expect(plan.requiresFinalResample)
}

@Test("4x upscale plan avoids an unnecessary final resample")
func fourXOutputPlan() throws {
    let plan = try UpscaleOutputPlan.resolve(
        sourceWidth: 1920,
        sourceHeight: 1080,
        recipe: UpscaleRecipe(scale: 4),
        nativeScale: 4
    )
    #expect(plan.nativeWidth == 7680)
    #expect(plan.nativeHeight == 4320)
    #expect(plan.finalWidth == 7680)
    #expect(plan.finalHeight == 4320)
    #expect(!plan.requiresFinalResample)
}

@Test("Custom target dimensions override scale while preserving validated bounds")
func customOutputPlan() throws {
    let plan = try UpscaleOutputPlan.resolve(
        sourceWidth: 1280,
        sourceHeight: 720,
        recipe: UpscaleRecipe(scale: 4, targetWidth: 3840, targetHeight: 2160),
        nativeScale: 4
    )
    #expect(plan.finalWidth == 3840)
    #expect(plan.finalHeight == 2160)
    #expect(plan.requiresFinalResample)
}

@Test("Output beyond Phase 7 maximum dimensions is rejected")
func outputTooLargeRejected() {
    #expect(throws: AIError.self) {
        _ = try UpscaleOutputPlan.resolve(
            sourceWidth: 5000,
            sourceHeight: 5000,
            recipe: UpscaleRecipe(scale: 4),
            nativeScale: 4
        )
    }
}

@Test("Dedicated anime/game profile is not silently substituted when unvalidated")
func animeProfileRequiresValidatedModel() {
    #expect(UpscaleModelSelection.modelID(for: .general) == "realesrgan-x4v3-f16")
    #expect(UpscaleModelSelection.modelID(for: .animeGame) == nil)
}
