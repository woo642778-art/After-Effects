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

private func encodeLegacyManifest(_ manifest: ProjectManifest) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
    return try encoder.encode(manifest)
}

private func decodeLegacyManifest(_ data: Data) throws -> ProjectManifest {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
    return try decoder.decode(ProjectManifest.self, from: data)
}

private func injectLegacyState(
    projectURL: URL,
    manifestURL: URL,
    bookmarkPayloads: [VertexID: Data]
) throws {
    let projectData = try Data(contentsOf: projectURL)
    let object = try #require(try JSONSerialization.jsonObject(with: projectData) as? [String: Any])
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

    let changedData = try JSONSerialization.data(withJSONObject: changed, options: [.sortedKeys, .withoutEscapingSlashes])
    try changedData.write(to: projectURL)

    var manifest = try decodeLegacyManifest(Data(contentsOf: manifestURL))
    manifest.projectChecksum = DeterministicProjectCodec().checksum(data: changedData)
    try encodeLegacyManifest(manifest).write(to: manifestURL)
}

private func makeLegacyImportFixture(at root: URL) throws -> LegacyImportFixture {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let sourceURL = root.appendingPathComponent("Legacy Source").appendingPathExtension("aeproject")
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
            ProjectComposition(
                id: legacyImportCompositionID,
                name: "Main",
                width: 1080,
                height: 1080,
                duration: RationalTime(value: 10, timescale: 1),
                frameRate: RationalTime(value: 30, timescale: 1),
                color: .rec709SDR(alphaMode: .straight),
                layerIDs: []
            )
        ],
        layerRegistry: [],
        activeCompositionID: legacyImportCompositionID,
        selectedLayerID: nil,
        selectedMediaID: legacyBookmarkMediaID
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
    let history = ProjectHistorySnapshot(undo: [rename], redo: [rename])
    let legacyStore = ProjectPackageStore()
    _ = try legacyStore.create(at: sourceURL, document: document, history: history)
    let layout = try ProjectPackageLayout(root: sourceURL)
    try embeddedBytes.write(to: layout.mediaDirectoryURL.appendingPathComponent("embedded-source.mov"))
    try Data("mutable-current".utf8).write(to: layout.autosaveCurrentURL)
    try Data("mutable-previous".utf8).write(to: layout.autosavePreviousURL)
    try FileManager.default.copyItem(at: layout.projectURL, to: layout.projectBackupURL)
    try ProjectJournalCodec().encodeLine(
        ProjectJournalRecord(sequence: 1, command: rename)
    ).write(to: layout.journalURL)

    try injectLegacyState(
        projectURL: layout.projectURL,
        manifestURL: layout.manifestURL,
        bookmarkPayloads: [
            legacyBookmarkMediaID: Data("valid-bookmark-sidecar".utf8),
            legacyMissingMediaID: Data()
        ]
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
    let layout = try ProjectPackageLayout(root: fixture.sourceURL)
    try Data("corrupt-project".utf8).write(to: layout.projectURL)

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
