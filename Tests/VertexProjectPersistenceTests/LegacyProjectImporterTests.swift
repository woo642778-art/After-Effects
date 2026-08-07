import Foundation
import Testing
import VertexCore
import VertexProject
@testable import VertexProjectPersistence

private let legacyImportProjectID = VertexID(rawValue: "57000000-0000-0000-0000-000000000001")
private let legacyImportCompositionID = VertexID(rawValue: "57000000-0000-0000-0000-000000000010")
private let legacyBookmarkMediaID = VertexID(rawValue: "57000000-0000-0000-0000-000000000020")
private let legacyMissingMediaID = VertexID(rawValue: "57000000-0000-0000-0000-000000000021")
private let legacyEmbeddedMediaID = VertexID(rawValue: "57000000-0000-0000-0000-000000000022")

private struct LegacyImportFixture {
    let sourceURL: URL
    let embeddedBytes: Data
    let originalCreatedAt: Date
    let originalModifiedAt: Date
}

private func legacyImportRoot(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
}

private func legacyEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
    encoder.nonConformingFloatEncodingStrategy = .throw
    return encoder
}

private func legacyMediaDTO(
    id: VertexID,
    name: String,
    fileSize: Int64,
    modificationDate: Date,
    fingerprint: String?,
    bookmarkData: Data?,
    embeddedPath: String?,
    availability: MediaAvailabilityStatus
) -> LegacyMediaReferenceDTO {
    LegacyMediaReferenceDTO(
        id: id,
        displayName: name,
        originalFilename: name,
        fileSize: fileSize,
        modificationDate: modificationDate,
        contentFingerprint: fingerprint,
        locator: LegacyMediaLocatorDTO(
            relativeHint: name,
            bookmarkData: bookmarkData,
            embeddedPath: embeddedPath
        ),
        kind: .video,
        availabilityStatus: availability
    )
}

