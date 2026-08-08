import Testing
@testable import Vertex

@Test("Pending AI preview explicitly reports source-pixel fallback")
func pendingAIStateUsesSourcePixels() {
    #expect(AIEffectPresentationState.computing.usesSourcePixels)
    #expect(AIEffectPresentationState.failed("inference").usesSourcePixels)
}

@Test("Ready and cached AI states never claim source fallback")
func successfulAIStateUsesEffectPixels() {
    #expect(!AIEffectPresentationState.ready.usesSourcePixels)
    #expect(!AIEffectPresentationState.cached.usesSourcePixels)
}
