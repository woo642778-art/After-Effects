import Foundation
import VertexCore

struct Schema4ProjectDocument: Codable, Equatable, Sendable {
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

enum Schema4ProjectCodec {
    static func decode(_ data: Data) throws -> Schema4ProjectDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        do {
            let value = try decoder.decode(Schema4ProjectDocument.self, from: data)
            guard value.schemaVersion == 4 else {
                throw ProjectError.migrationFailure("Schema 4 compatibility decoder received schema \(value.schemaVersion).")
            }
            guard value.minimumReaderVersion <= 4 else {
                throw ProjectError.migrationFailure("Schema 4 minimum reader version is invalid.")
            }
            return value
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.decodingFailure("Schema 4 project could not be decoded: \(error.localizedDescription)")
        }
    }

    static func encode(_ document: Schema4ProjectDocument) throws -> Data {
        guard document.schemaVersion == 4 else {
            throw ProjectError.migrationFailure("Schema 4 compatibility encoder requires schema 4.")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        encoder.nonConformingFloatEncodingStrategy = .throw
        do {
            return try encoder.encode(document)
        } catch {
            throw ProjectError.deterministicEncodingFailure("Schema 4 project could not be encoded: \(error.localizedDescription)")
        }
    }
}

public struct Schema4To5Migrator: ProjectMigrator {
    public let sourceVersion = 4
    public let destinationVersion = 5

    public init() {}

    public func migrate(_ data: Data) throws -> ProjectMigrationStepResult {
        let legacy = try Schema4ProjectCodec.decode(data)
        var metadata = legacy.metadata
        metadata.lastSavedByAppVersion = "9.0.0"
        var layers = legacy.layerRegistry
        for index in layers.indices {
            layers[index].timing.sourceOffset = .zero
            layers[index].parentLayerID = nil
        }
        var compositions = legacy.compositionRegistry
        for index in compositions.indices {
            compositions[index].workArea = nil
            compositions[index].markers = []
        }

        let migrated = try ProjectDocument(
            schemaVersion: 5,
            minimumReaderVersion: 5,
            projectID: legacy.projectID,
            revision: legacy.revision,
            metadata: metadata,
            settings: legacy.settings,
            mediaRegistry: legacy.mediaRegistry,
            compositionRegistry: compositions,
            layerRegistry: layers,
            aiAssetRegistry: legacy.aiAssetRegistry,
            activeCompositionID: legacy.activeCompositionID,
            selectedLayerID: legacy.selectedLayerID,
            selectedMediaID: legacy.selectedMediaID
        ).validated()

        return ProjectMigrationStepResult(
            data: try DeterministicProjectCodec().encode(migrated),
            report: ProjectMigrationReport(
                sourceVersion: 4,
                destinationVersion: 5,
                messages: [
                    "Added exact source offsets, parent links, work areas, and markers with deterministic empty defaults.",
                    "Preserved schema 4 media, layers, masks, mattes, animation channels, AI assets, selection, revision, and composition order."
                ]
            )
        )
    }
}
