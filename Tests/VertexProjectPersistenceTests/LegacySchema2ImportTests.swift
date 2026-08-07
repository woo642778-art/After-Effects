import Foundation
import Testing
import VertexCore
import VertexProject
@testable import VertexProjectPersistence

private struct DraftSchema2Document: Codable {
    var schemaVersion: Int
    var minimumReaderVersion: Int
    var projectID: VertexID
    var revision: UInt64
    var metadata: ProjectMetadata
    var settings: ProjectSettings
    var mediaRegistry: [MediaReference]
    var compositionRegistry: [ProjectComposition]
    var layerRegistry: [ProjectLayer]
    var activeCompositionID: VertexID?
    var selectedLayerID: VertexID?
    var selectedMediaID: VertexID?
    var legacyRenderSettings: ProjectRenderSettings?
    var appliedCommandIDs: [VertexID]
}

private struct DraftSchema2Manifest: Codable {
    var schemaVersion: Int
    var minimumReaderVersion: Int
    var projectID: VertexID
    var createdByAppVersion: String
    var lastSavedByAppVersion: String
    var projectRevision: UInt64
    var projectChecksum: String
    var committedJournalSequence: UInt64
    var lastSuccessfulSave: Date
    var integrityStatus: ProjectIntegrityStatus
}

private func legacySchema2Encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
    encoder.nonConformingFloatEncodingStrategy = .throw
    return encoder
}

@Test("Pre-correction schema 2 import preserves composition layer and media identities")
func legacySchema2ImportPreservesCanonicalProductData() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("LegacySchema2-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let projectID = VertexID(rawValue: "63000000-0000-0000-0000-000000000001")
    let compositionID = VertexID(rawValue: "63000000-0000-0000-0000-000000000010")
    let layerID = VertexID(rawValue: "63000000-0000-0000-0000-000000000020")
    let mediaID = VertexID(rawValue: "63000000-0000-0000-0000-000000000030")
    let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
    let media = MediaReference(
        id: mediaID,
        displayName: "legacy.mov",
        originalFilename: "legacy.mov",
        fileSize: 10,
        modificationDate: timestamp,
        contentFingerprint: nil,
        locator: MediaLocator(relativeHint: "legacy.mov"),
        kind: .video,
        availabilityStatus: .external
    )
    let layer = ProjectLayer(
        id: layerID,
        compositionID: compositionID,
        name: "Legacy Layer",
        source: .media(mediaID: mediaID, sourceStartTime: .zero),
        timing: LayerTiming(
            startTime: .zero,
            inPoint: .zero,
            outPoint: RationalTime(value: 5, timescale: 1)
        )
    )
    let composition = ProjectComposition(
        id: compositionID,
        name: "Legacy Composition",
        width: 1280,
        height: 720,
        duration: RationalTime(value: 5, timescale: 1),
        frameRate: RationalTime(value: 30, timescale: 1),
        color: .rec709SDR(alphaMode: .straight),
        layerIDs: [layerID]
    )
    let draft = DraftSchema2Document(
        schemaVersion: 2,
        minimumReaderVersion: 2,
        projectID: projectID,
        revision: 9,
        metadata: ProjectMetadata(
            name: "Legacy Phase 6",
            createdAt: timestamp,
            modifiedAt: timestamp,
            createdByAppVersion: "6.0.0-draft",
            lastSavedByAppVersion: "6.0.0-draft"
        ),
        settings: ProjectSettings(),
        mediaRegistry: [media],
        compositionRegistry: [composition],
        layerRegistry: [layer],
        activeCompositionID: compositionID,
        selectedLayerID: layerID,
        selectedMediaID: mediaID,
        legacyRenderSettings: ProjectRenderSettings(exposure: 2),
        appliedCommandIDs: [VertexID(rawValue: "63000000-0000-0000-0000-000000000099")]
    )

    var projectObject = try #require(
        try JSONSerialization.jsonObject(with: legacySchema2Encoder().encode(draft)) as? [String: Any]
    )
    var mediaObjects = try #require(projectObject["mediaRegistry"] as? [[String: Any]])
    var locator = try #require(mediaObjects[0]["locator"] as? [String: Any])
    locator["bookmarkData"] = Data("schema2-bookmark".utf8).base64EncodedString()
    mediaObjects[0]["locator"] = locator
    projectObject["mediaRegistry"] = mediaObjects
    let projectData = try JSONSerialization.data(
        withJSONObject: projectObject,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )

    let source = root.appendingPathComponent("Legacy Phase 6").appendingPathExtension("aeproject")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try projectData.write(to: source.appendingPathComponent("project.json"))
    let manifest = DraftSchema2Manifest(
        schemaVersion: 2,
        minimumReaderVersion: 2,
        projectID: projectID,
        createdByAppVersion: "6.0.0-draft",
        lastSavedByAppVersion: "6.0.0-draft",
        projectRevision: 9,
        projectChecksum: StableProjectSHA256.hexDigest(projectData),
        committedJournalSequence: 0,
        lastSuccessfulSave: timestamp,
        integrityStatus: .valid
    )
    try legacySchema2Encoder().encode(manifest).write(
        to: source.appendingPathComponent("manifest.json")
    )

    let destination = root.appendingPathComponent("Converted").appendingPathExtension("vertexproject")
    let result = try LegacyProjectImporter().convert(
        sourceURL: source,
        destinationURL: destination
    )

    #expect(result.snapshot.document.projectID == projectID)
    #expect(result.snapshot.document.revision == 9)
    #expect(result.snapshot.document.compositionRegistry.map(\.id) == [compositionID])
    #expect(result.snapshot.document.layerRegistry.map(\.id) == [layerID])
    #expect(result.snapshot.document.mediaRegistry.map(\.id) == [mediaID])
    #expect(result.snapshot.document.activeCompositionID == compositionID)
    #expect(result.snapshot.document.selectedLayerID == layerID)
    #expect(result.inspection.compositionCount == 1)
    #expect(result.inspection.layerCount == 1)
    #expect(try BookmarkSidecarStore().read(mediaID: mediaID, in: destination) == Data("schema2-bookmark".utf8))

    let json = try #require(String(data: result.snapshot.projectData, encoding: .utf8))
    for forbidden in ["bookmarkData", "appliedCommandIDs", "legacyRenderSettings", "renderSettings"] {
        #expect(!json.contains(forbidden))
    }
}
