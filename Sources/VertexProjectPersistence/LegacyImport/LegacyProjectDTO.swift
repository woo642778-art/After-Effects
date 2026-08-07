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
        guard schemaVersion == ProjectDocument.currentSchemaVersion else {
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

    package static func decode(_ data: Data) throws -> LegacyProjectDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        do {
            return try decoder.decode(LegacyProjectDTO.self, from: data)
        } catch {
            throw ProjectPersistenceError.legacyImportIncomplete(
                stage: "legacy project decode: \(error.localizedDescription)"
            )
        }
    }
}
