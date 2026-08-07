import Testing
import VertexAI
@testable import VertexAICoreML

@Test("Cutout cleanup keeps alpha finite and normalized")
func cutoutCleanupNormalizesAlpha() throws {
    let recipe = CutoutRecipe(mode: .foregroundFast, feather: 0.25, edgeCleanup: 0.4, temporalSmoothing: 0)
    let frame = try CutoutMaskProcessing.process(
        alpha: [-0.5, 0.2, 0.8, 1.5],
        width: 2,
        height: 2,
        recipe: recipe
    )
    #expect(frame.alpha.allSatisfy { $0.isFinite && (0...1).contains($0) })
    #expect(frame.previewBytes().count == 4)
}

@Test("Cutout temporal smoothing blends previous mask")
func cutoutTemporalSmoothing() throws {
    let previous = try CutoutMaskFrame(width: 2, height: 1, alpha: [0, 0])
    let recipe = CutoutRecipe(mode: .foregroundFast, temporalSmoothing: 0.5)
    let frame = try CutoutMaskProcessing.process(
        alpha: [1, 0.5],
        width: 2,
        height: 1,
        recipe: recipe,
        previous: previous
    )
    #expect(frame.alpha[0] == 0.5)
    #expect(frame.alpha[1] == 0.25)
}

@Test("Prompt quality requires a selection prompt")
func promptQualityRequiresPrompt() {
    #expect(throws: AIError.self) {
        _ = try CutoutRecipe(mode: .promptQuality, prompts: []).validated()
    }
}
