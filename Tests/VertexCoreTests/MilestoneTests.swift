import Testing
@testable import VertexCore

@Test("Phase 3 is the active implemented milestone")
func phaseThreeIsActiveMilestone() {
    let milestone = MilestoneCatalog.current

    #expect(milestone.number == 3)
    #expect(milestone.status == .implemented)
    #expect(milestone.title == "Media Input and Output Foundation")
    #expect(milestone.deliverables.contains { $0.contains("AVFoundation metadata inspection") })
    #expect(milestone.deliverables.contains { $0.contains("3.0.0") })
}

@Test("Core source candidates retain explicit adoption boundaries")
func sourceCandidatesHaveBoundaries() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    let repositories = Set(sources.map(\.repository))

    #expect(repositories.contains("Apple AVFoundation"))
    #expect(repositories.contains("MetalPetal/MetalPetal"))
    #expect(repositories.contains("MetalPetal/VideoIO"))
    #expect(repositories.contains("ruanjx/VideoLab"))
    #expect(sources.allSatisfy { !$0.license.isEmpty && !$0.purpose.isEmpty })
}

@Test("GPL UI source remains isolated to behavioral reference")
func gplSourceIsNotAdoptedIntoProduct() {
    let miniCut = MilestoneCatalog.current.sourceAdoptions.first { $0.repository == "fwcd/mini-cut" }
    #expect(miniCut?.mode == .behavioralReference)
}

@Test("Artifact policy fixes the phase-major version and signing boundary")
func artifactPolicyIsExplicit() {
    let policy = MilestoneCatalog.current.artifactPolicy.lowercased()
    #expect(policy.contains("after-effects-3.0.0-unsigned.ipa"))
    #expect(policy.contains("signing credentials"))
    #expect(policy.contains("major version"))
}
