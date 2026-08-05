import Testing
@testable import VertexCore

@Test("Phase 1 is the active implemented milestone")
func phaseOneIsActive() {
    let milestone = MilestoneCatalog.current
    #expect(milestone.number == 1)
    #expect(milestone.status == .implemented)
    #expect(milestone.title == "Repository Foundation and Source Audit")
}

@Test("Core source candidates have explicit adoption boundaries")
func sourceCandidatesHaveBoundaries() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    let repositories = Set(sources.map(\.repository))

    #expect(repositories.contains("MetalPetal/MetalPetal"))
    #expect(repositories.contains("MetalPetal/VideoIO"))
    #expect(repositories.contains("ruanjx/VideoLab"))
    #expect(sources.allSatisfy { !$0.license.isEmpty && !$0.purpose.isEmpty })
}

@Test("GPL UI source is isolated to behavioral reference")
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
