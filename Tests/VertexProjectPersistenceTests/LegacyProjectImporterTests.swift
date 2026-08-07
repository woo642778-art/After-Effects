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

private func legacyProjectData(
    from document: ProjectDocument,
    bookmarkPayloads: [VertexID: Data]
) throws -> Data {
    let canonical = try DeterministicProjectCodec().encode(document)
    let object = try #require(try JSONSerialization.jsonObject(with: canonical) as? [String: Any])
    var changed = object
    var media = try #require(changed["mediaRegistry"] as? [[String: Any]])

    for index in media.indices {
        let rawID = try #require(media[index]["id"] as? String)
        guard let payload = bookmarkPayloads.first(where: { $0.key.rawValue == rawID })?.value else {
            continue
        }
        var locator = (media[index]["locator"] as? [String: Any]) ?? [:]
        locator["bookmarkData"] = payload.base64EncodedString()
        media[index]["locator"] = locator
    }
    changed["mediaRegistry"] = media
    changed["appliedCommandIDs"] = [
        "57000000-0000-0000-0000-000000000099"
    ]

    return try JSONSerialization.data(
        withJSONObject: changed,
        options: [.sortedKeys, .withoutEscapingSlashes]
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

    let external = MediaReference(
        id: legacyBookmarkMediaID,
        displayName: "external.mov",
        originalFilename: "external.mov",
        fileSize: 100,
        modificationDate: modifiedAt,
        contentFingerprint: nil,
        locator: MediaLocator(relativeHint: "external.mov"),
        kind: .video,
        availabilityStatus: .external
    )
    let missing = MediaReference(
        id: legacyMissingMediaID,
        displayName: "missing.mov",
        originalFilename: "missing.mov",
        fileSize: 200,
        modificationDate: modifiedAt,
        contentFingerprint: nil,
        locator: MediaLocator(relativeHint: "missing.mov"),
        kind: .video,
        availabilityStatus: .external
    )
    let embedded = MediaReference(
        id: legacyEmbeddedMediaID,
        displayName: "embedded clip.mov",
        originalFilename: "embedded clip.mov",
        fileSize: Int64(embeddedBytes.count),
        modificationDate: modifiedAt,
        contentFingerprint: embeddedFingerprint,
        locator: MediaLocator(
            relativeHint: "embedded clip.mov",
            embeddedPath: "media/embedded-source.mov"
        ),
        kind: .video,
        availabilityStatus: .embedded
    )

    var document = ProjectDocument(
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
            ProjectCompositionPlaceholder(id: legacyImportCompositionID, name: "Main")
        ],
        activeCompositionID: legacyImportCompositionID,
        selectedMediaID: legacyBookmarkMediaID,
        renderSettings: ProjectRenderSettings()
    )
    document = try document.validated()

    let rename = ProjectCommandRecord(
        commandID: VertexID(rawValue: "57000000-0000-0000-0000-000000000030"),
        projectID: document.projectID,
        baseRevision: 0,
        timestamp: Date(timeIntervalSince1970: 1_650_000_200),
        mergeKey: nil,
        forwardOperation: .renameProject(before: "Legacy Original", after: "Legacy Replayed"),
        inverseOperation: .renameProject(before: "Legacy Replayed", after: "Legacy Original")
    )

    let projectData = try legacyProjectData(
        from: document,
        bookmarkPayloads: [
            legacyBookmarkMediaID: Data("valid-bookmark-sidecar".utf8),
            legacyMissingMediaID: Data()
        ]
    )
    try projectData.write(to: sourceURL.appendingPathComponent("project.json"))

    let manifest = LegacyManifestDTO(
        schemaVersion: document.schemaVersion,
        minimumReaderVersion: document.minimumReaderVersion,
        projectID: document.projectID,
        createdByAppVersion: document.metadata.createdByAppVersion,
        lastSavedByAppVersion: document.metadata.lastSavedByAppVersion,
        projectRevision: document.revision,
        projectChecksum: DeterministicProjectCodec().checksum(data: projectData),
        committedJournalSequence: 0,
        lastSuccessfulSave: modifiedAt,
        integrityStatus: .valid
    )
    try legacyEncoder().encode(manifest).write(
        to: sourceURL.appendingPathComponent("manifest.json")
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
    #expect(resultA.inspection.layerCount == 0)
    #expect(resultA.inspection.mediaCount == 3)
    #expect(resultA.inspection.embeddedMediaEligibleCount == 1)
    #expect(resultA.inspection.bookmarkSuccessCount == 1)
    #expect(resultA.inspection.bookmarkFailureCount == 1)
    #expect(resultA.inspection.discardedUndoCount == 1)
    #expect(resultA.inspection.discardedRedoCount == 1)
    #expect(resultA.inspection.discardedAutosaveCount == 2)
    #expect(resultA.inspection.validJournalRecordCount == 1)
    #expect(resultA.inspection.ignoredJournalRecordCount == 0)

    let bookmark = try BookmarkSidecarStore().read(mediaID: legacyBookmarkMediaID, in: destinationA)
    #expect(bookmark == Data("valid-bookmark-sidecar".utf8))
    let missingBookmark = try BookmarkSidecarStore().read(mediaID: legacyMissingMediaID, in: destinationA)
    #expect(missingBookmark == nil)

    let missing = try #require(resultA.snapshot.document.mediaRegistry.first {
        $0.id == legacyMissingMediaID
    })
    #expect(missing.availabilityStatus == .missing)

    let embedded = try #require(resultA.snapshot.document.mediaRegistry.first {
        $0.id == legacyEmbeddedMediaID
    })
    let embeddedURLOptional = try EmbeddedMediaStore().resolve(
        reference: embedded,
        packageURL: destinationA
    )
    let embeddedURL = try #require(embeddedURLOptional)
    #expect(try Data(contentsOf: embeddedURL) == fixture.embeddedBytes)

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
