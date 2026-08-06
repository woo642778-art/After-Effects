import Testing
@testable import VertexCore

@Test("Phase 5 is the active implemented milestone")
func phaseFiveIsActiveMilestone() {
    let milestone = MilestoneCatalog.current

    #expect(milestone.number == 5)
    #expect(milestone.status == .implemented)
    #expect(milestone.title == "Project Persistence and Recovery")
    #expect(milestone.deliverables.contains { $0.contains("write-ahead journal") })
    #expect(milestone.deliverables.contains { $0.contains("5.0.0") })
}

@Test("Core source candidates retain explicit adoption boundaries")
func sourceCandidatesHaveBoundaries() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    let repositories = Set(sources.map(\.repository))

    #expect(repositories.contains("Apple Foundation"))
    #expect(repositories.contains("Apple AVFoundation"))
    #expect(repositories.contains("Apple Metal"))
    #expect(repositories.contains("MetalPetal/MetalPetal"))
    #expect(repositories.contains("MetalPetal/VideoIO"))
    #expect(repositories.contains("ruanjx/VideoLab"))
    #expect(sources.allSatisfy { !$0.license.isEmpty && !$0.purpose.isEmpty })
}

@Test("Third-party GPU candidates remain unlinked research dependencies")
func gpuCandidatesRemainIsolated() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    let metalPetal = sources.first { $0.repository == "MetalPetal/MetalPetal" }
    let videoIO = sources.first { $0.repository == "MetalPetal/VideoIO" }

    #expect(metalPetal?.mode == .researchOnly)
    #expect(videoIO?.mode == .researchOnly)
}

@Test("GPL UI source remains isolated to behavioral reference")
func gplSourceIsNotAdoptedIntoProduct() {
    let miniCut = MilestoneCatalog.current.sourceAdoptions.first { $0.repository == "fwcd/mini-cut" }
    #expect(miniCut?.mode == .behavioralReference)
}

@Test("Artifact policy fixes the phase-major version and signing boundary")
func artifactPolicyIsExplicit() {
    let policy = MilestoneCatalog.current.artifactPolicy.lowercased()
    #expect(policy.contains("after-effects-5.0.0-unsigned.ipa"))
    #expect(policy.contains("signing credentials"))
    #expect(policy.contains("major version"))
}
