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
    package var appliedCommandIDs: [VertexID]
}

package enum Schema1ProjectCodec {
    package static func decode(_ data: Data) throws -> Schema1ProjectDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        do {
            let document = try decoder.decode(Schema1ProjectDocument.self, from: data)
            guard document.schemaVersion == 1 else {
                throw ProjectError.migrationFailure("Schema 1 compatibility decoder received schema \(document.schemaVersion).")
            }
            return document
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.migrationFailure("Schema 1 project could not be decoded: \(error.localizedDescription)")
        }
    }

    package static func encode(_ document: Schema1ProjectDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        encoder.nonConformingFloatEncodingStrategy = .throw
        do {
            return try encoder.encode(document)
        } catch {
            throw ProjectError.migrationFailure("Schema 1 project could not be encoded: \(error.localizedDescription)")
        }
    }
}
