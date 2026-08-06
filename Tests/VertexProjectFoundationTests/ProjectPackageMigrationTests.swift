import Foundation
import Testing
import VertexCore
import VertexProject
@testable import VertexProjectFoundation

private struct Schema1PackageFixture {
    var root: URL
    var packageURL: URL
    var projectData: Data
    var manifestData: Data

    static func make() throws -> Schema1PackageFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vertex-phase6-migration-\(UUID().uuidString)", isDirectory: true)
        let packageURL = root.appendingPathComponent("Legacy.aeproject", isDirectory: true)
        let layout = try ProjectPackageLayout(root: packageURL)
        try layout.createDirectories()

        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let projectID = VertexID(rawValue: "63000000-0000-0000-0000-000000000001")
        let media = MediaReference.fixture(id: "63000000-0000-0000-0000-000000000010")
        let composition = Schema1CompositionPlaceholder(
            id: VertexID(rawValue: "63000000-0000-0000-0000-000000000020"),
            name: "Legacy Comp"
        )
        let project = Schema1ProjectDocument(
            schemaVersion: 1,
            minimumReaderVersion: 1,
            projectID: projectID,
            revision: 4,
            metadata: ProjectMetadata(
                name: "Legacy Package",
                createdAt: timestamp,
                modifiedAt: timestamp,
                createdByAppVersion: "5.0.0",
                lastSavedByAppVersion: "5.0.0"
            ),
            settings: ProjectSettings(),
            mediaRegistry: [media],
            compositionRegistry: [composition],
            activeCompositionID: composition.id,
            selectedMediaID: media.id,
            renderSettings: ProjectRenderSettings(exposure: 1, outputWidth: 1280, outputHeight: 720),
            appliedCommandIDs: []
        )
        let projectData = try Schema1ProjectCodec.encode(project)
        let manifest = Schema1Manifest(
            schemaVersion: 1,
            minimumReaderVersion: 1,
            projectID: projectID,
            createdByAppVersion: "5.0.0",
            lastSavedByAppVersion: "5.0.0",
            projectRevision: 4,
            projectChecksum: StableProjectSHA256.hexDigest(projectData),
            committedJournalSequence: 0,
            lastSuccessfulSave: timestamp,
            integrityStatus: .valid
        )
        let manifestData = try Schema1ProjectCodec.makeEncoder().encode(manifest)
        try projectData.write(to: layout.projectURL)
        try manifestData.write(to: layout.manifestURL)
        FileManager.default.createFile(atPath: layout.journalURL.path, contents: Data())
        return Schema1PackageFixture(root: root, packageURL: packageURL, projectData: projectData, manifestData: manifestData)
    }
}

@Test("Schema 1 package migration preserves source and resets incompatible history")
func packageMigrationIsNonDestructive() throws {
    let fixture = try Schema1PackageFixture.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let destination = fixture.root.appendingPathComponent("Migrated.aeproject", isDirectory: true)

    let result = try ProjectPackageMigrator().migrate(
        schema1PackageURL: fixture.packageURL,
        destinationURL: destination
    )

    #expect(result.loadResult.document.schemaVersion == 2)
    #expect(result.loadResult.document.revision == 4)
    #expect(result.loadResult.document.layerRegistry.count == 1)
    #expect(result.loadResult.history == ProjectHistorySnapshot())
    #expect(result.loadResult.manifest.committedJournalSequence == 0)
    #expect(try Data(contentsOf: try ProjectPackageLayout(root: fixture.packageURL).projectURL) == fixture.projectData)
    #expect(try Data(contentsOf: try ProjectPackageLayout(root: fixture.packageURL).manifestURL) == fixture.manifestData)
}

@Test("Schema-aware opening rejects future projects without rewriting them")
func futureSchemaOpenIsNonDestructive() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("vertex-phase6-future-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let package = root.appendingPathComponent("Future.aeproject", isDirectory: true)
    let layout = try ProjectPackageLayout(root: package)
    try layout.createDirectories()
    let bytes = Data(#"{"schemaVersion":99,"minimumReaderVersion":99,"projectID":"63000000-0000-0000-0000-000000000099"}"#.utf8)
    try bytes.write(to: layout.projectURL)

    #expect(throws: ProjectError.self) {
        try ProjectPackageOpeningService().open(packageURL: package) {
            root.appendingPathComponent("Should-Not-Exist.aeproject")
        }
    }
    #expect(try Data(contentsOf: layout.projectURL) == bytes)
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Should-Not-Exist.aeproject").path))
}
