import Testing
@testable import VertexAI

private let maxProfile = AICapabilityProfile(
    supportsMaxQualityByHardwareClass: true,
    memoryBudgetBytes: 4_000_000_000,
    thermalRestricted: false,
    neuralEngineAvailable: true
)

@Test("Max Quality remains enabled only on an eligible profile")
func maxQualityEligible() {
    let decision = AIQualityPolicy.decide(requested: .maxQuality, profile: maxProfile)
    #expect(decision.effective == .maxQuality)
    #expect(decision.fallbackReason == nil)
}

@Test("Max Quality falls back when hardware class is unsupported")
func maxQualityHardwareFallback() {
    var profile = maxProfile
    profile.supportsMaxQualityByHardwareClass = false
    let decision = AIQualityPolicy.decide(requested: .maxQuality, profile: profile)
    #expect(decision.effective == .balanced)
    #expect(decision.fallbackReason != nil)
}

@Test("Max Quality falls back when memory budget is insufficient")
func maxQualityMemoryFallback() {
    var profile = maxProfile
    profile.memoryBudgetBytes = 2_000_000_000
    let decision = AIQualityPolicy.decide(requested: .maxQuality, profile: profile)
    #expect(decision.effective == .balanced)
}

@Test("Thermal pressure forces Preview")
func thermalFallback() {
    var profile = maxProfile
    profile.thermalRestricted = true
    let maxDecision = AIQualityPolicy.decide(requested: .maxQuality, profile: profile)
    let balancedDecision = AIQualityPolicy.decide(requested: .balanced, profile: profile)
    #expect(maxDecision.effective == .preview)
    #expect(balancedDecision.effective == .preview)
}

@Test("Preview is always available")
func previewAlwaysAvailable() {
    let decision = AIQualityPolicy.decide(requested: .preview, profile: .conservative)
    #expect(decision.effective == .preview)
}
