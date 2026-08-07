import Foundation
import VertexCore

package struct Schema1CompositionPlaceholder: Codable, Equatable, Sendable {
    package var id: VertexID
    package var name: String
}

package struct Schema1ProjectDocument: Codable, Equatable, Sendable {
    package var schemaVersion: Int
    package var minimumReaderVersion: Int
    package var projectID: VertexID
    package var revision: UInt64
    package var metadata: ProjectMetadata
    package var settings: ProjectSettings
    package var mediaRegistry: [MediaReference]
    package var compositionRegistry: [Schema1CompositionPlaceholder]
    package var activeCompositionID: VertexID?
    package var selectedMediaID: VertexID?
    package var renderSettings: ProjectRenderSettings

    package func validated() throws -> Self {
        guard schemaVersion == 1, minimumReaderVersion <= 1 else { throw ProjectError.migrationFailure("Schema 1 compatibility values are invalid.") }
        guard !metadata.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ProjectError.migrationFailure("Schema 1 project name is empty.") }
        _ = try renderSettings.validated()
        for media in mediaRegistry { _ = try media.validated() }
        guard Set(mediaRegistry.map(\.id)).count == mediaRegistry.count,
              Set(compositionRegistry.map(\.id)).count == compositionRegistry.count else {
            throw ProjectError.migrationFailure("Schema 1 project contains duplicate identities.")
        }
        if let selectedMediaID, !mediaRegistry.contains(where: { $0.id == selectedMediaID }) { throw ProjectError.migrationFailure("Schema 1 selected media is missing.") }
        if let activeCompositionID, !compositionRegistry.contains(where: { $0.id == activeCompositionID }) { throw ProjectError.migrationFailure("Schema 1 active composition is missing.") }
        return self
    }
}

package enum Schema1ProjectCodec {
    package static func decode(_ data: Data) throws -> Schema1ProjectDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        do { return try decoder.decode(Schema1ProjectDocument.self, from: data).validated() }
        catch let error as ProjectError { throw error }
        catch { throw ProjectError.migrationFailure("Schema 1 project could not be decoded: \(error.localizedDescription)") }
    }
}
