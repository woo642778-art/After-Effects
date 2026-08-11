import Testing
import VertexProject
@testable import Vertex

@Test func effectCatalogShowsOnlyActuallyImplementedEffects() {
    let catalog = VertexEffectCatalog.entries
    #expect(catalog.count == 25)
    #expect(Set(catalog.map(\.type)) == Set(ProjectEffectType.allCases))
    #expect(Set(catalog.map(\.category)) == ["AI", "Blur & Sharpen", "Color Correction", "Channel", "Stylize", "Distort"])
}

@Test func effectCatalogMetadataComesFromSharedDescriptors() {
    let catalog = VertexEffectCatalog.entries
    let descriptors = ProjectEffectDescriptorRegistry.all
    #expect(catalog.count == descriptors.count)
    #expect(catalog.map(\.descriptor) == descriptors)
    for entry in catalog {
        #expect(entry.name == entry.type.descriptor.displayName)
        #expect(entry.category == entry.type.descriptor.category.displayName)
        #expect(entry.keywords == entry.type.descriptor.keywords)
        #expect(entry.description == entry.type.descriptor.summary)
    }
}

@Test func effectCatalogSearchMatchesNamesKeywordsAndFuzzyAliases() {
    #expect(VertexEffectCatalog.search("depth").map(\.type) == [.depthMap])
    #expect(VertexEffectCatalog.search("denoise").contains(where: { $0.type == .restore || $0.type == .noiseReduction }))
    #expect(VertexEffectCatalog.search("gauss").first?.type == .gaussianBlur)
    #expect(VertexEffectCatalog.search("brt").contains(where: { $0.type == .colorControls }))
    #expect(VertexEffectCatalog.search("glow").contains(where: { $0.type == .glow }))
    #expect(VertexEffectCatalog.search("").count == 25)
}

@Test func fullIndexedBrowserIncludesVerifiedReferenceCatalog() {
    #expect(EffectIndexedCatalog.entries.count == 1_568)
    #expect(VertexEffectCatalog.searchAll("S_Glow").contains(where: { $0.product == "Boris FX Sapphire" }))
    #expect(VertexEffectCatalog.searchAll("Deep Glow").contains(where: { !$0.isImplemented }))
}
