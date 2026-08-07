import Testing
@testable import VertexAI

@Test("Identical recipes have identical canonical digest")
func identicalRecipeDigest() throws {
    let first = AITaskRecipe.depth(DepthRecipe(smoothing: 0.25, edgeRefinement: 0.4))
    let second = AITaskRecipe.depth(DepthRecipe(smoothing: 0.25, edgeRefinement: 0.4))
    #expect(try AIRecipeCodec.canonicalData(first) == AIRecipeCodec.canonicalData(second))
    #expect(try AIRecipeCodec.digest(first) == AIRecipeCodec.digest(second))
}

@Test("Any user-visible depth setting changes recipe digest")
func recipeSettingInvalidatesDigest() throws {
    let first = AITaskRecipe.depth(DepthRecipe(smoothing: 0.25))
    let second = AITaskRecipe.depth(DepthRecipe(smoothing: 0.26))
    #expect(try AIRecipeCodec.digest(first) != AIRecipeCodec.digest(second))
}

@Test("Cutout prompt coordinates are validated")
func cutoutPromptValidation() {
    #expect(throws: AIError.self) {
        _ = try CutoutRecipe(
            mode: .promptQuality,
            prompts: [.point(x: 1.1, y: 0.5, foreground: true)]
        ).validated()
    }
}

@Test("AI job identity changes with model digest")
func modelChangeInvalidatesIdentity() throws {
    let common = (
        source: "source-fingerprint",
        range: String(repeating: "1", count: 64),
        recipe: String(repeating: "2", count: 64),
        output: String(repeating: "3", count: 64)
    )
    let first = try AIJobIdentity(
        sourceFingerprint: common.source,
        sourceRangeDigest: common.range,
        modelDigest: String(repeating: "a", count: 64),
        recipeDigest: common.recipe,
        outputDigest: common.output
    )
    let second = try AIJobIdentity(
        sourceFingerprint: common.source,
        sourceRangeDigest: common.range,
        modelDigest: String(repeating: "b", count: 64),
        recipeDigest: common.recipe,
        outputDigest: common.output
    )
    #expect(first.digest != second.digest)
}
