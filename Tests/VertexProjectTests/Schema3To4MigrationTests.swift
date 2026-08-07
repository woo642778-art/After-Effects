import Foundation
import Testing
import VertexCore
@testable import VertexProject

private func schema3Phase7FixtureBytes() throws -> Data {
    let source = MediaReference.fixture(
        id: "86000000-0000-0000-0000-000000000001",
        name: "phase7-source.mov"
    )
    var current = try ProjectDocument.makeFixture(
        timestamp: Date(timeIntervalSince1970: 1_700_200_000.25),
        media: [source]
    )
    var composition = current.compositionRegistry[0]
    let layer = ProjectLayer(
        id: VertexID(rawValue: "86000000-0000-0000-0000-000000000010"),
        compositionID: composition.id,
        name: "Schema 3 Layer",
        source: .media(mediaID: source.id, sourceStartTime: .zero),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration)
    )
    composition.layerIDs = [layer.id]
    current.compositionRegistry = [composition]
    current.layerRegistry = [layer]
    current.selectedLayerID = layer.id

    let output = MediaReference.fixture(
        id: "86000000-0000-0000-0000-000000000002",
        name: "phase7-depth.png"
    )
    current.mediaRegistry.append(output)
    let aiAsset = ProjectAIAsset(
        id: VertexID(rawValue: "86000000-0000-0000-0000-000000000020"),
        kind: .depthMap,
        sourceMediaID: source.id,
        outputMediaID: output.id,
        modelIdentifier: "depth-anything-v2-small-f16",
        modelVersion: "phase7-test",
        createdAt: current.metadata.modifiedAt,
        processingSettingsFingerprint: "settings"
    )
    let schema3 = Schema3ProjectDocument(
        schemaVersion: 3,
        minimumReaderVersion: 3,
        projectID: current.projectID,
        revision: 77,
        metadata: ProjectMetadata(
            name: current.metadata.name,
            createdAt: current.metadata.createdAt,
            modifiedAt: current.metadata.modifiedAt,
            createdByAppVersion: "7.0.0",
            lastSavedByAppVersion: "7.0.0"
        ),
        settings: current.settings,
        mediaRegistry: current.mediaRegistry,
        compositionRegistry: current.compositionRegistry,
        layerRegistry: current.layerRegistry,
        aiAssetRegistry: [aiAsset],
        activeCompositionID: current.activeCompositionID,
        selectedLayerID: current.selectedLayerID,
        selectedMediaID: source.id
    )
    return try Schema3ProjectCodec.encode(schema3)
}

@Test("Schema 3 to 4 preserves Phase 7 assets and initializes motion state")
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
}

@Test("Schema 3 to 4 migration is byte deterministic")
func schema3To4MigrationIsDeterministic() throws {
    let source = try schema3Phase7FixtureBytes()
    let registry = ProjectMigrationRegistry.current
    let first = try registry.migrate(source, from: 3, to: 4)
    let second = try registry.migrate(source, from: 3, to: 4)
    #expect(first.data == second.data)
    #expect(first.reports == second.reports)
    #expect(first.reports.map(\.destinationVersion) == [4])
}
