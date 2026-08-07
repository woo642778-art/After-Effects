import Testing
@testable import VertexCore

@Test("Phase 6 is the active implemented milestone")
func phaseSixIsActiveMilestone() {
    let milestone = MilestoneCatalog.current

    #expect(milestone.number == 6)
    #expect(milestone.status == .implemented)
    #expect(milestone.title == "Layers, Compositions, and Multi-Source Rendering")
    #expect(milestone.deliverables.contains { $0.contains("schema 2") })
    #expect(milestone.deliverables.contains { $0.contains("6.0.0") })
}

@Test("Core source candidates retain explicit adoption boundaries")
func sourceCandidatesHaveBoundaries() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    let repositories = Set(sources.map(\.repository))

    #expect(repositories.contains("Apple Foundation"))
    #expect(repositories.contains("Apple AVFoundation"))
    #expect(repositories.contains("Apple Metal"))
    #expect(repositories.contains("MetalPetal/MetalPetal"))
    #expect(repositories.contains("ruanjx/VideoLab"))
    #expect(sources.allSatisfy { !$0.license.isEmpty && !$0.purpose.isEmpty })
}

@Test("Third-party GPU candidates remain unlinked research dependencies")
func gpuCandidatesRemainIsolated() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    let metalPetal = sources.first { $0.repository == "MetalPetal/MetalPetal" }

    #expect(metalPetal?.mode == .researchOnly)
}

@Test("Design references remain non-product dependencies")
func designReferencesRemainIsolated() {
    let videoLab = MilestoneCatalog.current.sourceAdoptions.first { $0.repository == "ruanjx/VideoLab" }
    #expect(videoLab?.mode == .designReference)
}

@Test("Artifact policy fixes the phase-major version and signing boundary")
func artifactPolicyIsExplicit() {
    let policy = MilestoneCatalog.current.artifactPolicy.lowercased()
    #expect(policy.contains("after-effects-6.0.0-unsigned.ipa"))
    #expect(policy.contains("signing credentials"))
    #expect(policy.contains("phase 6"))
}