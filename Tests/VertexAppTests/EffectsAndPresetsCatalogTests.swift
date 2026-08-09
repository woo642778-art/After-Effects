import Testing
import VertexProject
@testable import Vertex

@Test func effectCatalogShowsOnlyActuallyImplementedEffects() {
    let catalog = VertexEffectCatalog.entries
    #expect(catalog.map(\.type) == [.depthMap, .cutout, .upscale, .restore])
    #expect(Set(catalog.map(\.category)) == ["AI"])
}

@Test func effectCatalogSearchMatchesNamesAndKeywords() {
    #expect(VertexEffectCatalog.search("depth").map(\.type) == [.depthMap])
    #expect(VertexEffectCatalog.search("denoise").map(\.type) == [.restore])
    #expect(VertexEffectCatalog.search("").count == 4)
}
