import Testing
@testable import VertexCore

@Test("Phase 10 is the active iPad AE workspace, 3D, and export milestone")
func phaseTenIsActiveMilestone() {
    let milestone = MilestoneCatalog.current

    #expect(milestone.number == 10)
    #expect(milestone.status == .implemented)
    #expect(milestone.title == "iPad AE Workspace and 3D")
    #expect(milestone.deliverables.contains { $0.contains("iPad-only") && $0.contains("AE-style") })
    #expect(milestone.deliverables.contains { $0.contains("3D") && $0.contains("MetalKit") })
    #expect(milestone.deliverables.contains { $0.contains("MOV") && $0.contains("MP4") })
    #expect(milestone.deliverables.contains { $0.contains("Vertex2 10.0.0") })
}

@Test("Phase 10 source references retain explicit Apple platform boundaries")
func sourceCandidatesHaveBoundaries() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    let repositories = Set(sources.map(\.repository))

    #expect(repositories.contains("Apple SwiftUI"))
    #expect(repositories.contains("Apple Metal and MetalKit"))
    #expect(repositories.contains("Apple Model I/O"))
    #expect(repositories.contains("Apple AVFoundation"))
    #expect(sources.allSatisfy { !$0.license.isEmpty && !$0.purpose.isEmpty })
}

@Test("Phase 10 Apple-native runtime integrations remain wrapped dependencies")
func appleNativeDependenciesAreWrapped() {
    let sources = MilestoneCatalog.current.sourceAdoptions

    #expect(sources.first { $0.repository == "Apple SwiftUI" }?.mode == .wrappedDependency)
    #expect(sources.first { $0.repository == "Apple Metal and MetalKit" }?.mode == .wrappedDependency)
    #expect(sources.first { $0.repository == "Apple Model I/O" }?.mode == .wrappedDependency)
    #expect(sources.first { $0.repository == "Apple AVFoundation" }?.mode == .wrappedDependency)
}

@Test("Artifact policy fixes the Phase 10 version, qualification gates, and unsigned signing boundary")
func artifactPolicyIsExplicit() {
    let policy = MilestoneCatalog.current.artifactPolicy.lowercased()

    #expect(policy.contains("vertex2-10.0.0-unsigned.ipa"))
    #expect(policy.contains("phase 10"))
    #expect(policy.contains("ipad simulator tests"))
    #expect(policy.contains("bundle inspection"))
    #expect(policy.contains("ipa audit"))
    #expect(policy.contains("sha-256"))
    #expect(policy.contains("signing credentials"))
}
