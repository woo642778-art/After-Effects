import Testing
import VertexProject
@testable import Vertex

@Test func effectCatalogShowsOnlyActuallyImplementedEffects() {
    let catalog = VertexEffectCatalog.entries
    #expect(catalog.map(\.type) == [
        .gaussianBlur,
        .sharpen,
        .exposure,
        .colorControls,
        .hueAdjust,
        .invert,
        .depthMap,
        .cutout,
        .upscale,
        .restore
    ])
    #expect(Set(catalog.map(\.category)) == ["AI", "Blur & Sharpen", "Color Correction", "Channel"])
}

@Test func effectCatalogSearchMatchesNamesKeywordsAndFuzzyAliases() {
    #expect(VertexEffectCatalog.search("depth").map(\.type) == [.depthMap])
    #expect(VertexEffectCatalog.search("denoise").map(\.type) == [.restore])
    #expect(VertexEffectCatalog.search("gauss").first?.type == .gaussianBlur)
    #expect(VertexEffectCatalog.search("brt").contains(where: { $0.type == .colorControls }))
    #expect(VertexEffectCatalog.search("").count == 10)
}
