import Foundation
import Testing
import VertexCore
import VertexProject
@testable import VertexProjectPersistence

private func temporaryLegacyURL(_ name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("vertex-legacy-schema2-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent(name)
        .appendingPathExtension("aeproject")
}

private func temporaryCanonicalURL(_ name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("vertex-legacy-schema2-output-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent(name)
        .appendingPathExtension(VertexProjectPackageLayout.requiredExtension)
}

private func makeLegacySchema2Package(at root: URL) throws -> (projectID: VertexID, compositionID: VertexID, layerID: VertexID, mediaID: VertexID) {
    let projectID = VertexID(rawValue: "67000000-0000-0000-0000-000000000001")
    let compositionID = VertexID(rawValue: "67000000-0000-0000-0000-000000000002")
    let layerID = VertexID(rawValue: "67000000-0000-0000-0000-000000000003")
    let mediaID = VertexID(rawValue: "67000000-0000-0000-0000-000000000004")
    let timestamp = Date(timeIntervalSince1970: 1_700_000_000.123)
    let duration = RationalTime(value: 10, timescale: 1)

    let media = LegacyMediaReferenceDTO(
        id: mediaID,
        displayName: "legacy.mov",
        originalFilename: "legacy.mov",
        fileSize: 123,
        modificationDate: timestamp,
        contentFingerprint: nil,
        locator: LegacyMediaLocatorDTO(
            relativeHint: "legacy.mov",
            bookmarkData: Data([1, 2, 3, 4]),
            embeddedPath: nil
        ),
        kind: .video,
        availabilityStatus: .external
    )
    let layer = ProjectLayer(
        id: layerID,
        compositionID: compositionID,
        name: "Legacy Layer",
        source: .media(mediaID: mediaID, sourceStartTime: .zero),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: duration),
        transform: LayerTransform(
            positionX: 0.6,
            positionY: 0.4,
            anchorX: 0.5,
            anchorY: 0.5,
            scaleX: 1.25,
            scaleY: 1.25,
            rotationDegrees: 12,
            opacity: 0.8
        ),
        blendMode: .screen,
        operations: [.exposure(stops: 1), .saturation(value: 0.75)]
    )
    let composition = ProjectComposition(
        id: compositionID,
        name: "Legacy Composition",
        width: 1280,
        height: 720,
        duration: duration,
        frameRate: RationalTime(value: 30, timescale: 1),
        color: .rec709SDR(alphaMode: .straight),
        backgroundColor: .transparent,
        layerIDs: [layerID]
    )
    let dto = LegacySchema2ProjectDTO(
        schemaVersion: 2,
        minimumReaderVersion: 2,
        projectID: projectID,
        revision: 42,
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
        appliedCommandIDs: [VertexID(rawValue: "67000000-0000-0000-0000-000000000099")]
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
    encoder.nonConformingFloatEncodingStrategy = .throw
    let projectData = try encoder.encode(dto)
    let manifest = LegacyManifestDTO(
        schemaVersion: 2,
        minimumReaderVersion: 2,
        projectID: projectID,
        createdByAppVersion: "6.0.0-draft",
        lastSavedByAppVersion: "6.0.0-draft",
        projectRevision: 42,
        projectChecksum: StableProjectSHA256.hexDigest(projectData),
        committedJournalSequence: 0,
        lastSuccessfulSave: timestamp,
        integrityStatus: .valid
    )
    let manifestData = try encoder.encode(manifest)

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("journal"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("autosaves"), withIntermediateDirectories: true)
    try projectData.write(to: root.appendingPathComponent("project.json"))
    try manifestData.write(to: root.appendingPathComponent("manifest.json"))
    try Data().write(to: root.appendingPathComponent("journal/operations.log"))
    try Data("{\"undo\":[{}],\"redo\":[{},{}]}".utf8).write(to: root.appendingPathComponent("history.json"))
    try Data("legacy autosave".utf8).write(to: root.appendingPathComponent("autosaves/current.json"))

    return (projectID, compositionID, layerID, mediaID)
}

@Test("Pre-correction schema 2 imports non-destructively into canonical schema 2")
func legacySchema2ImportPreservesLayerModelAndDropsPersistenceState() throws {
    let source = temporaryLegacyURL("Legacy")
    let destination = temporaryCanonicalURL("Converted")
    defer {
        try? FileManager.default.removeItem(at: source.deletingLastPathComponent())
        try? FileManager.default.removeItem(at: destination.deletingLastPathComponent())
    }
    let identities = try makeLegacySchema2Package(at: source)
    let beforeDigest = try LegacySourceTreeDigest().digest(of: source)

    let importer = LegacyProjectImporter()
    let inspection = try importer.inspect(sourceURL: source)
    #expect(inspection.compositionCount == 1)
    #expect(inspection.layerCount == 1)
    #expect(inspection.discardedUndoCount == 1)
    #expect(inspection.discardedRedoCount == 2)
    #expect(inspection.discardedAutosaveCount == 1)

    let result = try importer.convert(sourceURL: source, destinationURL: destination)
    let afterDigest = try LegacySourceTreeDigest().digest(of: source)
    #expect(beforeDigest == afterDigest)
    #expect(result.snapshot.document.projectID == identities.projectID)
    #expect(result.snapshot.document.activeCompositionID == identities.compositionID)
    #expect(result.snapshot.document.selectedLayerID == identities.layerID)
    #expect(result.snapshot.document.selectedMediaID == identities.mediaID)
    #expect(result.snapshot.document.layer(id: identities.layerID)?.blendMode == .screen)
    #expect(result.snapshot.document.layer(id: identities.layerID)?.transform.rotationDegrees == 12)

    let canonicalJSON = String(decoding: result.snapshot.projectData, as: UTF8.self)
    #expect(!canonicalJSON.contains("bookmarkData"))
    #expect(!canonicalJSON.contains("appliedCommandIDs"))
    #expect(!canonicalJSON.contains("legacyRenderSettings"))
    #expect(!canonicalJSON.contains("history"))

    let layout = try VertexProjectPackageLayout(root: destination)
    #expect(FileManager.default.fileExists(atPath: layout.bookmarkURL(mediaID: identities.mediaID.rawValue).path))
    #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("history.json").path))
    #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("journal/operations.log").path))
}
