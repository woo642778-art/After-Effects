import Foundation
import Testing
import VertexCore
@testable import VertexProject

private func schema1Bytes(selectedMedia: Bool) throws -> Data {
    let projectID = VertexID(rawValue: "63000000-0000-0000-0000-000000000001")
    let compositionID = VertexID(rawValue: "63000000-0000-0000-0000-000000000002")
    let media = MediaReference.fixture(id: "63000000-0000-0000-0000-000000000003")
    let legacy = Schema1ProjectDocument(
        schemaVersion: 1,
        minimumReaderVersion: 1,
        projectID: projectID,
        revision: 7,
        metadata: ProjectMetadata(
            name: "Migrated",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000.123),
            modifiedAt: Date(timeIntervalSince1970: 1_700_000_010.456),
            createdByAppVersion: "5.0.0",
            lastSavedByAppVersion: "5.0.0"
        ),
        settings: ProjectSettings(),
        mediaRegistry: [media],
        compositionRegistry: [Schema1CompositionPlaceholder(id: compositionID, name: "Legacy Comp")],
        activeCompositionID: compositionID,
        selectedMediaID: selectedMedia ? media.id : nil,
        renderSettings: ProjectRenderSettings(
            exposure: 1.25,
            saturation: 0.8,
            opacity: 0.75,
            inverted: true,
            scale: 1.2,
            translationX: 0.1,
            translationY: -0.2,
            outputWidth: 1920,
            outputHeight: 1080
        )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
    encoder.nonConformingFloatEncodingStrategy = .throw
    return try encoder.encode(legacy)
}

@Test("Schema 1 migrates deterministically through every registered migration to the current schema")
func schema1MigratesToCurrentSchema() throws {
    let source = try schema1Bytes(selectedMedia: true)
    let codec = DeterministicProjectCodec()
    let first = try codec.decode(source)
    let second = try codec.decode(source)

    #expect(first == second)
    #expect(first.schemaVersion == ProjectDocument.currentSchemaVersion)
    #expect(first.minimumReaderVersion == ProjectDocument.currentSchemaVersion)
    #expect(first.metadata.lastSavedByAppVersion == ProjectDocument.currentAppVersion)
    #expect(first.revision == 7)
    #expect(first.compositionRegistry.count == 1)
    #expect(first.layerRegistry.count == 1)
    #expect(first.aiAssetRegistry.isEmpty)
    #expect(first.activeCompositionID == first.compositionRegistry[0].id)
    #expect(first.selectedLayerID == first.layerRegistry[0].id)
    #expect(first.selectedMediaID == first.mediaRegistry[0].id)
    #expect(first.compositionRegistry[0].width == 1920)
    #expect(first.compositionRegistry[0].height == 1080)
    #expect(first.layerRegistry[0].transform.opacity == 0.75)
    #expect(first.layerRegistry[0].transform.scaleX == 1.2)
    #expect(first.layerRegistry[0].operations.contains(.exposure(stops: 1.25)))

    let encoded = try codec.encode(first)
    let json = String(decoding: encoded, as: UTF8.self)
    #expect(json.contains("\"aiAssetRegistry\":[]"))
    #expect(!json.contains("bookmarkData"))
    #expect(!json.contains("appliedCommandIDs"))
    #expect(!json.contains("legacyRenderSettings"))
    #expect(!json.contains("renderSettings"))
}

@Test("Schema 1 without selected media creates an empty current-schema composition")
func schema1WithoutSelectionCreatesEmptyComposition() throws {
    let migrated = try DeterministicProjectCodec().decode(schema1Bytes(selectedMedia: false))
    #expect(migrated.schemaVersion == ProjectDocument.currentSchemaVersion)
    #expect(migrated.compositionRegistry.count == 1)
    #expect(migrated.layerRegistry.isEmpty)
    #expect(migrated.aiAssetRegistry.isEmpty)
    #expect(migrated.selectedLayerID == nil)
}

@Test("Future schemas remain rejected")
func futureSchemaRejected() throws {
    let object: [String: Any] = [
        "schemaVersion": 99,
        "minimumReaderVersion": 99,
        "projectID": "63000000-0000-0000-0000-000000000001"
    ]
    let data = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: ProjectError.self) {
        try DeterministicProjectCodec().decode(data)
    }
}