private func makeLegacyImportFixture(at root: URL) throws -> LegacyImportFixture {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let sourceURL = root.appendingPathComponent("Legacy Source").appendingPathExtension("aeproject")
    let journalDirectory = sourceURL.appendingPathComponent("journal", isDirectory: true)
    let autosavesDirectory = sourceURL.appendingPathComponent("autosaves", isDirectory: true)
    let mediaDirectory = sourceURL.appendingPathComponent("media", isDirectory: true)
    try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: journalDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: autosavesDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)

    let createdAt = Date(timeIntervalSince1970: 1_650_000_000)
    let modifiedAt = Date(timeIntervalSince1970: 1_650_000_100)
    let embeddedBytes = Data("verified-embedded-media".utf8)
    let embeddedFingerprint = StableProjectSHA256.hexDigest(embeddedBytes)

    let external = legacyMediaDTO(
        id: legacyBookmarkMediaID,
        name: "external.mov",
        fileSize: 100,
        modificationDate: modifiedAt,
        fingerprint: nil,
        bookmarkData: Data("valid-bookmark-sidecar".utf8),
        embeddedPath: nil,
        availability: .external
    )
    let missing = legacyMediaDTO(
        id: legacyMissingMediaID,
        name: "missing.mov",
        fileSize: 200,
        modificationDate: modifiedAt,
        fingerprint: nil,
        bookmarkData: Data(),
        embeddedPath: nil,
        availability: .external
    )
    let embedded = legacyMediaDTO(
        id: legacyEmbeddedMediaID,
        name: "embedded clip.mov",
        fileSize: Int64(embeddedBytes.count),
        modificationDate: modifiedAt,
        fingerprint: embeddedFingerprint,
        bookmarkData: nil,
        embeddedPath: "media/embedded-source.mov",
        availability: .embedded
    )

    let legacy = LegacySchema1ProjectDTO(
        schemaVersion: 1,
        minimumReaderVersion: 1,
        projectID: legacyImportProjectID,
        revision: 0,
        metadata: ProjectMetadata(
            name: "Legacy Original",
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            createdByAppVersion: "5.0.0-draft",
            lastSavedByAppVersion: "5.0.0-draft"
        ),
        settings: ProjectSettings(),
        mediaRegistry: [external, missing, embedded],
        compositionRegistry: [
            LegacyCompositionPlaceholderDTO(id: legacyImportCompositionID, name: "Main")
        ],
        activeCompositionID: legacyImportCompositionID,
        selectedMediaID: legacyBookmarkMediaID,
        renderSettings: ProjectRenderSettings(),
        legacyRenderSettings: nil,
        appliedCommandIDs: [
            VertexID(rawValue: "57000000-0000-0000-0000-000000000099")
        ]
    )
    let projectData = try legacyEncoder().encode(legacy)
    try projectData.write(to: sourceURL.appendingPathComponent("project.json"))

    let manifest = LegacyManifestDTO(
        schemaVersion: 1,
        minimumReaderVersion: 1,
        projectID: legacyImportProjectID,
        createdByAppVersion: legacy.metadata.createdByAppVersion,
        lastSavedByAppVersion: legacy.metadata.lastSavedByAppVersion,
        projectRevision: 0,
        projectChecksum: DeterministicProjectCodec().checksum(data: projectData),
        committedJournalSequence: 0,
        lastSuccessfulSave: modifiedAt,
        integrityStatus: .valid
    )
    try legacyEncoder().encode(manifest).write(
        to: sourceURL.appendingPathComponent("manifest.json")
    )

    let rename = ProjectCommandRecord(
        commandID: VertexID(rawValue: "57000000-0000-0000-0000-000000000030"),
        projectID: legacyImportProjectID,
        baseRevision: 0,
        timestamp: Date(timeIntervalSince1970: 1_650_000_200),
        mergeKey: nil,
        forwardOperation: .renameProject(before: "Legacy Original", after: "Legacy Replayed"),
        inverseOperation: .renameProject(before: "Legacy Replayed", after: "Legacy Original")
    )

    let discardedHistory: [String: Any] = [
        "undo": [["discarded": true]],
        "redo": [["discarded": true]]
    ]
    try JSONSerialization.data(
        withJSONObject: discardedHistory,
        options: [.sortedKeys]
    ).write(to: sourceURL.appendingPathComponent("history.json"))

    try embeddedBytes.write(
        to: mediaDirectory.appendingPathComponent("embedded-source.mov")
    )
    try Data("mutable-current".utf8).write(
        to: autosavesDirectory.appendingPathComponent("snapshot-current.json")
    )
    try Data("mutable-previous".utf8).write(
        to: autosavesDirectory.appendingPathComponent("snapshot-previous.json")
    )
    try projectData.write(
        to: sourceURL.appendingPathComponent("project.json.backup")
    )
    try ProjectJournalCodec().encodeLine(
        ProjectJournalRecord(sequence: 1, command: rename)
    ).write(
        to: journalDirectory.appendingPathComponent("operations.log")
    )

    return LegacyImportFixture(
        sourceURL: sourceURL,
        embeddedBytes: embeddedBytes,
        originalCreatedAt: createdAt,
        originalModifiedAt: modifiedAt
    )
}

