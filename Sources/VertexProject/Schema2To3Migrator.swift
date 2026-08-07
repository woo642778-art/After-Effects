import Foundation
import VertexCore

/// Exact compatibility shape for canonical Phase 6 / schema-2 project JSON.
/// It intentionally contains no AI runtime state or schema-3-only fields.
struct Schema2ProjectDocument: Codable, Equatable, Sendable {
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
}

enum Schema2ProjectCodec {
    static func decode(_ data: Data) throws -> Schema2ProjectDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        do {
            let value = try decoder.decode(Schema2ProjectDocument.self, from: data)
            guard value.schemaVersion == 2 else {
                throw ProjectError.migrationFailure("Schema 2 compatibility decoder received schema \(value.schemaVersion).")
            }
            guard value.minimumReaderVersion <= 2 else {
                throw ProjectError.migrationFailure("Schema 2 minimum reader version is invalid.")
            }
            return value
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.decodingFailure("Schema 2 project could not be decoded: \(error.localizedDescription)")
        }
    }

    static func encode(_ document: Schema2ProjectDocument) throws -> Data {
        guard document.schemaVersion == 2 else {
            throw ProjectError.migrationFailure("Schema 2 compatibility encoder requires schema 2.")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        encoder.nonConformingFloatEncodingStrategy = .throw
        do {
            return try encoder.encode(document)
        } catch {
            throw ProjectError.deterministicEncodingFailure("Schema 2 project could not be encoded: \(error.localizedDescription)")
        }
    }
}

public struct Schema2To3Migrator: ProjectMigrator {
    public let sourceVersion = 2
    public let destinationVersion = 3

    public init() {}

    public func migrate(_ data: Data) throws -> ProjectMigrationStepResult {
        let legacy = try Schema2ProjectCodec.decode(data)
        var metadata = legacy.metadata
        metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion

        let migrated = try ProjectDocument(
            schemaVersion: 3,
            minimumReaderVersion: 3,
            projectID: legacy.projectID,
            revision: legacy.revision,
            metadata: metadata,
            settings: legacy.settings,
            mediaRegistry: legacy.mediaRegistry,
            compositionRegistry: legacy.compositionRegistry,
            layerRegistry: legacy.layerRegistry,
            aiAssetRegistry: [],
            activeCompositionID: legacy.activeCompositionID,
            selectedLayerID: legacy.selectedLayerID,
            selectedMediaID: legacy.selectedMediaID
        ).validated()

        return ProjectMigrationStepResult(
            data: try DeterministicProjectCodec().encode(migrated),
            report: ProjectMigrationReport(
                sourceVersion: 2,
                destinationVersion: 3,
                messages: [
                    "Added an empty AI asset registry.",
                    "Preserved all schema 2 media, composition, layer, timing, and render semantics."
                ]
            )
        )
    }
}
