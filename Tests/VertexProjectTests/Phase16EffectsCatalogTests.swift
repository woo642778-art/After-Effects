import Testing
@testable import VertexProject

@Test("V16 exposes the complete 1,568-entry reference catalog")
func phase16IndexedCatalogCount() {
    #expect(EffectIndexedCatalog.entries.count == 1_568)
    #expect(Set(EffectIndexedCatalog.entries.map(\.id)).count == 1_568)
}

@Test("Indexed effect search finds native and reference entries without pretending all are implemented")
func phase16IndexedCatalogSearchAndStatus() {
    let glow = EffectIndexedCatalog.search("glow")
    #expect(glow.contains(where: { $0.name == "Glow" && $0.product == "Adobe After Effects" }))
    #expect(glow.contains(where: { $0.name.localizedCaseInsensitiveContains("glow") }))

    let gaussian = EffectIndexedCatalog.entries.first { $0.name == "Gaussian Blur" && $0.product == "Adobe After Effects" }
    #expect(gaussian?.status == .nativeImplemented)

    let sapphire = EffectIndexedCatalog.entries.first { $0.product == "Boris FX Sapphire" }
    #expect(sapphire != nil)
    #expect(sapphire?.status != .nativeImplemented)
    #expect(sapphire?.status != .aiImplemented)
}

@Test("Preview update gate coalesces high-frequency slider events while preserving final commits")
func phase16PreviewUpdateGate() {
    var gate = EffectPreviewUpdateGate(minimumInterval: 0.05)
    #expect(gate.shouldCommit(at: 1.00))
    #expect(!gate.shouldCommit(at: 1.01))
    #expect(!gate.shouldCommit(at: 1.049))
    #expect(gate.shouldCommit(at: 1.05))
    #expect(gate.shouldCommitFinal(at: 1.051))
    #expect(!gate.shouldCommit(at: 1.052))
}
