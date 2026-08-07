import Testing
@testable import VertexAI

private func entry(
    id: String = "depth",
    path: String = "AIModels/depth.mlmodelc",
    sourceSHA: String = String(repeating: "a", count: 64)
) -> AIModelManifestEntry {
    AIModelManifestEntry(
        modelID: id,
        task: "depth",
        upstream: "https://example.com/model",
        upstreamVersion: "abc123",
        license: "Apache-2.0",
        sourceSHA256: sourceSHA,
        convertedSHA256: nil,
        precision: "float16",
        compiledSizeBytes: nil,
        minimumTier: .preview,
        bundleRelativePath: path
    )
}

@Test("Valid model manifest accepts pinned HTTPS model")
func validManifest() throws {
    let manifest = AIModelManifest(models: [entry()])
    _ = try manifest.validated()
}

@Test("Manifest rejects invalid source digest")
func invalidDigest() {
    #expect(throws: AIError.self) {
        _ = try AIModelManifest(models: [entry(sourceSHA: "bad")]).validated()
    }
}

@Test("Manifest rejects duplicate identifiers")
func duplicateIDs() {
    #expect(throws: AIError.self) {
        _ = try AIModelManifest(models: [entry(), entry()]).validated()
    }
}

@Test("Manifest rejects duplicate bundle paths")
func duplicatePaths() {
    #expect(throws: AIError.self) {
        _ = try AIModelManifest(models: [entry(id: "a"), entry(id: "b")]).validated()
    }
}

@Test("Shipping validation requires converted digest")
func convertedDigestRequiredForShipping() {
    #expect(throws: AIError.self) {
        _ = try AIModelManifest(models: [entry()]).validated(requireConvertedDigests: true)
    }
}
