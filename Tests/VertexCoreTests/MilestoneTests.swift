import Testing
@testable import VertexCore

@Test("Phase 7 is the active Offline AI Studio milestone")
func phaseSevenIsActiveMilestone() {
    let milestone = MilestoneCatalog.current

    #expect(milestone.number == 7)
    #expect(milestone.status == .inProgress)
    #expect(milestone.title == "Offline AI Studio")
    #expect(milestone.deliverables.contains { $0.contains("offline") || $0.contains("Offline") })
    #expect(milestone.deliverables.contains { $0.contains("7.0.0") })
    #expect(milestone.deliverables.contains { $0.contains("Startup") })
}

@Test("AI source candidates retain explicit adoption boundaries")
func sourceCandidatesHaveBoundaries() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    let repositories = Set(sources.map(\.repository))

    #expect(repositories.contains("Apple Vision"))
    #expect(repositories.contains("Apple Core ML"))
    #expect(repositories.contains("DepthAnything/Depth-Anything-V2"))
    #expect(repositories.contains("xinntao/Real-ESRGAN"))
    #expect(repositories.contains("facebookresearch/sam2"))
    #expect(sources.allSatisfy { !$0.license.isEmpty && !$0.purpose.isEmpty })
}

@Test("Unvalidated third-party AI candidates remain research-only")
func aiCandidatesRemainIsolatedUntilValidated() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    let depth = sources.first { $0.repository == "DepthAnything/Depth-Anything-V2" }
    let realESRGAN = sources.first { $0.repository == "xinntao/Real-ESRGAN" }
    let sam = sources.first { $0.repository == "facebookresearch/sam2" }

    #expect(depth?.mode == .researchOnly)
    #expect(realESRGAN?.mode == .researchOnly)
    #expect(sam?.mode == .researchOnly)
}

@Test("Apple-native offline inference boundaries are wrapped dependencies")
func appleNativeAIIsWrapped() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    #expect(sources.first { $0.repository == "Apple Vision" }?.mode == .wrappedDependency)
    #expect(sources.first { $0.repository == "Apple Core ML" }?.mode == .wrappedDependency)
}

@Test("Artifact policy fixes the Phase 7 version and unsigned signing boundary")
func artifactPolicyIsExplicit() {
    let policy = MilestoneCatalog.current.artifactPolicy.lowercased()
    #expect(policy.contains("after-effects-7.0.0-unsigned.ipa"))
    #expect(policy.contains("signing credentials"))
    #expect(policy.contains("phase 7"))
    #expect(policy.contains("model-manifest"))
}
