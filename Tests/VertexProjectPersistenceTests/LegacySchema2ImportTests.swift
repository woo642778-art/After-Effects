import Foundation
import Testing
import VertexCore
import VertexProject
@testable import VertexProjectPersistence

private struct OldPhase6ProjectDTO: Codable {
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

private struct OldPhase6ManifestDTO: Codable {
    var schemaVersion: Int
    var minimumReaderVersion: Int
    var projectID: VertexID
    var createdByAppVersion: String
    var lastSavedByAppVersion: String
    var projectRevision: UInt64
    var projectChecksum: String
    var committedJournalSequence: UInt64
    var lastSuccessfulSave: Date
    var integrityStatus: String
}

private func legacySchema2Encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
    encoder.nonConformingFloatEncodingStrategy = .throw
    return encoder
}

@Test("Pre-correction Phase 6 schema 2 package imports layers and navigation without mutating source")
func preCorrectionSchema2ImportPreservesLayerGraph() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("LegacySchema2-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let source = root.appendingPathComponent("Phase6 Draft").appendingPathExtension("aeproject")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

    let projectID = VertexID(rawValue: "68000000-0000-0000-0000-000000000001")
    let compositionID = VertexID(rawValue: "68000000-0000-0000-0000-000000000010")
    let layerID = VertexID(rawValue: "68000000-0000-0000-0000-000000000020")
    let commandID = VertexID(rawValue: "68000000-0000-0000-0000-000000000030")
    let timestamp = Date(timeIntervalSince1970: 1_720_000_000)
    let settings = ProjectSettings()
    let layer = ProjectLayer(id: layerID, compositionID: compositionID, name: "Legacy Null", source: .null, enabled: true, locked: false, solo: false, timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 8, timescale: 1)), transform: .identity, blendMode: .normal, operations: [])
    let composition = ProjectComposition(id: compositionID, name: "Legacy Main", width: 1920, height: 1080, duration: RationalTime(value: 8, timescale: 1), frameRate: RationalTime(value: 24, timescale: 1), color: settings.color, backgroundColor: ProjectRGBAColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1), layerIDs: [layerID])
    let oldProject = OldPhase6ProjectDTO(schemaVersion: 2, minimumReaderVersion: 2, projectID: projectID, revision: 7, metadata: ProjectMetadata(name: "Phase 6 Draft", createdAt: timestamp, modifiedAt: timestamp, createdByAppVersion: "6.0.0", lastSavedByAppVersion: "6.0.0"), settings: settings, mediaRegistry: [], compositionRegistry: [composition], layerRegistry: [layer], activeCompositionID: compositionID, selectedLayerID: layerID, selectedMediaID: nil, legacyRenderSettings: nil, appliedCommandIDs: [commandID])
    let projectData = try legacySchema2Encoder().encode(oldProject)
    let checksum = DeterministicProjectCodec().checksum(data: projectData)
    let oldManifest = OldPhase6ManifestDTO(schemaVersion: 2, minimumReaderVersion: 2, projectID: projectID, createdByAppVersion: "6.0.0", lastSavedByAppVersion: "6.0.0", projectRevision: 7, projectChecksum: checksum, committedJournalSequence: 0, lastSuccessfulSave: timestamp, integrityStatus: "valid")
    try projectData.write(to: source.appendingPathComponent("project.json"))
    try legacySchema2Encoder().encode(oldManifest).write(to: source.appendingPathComponent("manifest.json"))

    let digestBefore = try LegacySourceTreeDigest().digest(of: source)
    let destination = root.appendingPathComponent("Converted").appendingPathExtension("vertexproject")
    let importer = LegacyProjectImporter()
    let inspection = try importer.inspect(sourceURL: source)
    let result = try importer.convert(sourceURL: source, destinationURL: destination)
    let digestAfter = try LegacySourceTreeDigest().digest(of: source)

    #expect(digestBefore == digestAfter)
    #expect(inspection.compositionCount == 1)
    #expect(inspection.layerCount == 1)
    #expect(result.snapshot.document.projectID == projectID)
    #expect(result.snapshot.document.revision == 7)
    #expect(result.snapshot.document.composition(id: compositionID) == composition)
    #expect(result.snapshot.document.layer(id: layerID) == layer)
    #expect(result.snapshot.document.activeCompositionID == compositionID)
    #expect(result.snapshot.document.selectedLayerID == layerID)
    let json = String(decoding: result.snapshot.projectData, as: UTF8.self)
    #expect(!json.contains("legacyRenderSettings"))
    #expect(!json.contains("appliedCommandIDs"))
}
