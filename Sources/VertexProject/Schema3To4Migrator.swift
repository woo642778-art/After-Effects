import Foundation
import VertexCore

/// Exact compatibility shape for canonical Phase 7 / schema-3 project JSON.
/// `ProjectLayer` provides decode defaults for the Phase 8 fields so legacy
/// schema-3 data can be decoded before the deterministic 3 -> 4 migration.
struct Schema3ProjectDocument: Codable, Equatable, Sendable {
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

enum Schema3ProjectCodec {
    static func decode(_ data: Data) throws -> Schema3ProjectDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        do {
            let value = try decoder.decode(Schema3ProjectDocument.self, from: data)
            guard value.schemaVersion == 3 else {
                throw ProjectError.migrationFailure("Schema 3 compatibility decoder received schema \(value.schemaVersion).")
            }
            guard value.minimumReaderVersion <= 3 else {
                throw ProjectError.migrationFailure("Schema 3 minimum reader version is invalid.")
            }
            return value
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.decodingFailure("Schema 3 project could not be decoded: \(error.localizedDescription)")
        }
    }

    static func encode(_ document: Schema3ProjectDocument) throws -> Data {
        guard document.schemaVersion == 3 else {
            throw ProjectError.migrationFailure("Schema 3 compatibility encoder requires schema 3.")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        encoder.nonConformingFloatEncodingStrategy = .throw
        do {
            return try encoder.encode(document)
        } catch {
            throw ProjectError.deterministicEncodingFailure("Schema 3 project could not be encoded: \(error.localizedDescription)")
        }
    }
}

public struct Schema3To4Migrator: ProjectMigrator {
    public let sourceVersion = 3
    public let destinationVersion = 4

    public init() {}

    public func migrate(_ data: Data) throws -> ProjectMigrationStepResult {
        let legacy = try Schema3ProjectCodec.decode(data)
        var metadata = legacy.metadata
        metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion
        var layers = legacy.layerRegistry
        for index in layers.indices {
            layers[index].animationChannels = []
            layers[index].masks = []
            layers[index].trackMatte = nil
        }

        let migrated = try ProjectDocument(
            schemaVersion: 4,
            minimumReaderVersion: 4,
            projectID: legacy.projectID,
            revision: legacy.revision,
            metadata: metadata,
            settings: legacy.settings,
            mediaRegistry: legacy.mediaRegistry,
            compositionRegistry: legacy.compositionRegistry,
            layerRegistry: layers,
            aiAssetRegistry: legacy.aiAssetRegistry,
            activeCompositionID: legacy.activeCompositionID,
            selectedLayerID: legacy.selectedLayerID,
            selectedMediaID: legacy.selectedMediaID
        ).validated()

        return ProjectMigrationStepResult(
            data: try DeterministicProjectCodec().encode(migrated),
            report: ProjectMigrationReport(
                sourceVersion: 3,
                destinationVersion: 4,
                messages: [
                    "Added empty exact-time animation channels, vector masks, and track-matte state to every existing layer.",
                    "Preserved schema 3 media, compositions, layers, AI assets, selections, revision, and timing semantics."
                ]
            )
        )
    }
}
