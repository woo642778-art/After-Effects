import Foundation
import Testing
import VertexAI
@testable import VertexAICoreML

private func registryManifest() -> AIModelManifest {
    AIModelManifest(models: [
        AIModelManifestEntry(
            modelID: "fixture-model",
            task: "fixture",
            upstream: "https://example.com/fixture",
            upstreamVersion: "1",
            license: "MIT",
            sourceSHA256: String(repeating: "a", count: 64),
            convertedSHA256: nil,
            precision: "float16",
            compiledSizeBytes: nil,
            minimumTier: .preview,
            bundleRelativePath: "AIModels/Fixture.mlmodelc"
        )
    ])
}

@Test("Registry construction is lazy and does not load model bytes")
func registryStartsEmpty() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("vertex-ai-registry-\(UUID().uuidString)", isDirectory: true)
    let registry = try AIModelRegistry(resourceRoot: root, manifest: registryManifest())
    #expect(registry.residentModelIDs.isEmpty)
}

@Test("Hardware classifier accepts A17 Pro and M1-class identifiers conservatively")
func hardwareClassFloor() {
    #expect(HardwareClassClassifier.supportsMaxQuality(machineIdentifier: "iPhone16,1"))
    #expect(HardwareClassClassifier.supportsMaxQuality(machineIdentifier: "iPhone17,2"))
    #expect(!HardwareClassClassifier.supportsMaxQuality(machineIdentifier: "iPhone15,2"))
    #expect(HardwareClassClassifier.supportsMaxQuality(machineIdentifier: "iPad13,4"))
    #expect(HardwareClassClassifier.supportsMaxQuality(machineIdentifier: "iPad13,16"))
    #expect(!HardwareClassClassifier.supportsMaxQuality(machineIdentifier: "iPad13,2"))
}

#if canImport(CoreML)
import CoreML

@Test("Missing compiled model fails locally without becoming resident")
func missingModelFailsClosed() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("vertex-ai-registry-missing-\(UUID().uuidString)", isDirectory: true)
    let registry = try AIModelRegistry(resourceRoot: root, manifest: registryManifest())
    do {
        _ = try registry.withModel(for: "fixture-model") { _ in true }
        Issue.record("Missing model should fail closed")
    } catch {
        #expect(error is AIError)
    }
    #expect(registry.residentModelIDs.isEmpty)
}
#endif