@Test("Legacy import preserves source bytes IDs timestamps and deterministic canonical output")
func legacyImportIsNonDestructiveAndDeterministic() throws {
    let root = legacyImportRoot("LegacyImport")
    defer { try? FileManager.default.removeItem(at: root) }
    let fixture = try makeLegacyImportFixture(at: root)
    let destinationA = root.appendingPathComponent("Converted A").appendingPathExtension("vertexproject")
    let destinationB = root.appendingPathComponent("Converted B").appendingPathExtension("vertexproject")
    let digestBefore = try LegacySourceTreeDigest().digest(of: fixture.sourceURL)

    let importer = LegacyProjectImporter()
    let inspection = try importer.inspect(sourceURL: fixture.sourceURL)
    let resultA = try importer.convert(sourceURL: fixture.sourceURL, destinationURL: destinationA)
    let digestAfterA = try LegacySourceTreeDigest().digest(of: fixture.sourceURL)
    let resultB = try importer.convert(sourceURL: fixture.sourceURL, destinationURL: destinationB)
    let digestAfterB = try LegacySourceTreeDigest().digest(of: fixture.sourceURL)

    #expect(digestBefore == digestAfterA)
    #expect(digestBefore == digestAfterB)
    #expect(inspection.sourceDigest == digestBefore)
    #expect(resultA.inspection.sourceDigest == digestBefore)
    #expect(resultA.snapshot.document.projectID == legacyImportProjectID)
    #expect(resultA.snapshot.document.compositionRegistry.first?.id == legacyImportCompositionID)
    #expect(Set(resultA.snapshot.document.mediaRegistry.map(\.id)) == Set([
        legacyBookmarkMediaID, legacyMissingMediaID, legacyEmbeddedMediaID
    ]))
    #expect(resultA.snapshot.document.metadata.createdAt == fixture.originalCreatedAt)
    #expect(resultA.snapshot.document.metadata.name == "Legacy Replayed")
    #expect(resultA.snapshot.document.revision == 1)
    #expect(resultA.snapshot.projectData == resultB.snapshot.projectData)

    #expect(resultA.inspection.compositionCount == 1)
    #expect(resultA.inspection.layerCount == 1)
    #expect(resultA.inspection.mediaCount == 3)
    #expect(resultA.inspection.embeddedMediaEligibleCount == 1)
    #expect(resultA.inspection.bookmarkSuccessCount == 1)
    #expect(resultA.inspection.bookmarkFailureCount == 1)
    #expect(resultA.inspection.discardedUndoCount == 1)
    #expect(resultA.inspection.discardedRedoCount == 1)
    #expect(resultA.inspection.discardedAutosaveCount == 2)
    #expect(resultA.inspection.validJournalRecordCount == 1)
    #expect(resultA.inspection.ignoredJournalRecordCount == 0)

    let migratedLayer = try #require(resultA.snapshot.document.layerRegistry.first)
    #expect(migratedLayer.compositionID == legacyImportCompositionID)
    #expect(migratedLayer.source == .media(mediaID: legacyBookmarkMediaID, sourceStartTime: .zero))

    let bookmark = try BookmarkSidecarStore().read(mediaID: legacyBookmarkMediaID, in: destinationA)
    #expect(bookmark == Data("valid-bookmark-sidecar".utf8))
    let missingBookmark = try BookmarkSidecarStore().read(mediaID: legacyMissingMediaID, in: destinationA)
    #expect(missingBookmark == nil)

    let missingReference = try #require(resultA.snapshot.document.mediaRegistry.first {
        $0.id == legacyMissingMediaID
    })
    #expect(missingReference.availabilityStatus == .missing)

    let embeddedReference = try #require(resultA.snapshot.document.mediaRegistry.first {
        $0.id == legacyEmbeddedMediaID
    })
    let embeddedURLOptional = try EmbeddedMediaStore().resolve(
        reference: embeddedReference,
        packageURL: destinationA
    )
    let embeddedURL = try #require(embeddedURLOptional)
    #expect(try Data(contentsOf: embeddedURL) == fixture.embeddedBytes)

    let canonicalJSON = String(decoding: resultA.snapshot.projectData, as: UTF8.self)
    #expect(!canonicalJSON.contains("bookmarkData"))
    #expect(!canonicalJSON.contains("appliedCommandIDs"))
    #expect(!canonicalJSON.contains("legacyRenderSettings"))

    let canonicalEntries = try FileManager.default.contentsOfDirectory(atPath: destinationA.path)
    for forbidden in ["history.json", "project.json.backup", "journal", "autosaves", "proxies", "thumbnails", "recovery"] {
        #expect(!canonicalEntries.contains(forbidden))
    }
}

@Test("Legacy inspection and failed conversion leave no destination or staging package")
func legacyImportFailureCleansTemporaryDestination() throws {
    let root = legacyImportRoot("LegacyFailure")
    defer { try? FileManager.default.removeItem(at: root) }
    let fixture = try makeLegacyImportFixture(at: root)
    let projectURL = fixture.sourceURL.appendingPathComponent("project.json")
    try Data("corrupt-project".utf8).write(to: projectURL)

    let destination = root.appendingPathComponent("Failed").appendingPathExtension("vertexproject")
    #expect(throws: ProjectPersistenceError.self) {
        try LegacyProjectImporter().convert(
            sourceURL: fixture.sourceURL,
            destinationURL: destination
        )
    }

    #expect(!FileManager.default.fileExists(atPath: destination.path))
    let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
    #expect(!names.contains { $0.contains("Failed") && $0.contains("importing") })
}
