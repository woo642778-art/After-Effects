import Foundation
import VertexCore
import VertexProject

package struct LegacyMediaLocatorDTO: Codable, Equatable, Sendable {
    package var relativeHint: String?
    package var bookmarkData: Data?
    package var embeddedPath: String?
}

package struct LegacyMediaReferenceDTO: Codable, Equatable, Sendable {
    package var id: VertexID
    package var displayName: String
    package var originalFilename: String
    package var fileSize: Int64
    package var modificationDate: Date?
    package var contentFingerprint: String?
    package var locator: LegacyMediaLocatorDTO
    package var kind: ProjectMediaKind
    package var availabilityStatus: MediaAvailabilityStatus

    package func canonicalReference() -> MediaReference {
        MediaReference(
            id: id,
            displayName: displayName,
            originalFilename: originalFilename,
            fileSize: fileSize,
            modificationDate: modificationDate,
            contentFingerprint: contentFingerprint,
            locator: MediaLocator(
                relativeHint: locator.relativeHint,
                embeddedPath: locator.embeddedPath
            ),
            kind: kind,
            availabilityStatus: availabilityStatus
        )
    }
}

private struct LegacyCompositionPlaceholderDTO: Codable, Equatable, Sendable {
    var id: VertexID
    var name: String
}

private struct LegacySchema1ProjectDTO: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var minimumReaderVersion: Int
    var projectID: VertexID
    var revision: UInt64
    var metadata: ProjectMetadata
    var settings: ProjectSettings
    var mediaRegistry: [LegacyMediaReferenceDTO]
    var compositionRegistry: [LegacyCompositionPlaceholderDTO]
    var activeCompositionID: VertexID?
    var selectedMediaID: VertexID?
    var renderSettings: ProjectRenderSettings
    var legacyRenderSettings: ProjectRenderSettings?
    var appliedCommandIDs: [VertexID]?
}

private struct LegacySchema2ProjectDTO: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var minimumReaderVersion: Int
    var projectID: VertexID
    var revision: UInt64
    var metadata: ProjectMetadata
    var settings: ProjectSettings
    var mediaRegistry: [LegacyMediaReferenceDTO]
    var compositionRegistry: [ProjectComposition]
    var layerRegistry: [ProjectLayer]
    var activeCompositionID: VertexID?
    var selectedLayerID: VertexID?
    var selectedMediaID: VertexID?
    var legacyRenderSettings: ProjectRenderSettings?
    var appliedCommandIDs: [VertexID]?
}

package enum LegacyProjectDTO: Equatable, Sendable {
    case schema1(LegacySchema1ProjectDTO)
    case schema2(LegacySchema2ProjectDTO)

    package var schemaVersion: Int {
        switch self {
        case .schema1(let value): value.schemaVersion
        case .schema2(let value): value.schemaVersion
        }
    }

    package var minimumReaderVersion: Int {
        switch self {
        case .schema1(let value): value.minimumReaderVersion
        case .schema2(let value): value.minimumReaderVersion
        }
    }

    package var projectID: VertexID {
        switch self {
        case .schema1(let value): value.projectID
        case .schema2(let value): value.projectID
        }
    }

    package var revision: UInt64 {
        switch self {
        case .schema1(let value): value.revision
        case .schema2(let value): value.revision
        }
    }

    package var mediaRegistry: [LegacyMediaReferenceDTO] {
        switch self {
        case .schema1(let value): value.mediaRegistry
        case .schema2(let value): value.mediaRegistry
        }
    }

    package func canonicalDocument() throws -> ProjectDocument {
        switch self {
        case .schema1(let legacy):
            let schema1 = Schema1ProjectDocument(
                schemaVersion: 1,
                minimumReaderVersion: min(legacy.minimumReaderVersion, 1),
                projectID: legacy.projectID,
                revision: legacy.revision,
                metadata: legacy.metadata,
                settings: legacy.settings,
                mediaRegistry: legacy.mediaRegistry.map { $0.canonicalReference() },
                compositionRegistry: legacy.compositionRegistry.map {
                    Schema1CompositionPlaceholder(id: $0.id, name: $0.name)
                },
                activeCompositionID: legacy.activeCompositionID,
                selectedMediaID: legacy.selectedMediaID,
                renderSettings: legacy.legacyRenderSettings ?? legacy.renderSettings
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
            encoder.nonConformingFloatEncodingStrategy = .throw
            let sourceData = try encoder.encode(schema1)
            let migrated = try Schema1To2Migrator().migrate(sourceData)
            return try DeterministicProjectCodec().decode(migrated.data)

        case .schema2(let legacy):
            guard legacy.schemaVersion == 2 else {
                throw ProjectPersistenceError.legacyImportIncomplete(
                    stage: "unsupported legacy schema \(legacy.schemaVersion)"
                )
            }
            return try ProjectDocument(
                schemaVersion: ProjectDocument.currentSchemaVersion,
                minimumReaderVersion: ProjectDocument.currentSchemaVersion,
                projectID: legacy.projectID,
                revision: legacy.revision,
                metadata: legacy.metadata,
                settings: legacy.settings,
                mediaRegistry: legacy.mediaRegistry.map { $0.canonicalReference() },
                compositionRegistry: legacy.compositionRegistry,
                layerRegistry: legacy.layerRegistry,
                activeCompositionID: legacy.activeCompositionID,
                selectedLayerID: legacy.selectedLayerID,
                selectedMediaID: legacy.selectedMediaID
            ).normalized().validated()
        }
    }

    package var bookmarkPayloads: [VertexID: Data] {
        Dictionary(uniqueKeysWithValues: mediaRegistry.compactMap { reference in
            guard let data = reference.locator.bookmarkData else { return nil }
            return (reference.id, data)
        })
    }

    package static func decode(_ data: Data) throws -> LegacyProjectDTO {
        let schemaVersion: Int
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let root = object as? [String: Any],
                  let number = root["schemaVersion"] as? NSNumber else {
                throw ProjectPersistenceError.legacyImportIncomplete(stage: "legacy schema header missing")
            }
            schemaVersion = number.intValue
        } catch let error as ProjectPersistenceError {
            throw error
        } catch {
            throw ProjectPersistenceError.legacyImportIncomplete(
                stage: "legacy schema header: \(error.localizedDescription)"
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        do {
            switch schemaVersion {
            case 1:
                return .schema1(try decoder.decode(LegacySchema1ProjectDTO.self, from: data))
            case 2:
                return .schema2(try decoder.decode(LegacySchema2ProjectDTO.self, from: data))
            default:
                throw ProjectPersistenceError.legacyImportIncomplete(
                    stage: "unsupported legacy schema \(schemaVersion)"
                )
            }
        } catch let error as ProjectPersistenceError {
            throw error
        } catch {
            throw ProjectPersistenceError.legacyImportIncomplete(
                stage: "legacy project decode: \(error.localizedDescription)"
            )
        }
    }
}
