import Foundation
import Testing
import VertexCore
import VertexProject
@testable import VertexProjectPersistence

private func schema1PackageURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("vertex-schema1-package-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("Native")
        .appendingPathExtension(VertexProjectPackageLayout.requiredExtension)
}

private func writeNativeSchema1Package(at url: URL) throws -> (VertexID, VertexID, VertexID) {
    let projectID = VertexID(rawValue: "69000000-0000-0000-0000-000000000001")
    let compositionID = VertexID(rawValue: "69000000-0000-0000-0000-000000000002")
    let mediaID = VertexID(rawValue: "69000000-0000-0000-0000-000000000003")
    let timestamp = Date(timeIntervalSince1970: 1_700_000_000.123)
    let media = MediaReference.fixture(id: mediaID.rawValue, name: "native.mov")
    let legacy = Schema1ProjectDocument(
        schemaVersion: 1,
        minimumReaderVersion: 1,
        projectID: projectID,
        revision: 9,
        metadata: ProjectMetadata(
            name: "Native Schema 1",
            createdAt: timestamp,
            modifiedAt: timestamp,
            createdByAppVersion: "5.0.0",
            lastSavedByAppVersion: "5.0.0"
        ),
        settings: ProjectSettings(),
        mediaRegistry: [media],
        compositionRegistry: [Schema1CompositionPlaceholder(id: compositionID, name: "Legacy Main")],
        activeCompositionID: compositionID,
        selectedMediaID: mediaID,
        renderSettings: ProjectRenderSettings(
            exposure: 1.5,
            saturation: 0.7,
            opacity: 0.6,
            inverted: true,
            scale: 1.1,
            translationX: 0.1,
            translationY: -0.1,
            outputWidth: 1280,
            outputHeight: 720
        )
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
    encoder.nonConformingFloatEncodingStrategy = .throw
    let projectData = try encoder.encode(legacy.validated())
    let manifest = try VertexProjectManifest(
        schemaVersion: 1,
        minimumReaderVersion: 1,
        projectID: projectID,
        projectRevision: legacy.revision,
        projectChecksum: DeterministicProjectCodec().checksum(data: projectData),
        createdByAppVersion: "5.0.0",
        lastSavedByAppVersion: "5.0.0",
        lastSuccessfulSave: timestamp
    )
    let manifestData = try VertexProjectManifestCodec().encode(manifest)

    let layout = try VertexProjectPackageLayout(root: url)
    try layout.createRequiredDirectories()
    try projectData.write(to: layout.projectURL)
    try manifestData.write(to: layout.manifestURL)
    return (projectID, compositionID, mediaID)
}

@Test("Native schema 1 vertexproject opens by atomically migrating to schema 2")
func nativeSchema1PackageMigratesOnOpen() throws {
    let url = schema1PackageURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let identities = try writeNativeSchema1Package(at: url)

    guard case .opened(let snapshot) = try VertexProjectPackageStore().open(at: url) else {
        Issue.record("Native schema 1 package should migrate without a pending user decision.")
        return
    }
    #expect(snapshot.document.schemaVersion == 2)
    #expect(snapshot.manifest.schemaVersion == 2)
    #expect(snapshot.document.projectID == identities.0)
    #expect(snapshot.document.activeCompositionID == identities.1)
    #expect(snapshot.document.selectedMediaID == identities.2)
    #expect(snapshot.document.layerRegistry.count == 1)
    #expect(snapshot.document.composition(id: identities.1)?.width == 1280)
    #expect(snapshot.document.composition(id: identities.1)?.height == 720)
    #expect(!FileManager.default.fileExists(atPath: snapshot.layout.pendingSaveURL.path))

    let persistedHeader = try ProjectSchemaHeader.decode(from: Data(contentsOf: snapshot.layout.projectURL))
    #expect(persistedHeader.schemaVersion == 2)
    let persistedManifest = try VertexProjectManifestCodec().decode(Data(contentsOf: snapshot.layout.manifestURL))
    #expect(persistedManifest.schemaVersion == 2)

    guard case .opened(let reopened) = try VertexProjectPackageStore().open(at: url) else {
        Issue.record("Migrated schema 2 package should reopen directly.")
        return
    }
    #expect(reopened.document == snapshot.document)
    #expect(reopened.projectData == snapshot.projectData)
}
