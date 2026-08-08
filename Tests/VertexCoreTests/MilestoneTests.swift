import Testing
@testable import VertexCore

@Test("Phase 9 is the active AE workspace and live AI effects milestone")
func phaseNineIsActiveMilestone() {
    let milestone = MilestoneCatalog.current

    #expect(milestone.number == 9)
    #expect(milestone.status == .implemented)
    #expect(milestone.title == "AE Workspace and Live AI Effects")
    #expect(milestone.deliverables.contains { $0.contains("AE-style") })
    #expect(milestone.deliverables.contains { $0.contains("Depth Map") && $0.contains("Cutout") })
    #expect(milestone.deliverables.contains { $0.contains("Vertex2 9.0.0") })
}

@Test("Phase 9 source references retain explicit adoption boundaries")
func sourceCandidatesHaveBoundaries() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    let repositories = Set(sources.map(\.repository))

    #expect(repositories.contains("Apple SwiftUI"))
    #expect(repositories.contains("Apple Core ML and Vision"))
    #expect(repositories.contains("AcademySoftwareFoundation/OpenTimelineIO"))
    #expect(repositories.contains("NatronGitHub/Natron"))
    #expect(sources.allSatisfy { !$0.license.isEmpty && !$0.purpose.isEmpty })
}

@Test("Reference-only compositor and timeline sources remain design references")
func thirdPartyReferencesRemainNonRuntime() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    let openTimelineIO = sources.first { $0.repository == "AcademySoftwareFoundation/OpenTimelineIO" }
    let natron = sources.first { $0.repository == "NatronGitHub/Natron" }

    #expect(openTimelineIO?.mode == .designReference)
    #expect(natron?.mode == .designReference)
}

@Test("Apple-native editing and inference boundaries are wrapped dependencies")
func appleNativeDependenciesAreWrapped() {
    let sources = MilestoneCatalog.current.sourceAdoptions
    #expect(sources.first { $0.repository == "Apple SwiftUI" }?.mode == .wrappedDependency)
    #expect(sources.first { $0.repository == "Apple Core ML and Vision" }?.mode == .wrappedDependency)
}

@Test("Artifact policy fixes the Phase 9 version and unsigned signing boundary")
func artifactPolicyIsExplicit() {
    let policy = MilestoneCatalog.current.artifactPolicy.lowercased()
    #expect(policy.contains("vertex2-9.0.0-unsigned.ipa"))
    #expect(policy.contains("signing credentials"))
    #expect(policy.contains("phase 9"))
    #expect(policy.contains("model/license audits"))
    #expect(policy.contains("independent ipa audit"))
    #expect(policy.contains("sha-256"))
}
