import Foundation
import Testing
import VertexCore
@testable import VertexProject

private func schema2FixtureBytes() throws -> Data {
    let source = MediaReference.fixture(
        id: "73000000-0000-0000-0000-000000000001",
        name: "source.mov"
    )
    let current = try ProjectDocument.makeFixture(
        timestamp: Date(timeIntervalSince1970: 1_700_100_000.125),
        media: [source]
    )
    let schema2 = Schema2ProjectDocument(
        schemaVersion: 2,
        minimumReaderVersion: 2,
        projectID: current.projectID,
        revision: 12,
        metadata: ProjectMetadata(
            name: current.metadata.name,
            createdAt: current.metadata.createdAt,
            modifiedAt: current.metadata.modifiedAt,
            createdByAppVersion: "6.0.0",
            lastSavedByAppVersion: "6.0.0"
        ),
        settings: current.settings,
        mediaRegistry: current.mediaRegistry,
        compositionRegistry: current.compositionRegistry,
        layerRegistry: current.layerRegistry,
        activeCompositionID: current.activeCompositionID,
        selectedLayerID: current.selectedLayerID,
        selectedMediaID: current.selectedMediaID
    )
    return try Schema2ProjectCodec.encode(schema2)
}

@Test("Current codec migrates schema 2 through every registered migration without inventing AI or motion state")
func schema2MigratesThroughCurrentSchema() throws {
    let source = try schema2FixtureBytes()
    let codec = DeterministicProjectCodec()
    let migrated = try codec.decode(source)

    #expect(migrated.schemaVersion == ProjectDocument.currentSchemaVersion)
    #expect(migrated.minimumReaderVersion == ProjectDocument.currentSchemaVersion)
    #expect(migrated.metadata.lastSavedByAppVersion == ProjectDocument.currentAppVersion)
    #expect(migrated.revision == 12)
    #expect(migrated.mediaRegistry.count == 1)
    #expect(migrated.compositionRegistry.count == 1)
    #expect(migrated.layerRegistry.isEmpty)
    #expect(migrated.aiAssetRegistry.isEmpty)
}

@Test("Schema 2 to 3 intermediate migration remains byte deterministic")
func schema2MigrationIsDeterministic() throws {
    let source = try schema2FixtureBytes()
    let registry = ProjectMigrationRegistry.current
    let first = try registry.migrate(source, from: 2, to: 3)
    let second = try registry.migrate(source, from: 2, to: 3)

    #expect(first.data == second.data)
    #expect(first.reports == second.reports)
    #expect(first.reports.map(\.destinationVersion) == [3])
    let intermediate = try Schema3ProjectCodec.decode(first.data)
    #expect(intermediate.schemaVersion == 3)
    #expect(intermediate.metadata.lastSavedByAppVersion == "7.0.0")
}
