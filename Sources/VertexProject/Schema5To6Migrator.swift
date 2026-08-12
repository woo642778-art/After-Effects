import Foundation
import VertexCore

struct Schema5ProjectDocument: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var minimumReaderVersion: Int
    var projectID: VertexID
    var revision: UInt64
    var metadata: ProjectMetadata
    var settings: ProjectSettings
    var mediaRegistry: [MediaReference]
    var compositionRegistry: [ProjectComposition]
    var layerRegistry: [ProjectLayer]
    var aiAssetRegistry: [ProjectAIAsset]
    var activeCompositionID: VertexID?
    var selectedLayerID: VertexID?
    var selectedMediaID: VertexID?
}

enum Schema5ProjectCodec {
    static func decode(_ data: Data) throws -> Schema5ProjectDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        do {
            let value = try decoder.decode(Schema5ProjectDocument.self, from: data)
            guard value.schemaVersion == 5 else {
                throw ProjectError.migrationFailure("Schema 5 compatibility decoder received schema \(value.schemaVersion).")
            }
            guard value.minimumReaderVersion <= 5 else {
                throw ProjectError.migrationFailure("Schema 5 minimum reader version is invalid.")
            }
            return value
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.decodingFailure("Schema 5 project could not be decoded: \(error.localizedDescription)")
        }
    }

    static func encode(_ document: Schema5ProjectDocument) throws -> Data {
        guard document.schemaVersion == 5 else {
            throw ProjectError.migrationFailure("Schema 5 compatibility encoder requires schema 5.")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        encoder.nonConformingFloatEncodingStrategy = .throw
        do {
            return try encoder.encode(document)
        } catch {
            throw ProjectError.deterministicEncodingFailure("Schema 5 project could not be encoded: \(error.localizedDescription)")
        }
    }
}

public struct Schema5To6Migrator: ProjectMigrator {
    public let sourceVersion = 5
    public let destinationVersion = 6

    public init() {}

    public func migrate(_ data: Data) throws -> ProjectMigrationStepResult {
        let legacy = try Schema5ProjectCodec.decode(data)
        var metadata = legacy.metadata
        metadata.lastSavedByAppVersion = "18.0.0"
        var compositions = legacy.compositionRegistry
        for index in compositions.indices {
            compositions[index].nodeGraph = nil
        }

        let migrated = try ProjectDocument(
            schemaVersion: 6,
            minimumReaderVersion: 6,
            projectID: legacy.projectID,
            revision: legacy.revision,
            metadata: metadata,
            settings: legacy.settings,
            mediaRegistry: legacy.mediaRegistry,
            compositionRegistry: compositions,
            layerRegistry: legacy.layerRegistry,
            aiAssetRegistry: legacy.aiAssetRegistry,
            activeCompositionID: legacy.activeCompositionID,
            selectedLayerID: legacy.selectedLayerID,
            selectedMediaID: legacy.selectedMediaID
        ).validated()

        return ProjectMigrationStepResult(
            data: try DeterministicProjectCodec().encode(migrated),
            report: ProjectMigrationReport(
                sourceVersion: 5,
                destinationVersion: 6,
                messages: [
                    "Added optional per-composition V18 node compositor graphs with deterministic nil defaults.",
                    "Preserved schema 5 media, layers, effects, masks, mattes, animation, AI assets, timing, selection, and composition order."
                ]
            )
        )
    }
}
