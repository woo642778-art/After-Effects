import Foundation
import VertexCore
import VertexProject

package enum LegacyProjectIntegrityStatus: String, Codable, Equatable, Sendable {
    case valid
    case recovered
    case damaged
}

package struct LegacyManifestDTO: Codable, Equatable, Sendable {
    package var schemaVersion: Int
    package var minimumReaderVersion: Int
    package var projectID: VertexID
    package var createdByAppVersion: String
    package var lastSavedByAppVersion: String
    package var projectRevision: UInt64
    package var projectChecksum: String
    package var committedJournalSequence: UInt64
    package var lastSuccessfulSave: Date
    package var integrityStatus: LegacyProjectIntegrityStatus

    package static func decode(_ data: Data) throws -> LegacyManifestDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        do {
            return try decoder.decode(LegacyManifestDTO.self, from: data)
        } catch {
            throw ProjectPersistenceError.legacyImportIncomplete(
                stage: "legacy manifest decode: \(error.localizedDescription)"
            )
        }
    }

    package func validate(project: DecodedLegacyProject, projectData: Data) throws {
        guard projectID == project.projectID,
              projectRevision == project.revision,
              schemaVersion == project.schemaVersion,
              minimumReaderVersion <= schemaVersion else {
            throw ProjectPersistenceError.legacyImportIncomplete(
                stage: "legacy manifest identity or schema mismatch"
            )
        }
        let actual = DeterministicProjectCodec().checksum(data: projectData)
        guard actual == projectChecksum else {
            throw ProjectPersistenceError.checksumMismatch(
                expected: projectChecksum,
                actual: actual
            )
        }
    }
}
