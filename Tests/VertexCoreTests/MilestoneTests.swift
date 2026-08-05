import Testing
@testable import VertexCore

@Test("Phase 2 is the active implemented milestone")
func phaseTwoIsActiveMilestone() {
    let milestone = MilestoneCatalog.current

    #expect(milestone.number == 2)
    #expect(milestone.status == .implemented)
    #expect(milestone.title == "Core Architecture and Product Identity")
    #expect(milestone.deliverables.contains { $0.contains("rational timeline time") })
}

@Test("Core source candidates retain explicit adoption boundaries")
func sourceCandidatesHaveBoundaries() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    let repositories = Set(sources.map(\.repository))

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

@Test("Artifact policy distinguishes unsigned and signed IPA files")
func artifactPolicyIsExplicit() {
    let policy = MilestoneCatalog.current.artifactPolicy.lowercased()
    #expect(policy.contains("unsigned ipa"))
    #expect(policy.contains("signing credentials"))
}
