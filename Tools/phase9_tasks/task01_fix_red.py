from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "Tests/VertexProjectTests/Schema3To4MigrationTests.swift"
text = path.read_text()

old_asset = '''    let aiAsset = ProjectAIAsset(
        id: VertexID(rawValue: "86000000-0000-0000-0000-000000000020"),
        kind: .depthMap,
        sourceMediaID: source.id,
        outputMediaID: output.id,
        modelIdentifier: "depth-anything-v2-small-f16",
        modelVersion: "phase7-test",
        createdAt: current.metadata.modifiedAt,
        processingSettingsFingerprint: "settings"
    )'''
new_asset = '''    let aiAsset = ProjectAIAsset(
        id: VertexID(rawValue: "86000000-0000-0000-0000-000000000020"),
        kind: .depth,
        sourceMediaID: source.id,
        outputMediaID: output.id,
        recipe: ProjectAIRecipeReference(
            task: "depth",
            modelID: "depth-anything-v2-small-f16",
            modelDigest: String(repeating: "a", count: 64),
            recipeDigest: String(repeating: "b", count: 64),
            qualityTier: "balanced"
        )
    )'''
if old_asset in text:
    text = text.replace(old_asset, new_asset, 1)
elif new_asset not in text:
    raise RuntimeError("Schema3To4 AI fixture marker not found")

old_test = '''@Test("Schema 3 to 4 preserves Phase 7 assets and initializes motion state")
func schema3MigratesToSchema4() throws {
    let source = try schema3Phase7FixtureBytes()
    let migrated = try DeterministicProjectCodec().decode(source)

    #expect(migrated.schemaVersion == 4)
    #expect(migrated.minimumReaderVersion == 4)
    #expect(migrated.metadata.lastSavedByAppVersion == "8.0.0")
    #expect(migrated.revision == 77)
    #expect(migrated.aiAssetRegistry.count == 1)
    #expect(migrated.mediaRegistry.count == 2)
    let layer = try #require(migrated.layerRegistry.first)
    #expect(layer.animationChannels.isEmpty)
    #expect(layer.masks.isEmpty)
    #expect(layer.trackMatte == nil)
}'''
new_test = '''@Test("Schema 3 to 4 preserves Phase 7 assets and initializes motion state")
func schema3MigratesToSchema4() throws {
    let source = try schema3Phase7FixtureBytes()
    let step = try ProjectMigrationRegistry.current.migrate(source, from: 3, to: 4)
    let migrated = try Schema4ProjectCodec.decode(step.data)

    #expect(migrated.schemaVersion == 4)
    #expect(migrated.minimumReaderVersion == 4)
    #expect(migrated.metadata.lastSavedByAppVersion == "8.0.0")
    #expect(migrated.revision == 77)
    #expect(migrated.aiAssetRegistry.count == 1)
    #expect(migrated.mediaRegistry.count == 2)
    let layer = try #require(migrated.layerRegistry.first)
    #expect(layer.animationChannels.isEmpty)
    #expect(layer.masks.isEmpty)
    #expect(layer.trackMatte == nil)
}'''
if old_test in text:
    text = text.replace(old_test, new_test, 1)
elif new_test not in text:
    raise RuntimeError("Schema3To4 test marker not found")

path.write_text(text)
print("Task 1 RED fixture applied")
