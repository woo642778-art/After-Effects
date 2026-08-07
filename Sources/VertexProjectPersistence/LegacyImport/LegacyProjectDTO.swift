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

// Phase 5 and early compatibility packages stored placeholder compositions and
// a top-level Render Lab state. This DTO remains confined to LegacyImport.
package struct LegacyProjectDTO: Codable, Equatable, Sendable {
    package var schemaVersion: Int
    package var minimumReaderVersion: Int
    package var projectID: VertexID
    package var revision: UInt64
    package var metadata: ProjectMetadata
    package var settings: ProjectSettings
    package var mediaRegistry: [LegacyMediaReferenceDTO]
    package var compositionRegistry: [ProjectCompositionPlaceholder]
    package var activeCompositionID: VertexID?
    package var selectedMediaID: VertexID?
    package var renderSettings: ProjectRenderSettings
    package var legacyRenderSettings: ProjectRenderSettings?
    package var appliedCommandIDs: [VertexID]?

    package func canonicalDocument() throws -> ProjectDocument {
        guard (1...ProjectDocument.currentSchemaVersion).contains(schemaVersion) else {
            throw ProjectPersistenceError.legacyImportIncomplete(
                stage: "unsupported legacy schema \(schemaVersion)"
            )
        }
        return try ProjectDocument(
            schemaVersion: ProjectDocument.currentSchemaVersion,
            minimumReaderVersion: min(minimumReaderVersion, ProjectDocument.currentSchemaVersion),
            projectID: projectID,
            revision: revision,
            metadata: metadata,
            settings: settings,
            mediaRegistry: mediaRegistry.map { $0.canonicalReference() },
            compositionRegistry: compositionRegistry,
            activeCompositionID: activeCompositionID,
            selectedMediaID: selectedMediaID,
            renderSettings: legacyRenderSettings ?? renderSettings
        ).validated()
    }

    package var bookmarkPayloads: [VertexID: Data] {
        Dictionary(uniqueKeysWithValues: mediaRegistry.compactMap { reference in
            guard let data = reference.locator.bookmarkData else { return nil }
            return (reference.id, data)
        })
    }
}

// The pre-correction Phase 6 draft stored the real composition/layer graph,
// navigation IDs, legacyRenderSettings and appliedCommandIDs. renderSettings
// was computed and therefore absent from project.json.
package struct LegacySchema2ProjectDTO: Codable, Equatable, Sendable {
    package var schemaVersion: Int
    package var minimumReaderVersion: Int
    package var projectID: VertexID
    package var revision: UInt64
    package var metadata: ProjectMetadata
    package var settings: ProjectSettings
    package var mediaRegistry: [LegacyMediaReferenceDTO]
    package var compositionRegistry: [ProjectComposition]
    package var layerRegistry: [ProjectLayer]
    package var activeCompositionID: VertexID?
    package var selectedLayerID: VertexID?
    package var selectedMediaID: VertexID?
    package var legacyRenderSettings: ProjectRenderSettings?
    package var appliedCommandIDs: [VertexID]?

    package func canonicalDocument() throws -> ProjectDocument {
        guard schemaVersion == 2 else {
            throw ProjectPersistenceError.legacyImportIncomplete(
                stage: "unsupported pre-correction Phase 6 schema \(schemaVersion)"
            )
        }
        let active = activeCompositionID.flatMap { id in
            compositionRegistry.first { $0.id == id }
        } ?? compositionRegistry.first
        let renderState = legacyRenderSettings ?? ProjectRenderSettings(
            outputWidth: active?.width ?? 1080,
            outputHeight: active?.height ?? 1080
        )
        return try ProjectDocument(
            schemaVersion: ProjectDocument.currentSchemaVersion,
            minimumReaderVersion: min(minimumReaderVersion, ProjectDocument.currentSchemaVersion),
            projectID: projectID,
            revision: revision,
            metadata: metadata,
            settings: settings,
            mediaRegistry: mediaRegistry.map { $0.canonicalReference() },
            compositionRegistry: compositionRegistry,
            layerRegistry: layerRegistry,
            activeCompositionID: activeCompositionID,
            selectedLayerID: selectedLayerID,
            selectedMediaID: selectedMediaID,
            renderSettings: renderState
        ).normalized().validated()
    }

    package var bookmarkPayloads: [VertexID: Data] {
        Dictionary(uniqueKeysWithValues: mediaRegistry.compactMap { reference in
            guard let data = reference.locator.bookmarkData else { return nil }
            return (reference.id, data)
        })
    }
}

package struct DecodedLegacyProject: Sendable {
    package let schemaVersion: Int
    package let minimumReaderVersion: Int
    package let projectID: VertexID
    package let revision: UInt64
    package let mediaRegistry: [LegacyMediaReferenceDTO]
    package let bookmarkPayloads: [VertexID: Data]
    package let document: ProjectDocument

    package static func decode(_ data: Data) throws -> DecodedLegacyProject {
        let decoder = makeDecoder()
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                throw ProjectPersistenceError.legacyImportIncomplete(
                    stage: "legacy project root is not an object"
                )
            }

            if dictionary["layerRegistry"] != nil {
                let dto = try decoder.decode(LegacySchema2ProjectDTO.self, from: data)
                return DecodedLegacyProject(
                    schemaVersion: dto.schemaVersion,
                    minimumReaderVersion: dto.minimumReaderVersion,
                    projectID: dto.projectID,
                    revision: dto.revision,
                    mediaRegistry: dto.mediaRegistry,
                    bookmarkPayloads: dto.bookmarkPayloads,
                    document: try dto.canonicalDocument()
                )
            }

            let dto = try decoder.decode(LegacyProjectDTO.self, from: data)
            return DecodedLegacyProject(
                schemaVersion: dto.schemaVersion,
                minimumReaderVersion: dto.minimumReaderVersion,
                projectID: dto.projectID,
                revision: dto.revision,
                mediaRegistry: dto.mediaRegistry,
                bookmarkPayloads: dto.bookmarkPayloads,
                document: try dto.canonicalDocument()
            )
        } catch let error as ProjectPersistenceError {
            throw error
        } catch {
            throw ProjectPersistenceError.legacyImportIncomplete(
                stage: "legacy project decode: \(error.localizedDescription)"
            )
        }
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        return decoder
    }
}
