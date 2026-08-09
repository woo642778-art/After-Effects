import Testing
@testable import VertexProject

@Test("Vertex2 12 compatibility audit preserves the full indexed reference count")
func compatibilityAuditTotalsRemainTruthful() throws {
    try EffectCompatibilityAudit.validate()

    #expect(EffectCompatibilityAudit.indexedEntryCount == 1_568)
    #expect(EffectCompatibilityAudit.families.reduce(0, { $0 + $1.indexedEntryCount }) == 1_568)
    #expect(EffectCompatibilityAudit.implementedCount == ProjectEffectType.allCases.count)
    #expect(EffectCompatibilityAudit.implementedCount == 10)
    #expect(EffectCompatibilityAudit.remainingIndexedCount == 1_558)
}

@Test("Commercial plugin families are plans rather than fake native implementations")
func commercialFamiliesRemainCleanRoomPlans() {
    let cleanRoomFamilies: Set<EffectCompatibilityFamily> = [.continuum, .sapphire, .redGiantUniverse]
    let summaries = EffectCompatibilityAudit.families.filter { cleanRoomFamilies.contains($0.family) }

    #expect(summaries.count == cleanRoomFamilies.count)
    #expect(summaries.allSatisfy { $0.defaultStatus == .cleanRoomPlanned })
}

@Test("Extensions and scripts remain workflow categories")
func workflowFamiliesAreNotPixelEffects() {
    let extensions = EffectCompatibilityAudit.families.first { $0.family == .extensions }
    let scripts = EffectCompatibilityAudit.families.first { $0.family == .scripts }

    #expect(extensions?.defaultStatus == .workflowExtension)
    #expect(scripts?.defaultStatus == .scriptCommand)
}
