import Testing
import VertexComposition

@Test("Effect resolution errors carry layer effect type and exact time")
func effectFailureDescriptionIsContextual() {
    let error = CompositionError.effectResolutionFailed(
        layerID: "layer-1",
        effectID: "effect-1",
        effectType: "depthMap",
        time: "7/30s",
        message: "model unavailable"
    )
    let description = error.errorDescription ?? ""
    #expect(description.contains("layer-1"))
    #expect(description.contains("effect-1"))
    #expect(description.contains("depthMap"))
    #expect(description.contains("7/30s"))
    #expect(description.contains("model unavailable"))
}
