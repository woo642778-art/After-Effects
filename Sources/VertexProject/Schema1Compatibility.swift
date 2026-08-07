import Foundation
import VertexCore

package struct Schema1ProjectDocument: Codable, Equatable, Sendable {
    package var schemaVersion: Int
    package var minimumReaderVersion: Int
    package var projectID: VertexID
    package var revision: UInt64
    package var metadata: ProjectMetadata
    package var settings: ProjectSettings
    package var mediaRegistry: [MediaReference]
    package var compositionRegistry: [ProjectCompositionPlaceholder]
    package var activeCompositionID: VertexID?
    package var selectedMediaID: VertexID?
    package var renderSettings: ProjectRenderSettings

    package init(
        schemaVersion: Int,
        minimumReaderVersion: Int,
        projectID: VertexID,
        revision: UInt64,
        metadata: ProjectMetadata,
        settings: ProjectSettings,
        mediaRegistry: [MediaReference],
        compositionRegistry: [ProjectCompositionPlaceholder],
        activeCompositionID: VertexID?,
        selectedMediaID: VertexID?,
        renderSettings: ProjectRenderSettings
    ) {
        self.schemaVersion = schemaVersion
        self.minimumReaderVersion = minimumReaderVersion
        self.projectID = projectID
        self.revision = revision
        self.metadata = metadata
        self.settings = settings
        self.mediaRegistry = mediaRegistry
        self.compositionRegistry = compositionRegistry
        self.activeCompositionID = activeCompositionID
        self.selectedMediaID = selectedMediaID
        self.renderSettings = renderSettings
    }

    package func validated() throws -> Schema1ProjectDocument {
        guard schemaVersion == 1, minimumReaderVersion <= schemaVersion else {
            throw ProjectError.migrationFailure("Schema 1 project compatibility values are invalid.")
        }
        guard !metadata.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.migrationFailure("Schema 1 project name is empty.")
        }
        guard settings.frameRate > .zero else {
            throw ProjectError.migrationFailure("Schema 1 frame rate must be positive.")
        }
        _ = try renderSettings.validated()
        for media in mediaRegistry { _ = try media.validated() }
        guard Set(mediaRegistry.map(\.id)).count == mediaRegistry.count,
              Set(compositionRegistry.map(\.id)).count == compositionRegistry.count else {
            throw ProjectError.migrationFailure("Schema 1 project contains duplicate identities.")
        }
        return self
    }
}

package enum Schema1ProjectCodec {
    package static func decode(_ data: Data) throws -> Schema1ProjectDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        do {
            return try decoder.decode(Schema1ProjectDocument.self, from: data).validated()
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.migrationFailure(
                "Schema 1 project could not be decoded: \(error.localizedDescription)"
            )
        }
    }
    package static func encode(_ document: Schema1ProjectDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        encoder.nonConformingFloatEncodingStrategy = .throw
        do {
            return try encoder.encode(document.validated())
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.migrationFailure(
                "Schema 1 project could not be encoded: \(error.localizedDescription)"
            )
        }
    }

}
