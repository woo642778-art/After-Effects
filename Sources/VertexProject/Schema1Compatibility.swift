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

    package func validated() throws -> Self {
        guard schemaVersion == 1, minimumReaderVersion <= 1 else {
            throw ProjectError.migrationFailure("Schema 1 project compatibility values are invalid.")
        }
        guard !metadata.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.migrationFailure("Schema 1 project name is empty.")
        }
        _ = try renderSettings.validated()
        for media in mediaRegistry { _ = try media.validated() }
        guard Set(mediaRegistry.map(\.id)).count == mediaRegistry.count,
              Set(compositionRegistry.map(\.id)).count == compositionRegistry.count else {
            throw ProjectError.migrationFailure("Schema 1 project contains duplicate identities.")
        }
        if let selectedMediaID, !mediaRegistry.contains(where: { $0.id == selectedMediaID }) {
            throw ProjectError.migrationFailure("Schema 1 selected media is missing.")
        }
        if let activeCompositionID, !compositionRegistry.contains(where: { $0.id == activeCompositionID }) {
            throw ProjectError.migrationFailure("Schema 1 active composition is missing.")
        }
        return self
    }
}

package struct Schema1Manifest: Codable, Equatable, Sendable {
    package var schemaVersion: Int
    package var minimumReaderVersion: Int
    package var projectID: VertexID
    package var createdByAppVersion: String
    package var lastSavedByAppVersion: String
    package var projectRevision: UInt64
    package var projectChecksum: String
    package var committedJournalSequence: UInt64
    package var lastSuccessfulSave: Date
    package var integrityStatus: ProjectIntegrityStatus
}

package enum Schema1ProjectCodec {
    package static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        return decoder
    }

    package static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        encoder.nonConformingFloatEncodingStrategy = .throw
        return encoder
    }

    package static func decode(_ data: Data) throws -> Schema1ProjectDocument {
        do {
            return try makeDecoder().decode(Schema1ProjectDocument.self, from: data).validated()
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.migrationFailure("Schema 1 project could not be decoded: \(error.localizedDescription)")
        }
    }

    package static func encode(_ document: Schema1ProjectDocument) throws -> Data {
        do {
            return try makeEncoder().encode(document.validated())
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.migrationFailure("Schema 1 project could not be encoded: \(error.localizedDescription)")
        }
    }

    package static func decodeManifest(_ data: Data) throws -> Schema1Manifest {
        do {
            return try makeDecoder().decode(Schema1Manifest.self, from: data)
        } catch {
            throw ProjectError.migrationFailure("Schema 1 manifest could not be decoded: \(error.localizedDescription)")
        }
    }
}

package struct Schema1RecoveredState: Sendable {
    package var document: Schema1ProjectDocument
    package var lastJournalSequence: UInt64
    package var appliedCount: Int
}

package struct Schema1CommandEngine {
    package init() {}

    package func apply(_ record: ProjectCommandRecord, to input: Schema1ProjectDocument) throws -> Schema1ProjectDocument {
        guard record.projectID == input.projectID else { throw ProjectError.invalidProjectIdentity }
        guard record.baseRevision == input.revision else {
            throw ProjectError.staleBaseRevision(expected: record.baseRevision, actual: input.revision)
        }
        guard !input.appliedCommandIDs.contains(record.commandID) else {
            throw ProjectError.duplicateCommand(record.commandID.rawValue)
        }
        guard record.inverseOperation == record.forwardOperation.inverse else {
            throw ProjectError.invalidInverseOperation("Schema 1 journal inverse is invalid.")
        }

        var document = input
        switch record.forwardOperation {
        case .renameProject(let before, let after):
            guard document.metadata.name == before, !after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ProjectError.invalidOperation("Schema 1 project rename precondition failed.")
            }
            document.metadata.name = after

        case .registerMedia(let reference):
            _ = try reference.validated()
            guard !document.mediaRegistry.contains(where: { $0.id == reference.id }) else { throw ProjectError.duplicateIdentity("media") }
            document.mediaRegistry.append(reference)

        case .removeMedia(let reference):
            guard let index = document.mediaRegistry.firstIndex(of: reference) else {
                throw ProjectError.invalidOperation("Schema 1 media removal precondition failed.")
            }
            document.mediaRegistry.remove(at: index)
            if document.selectedMediaID == reference.id { document.selectedMediaID = nil }

        case .relinkMedia(let mediaID, let before, let after):
            guard let index = document.mediaRegistry.firstIndex(where: { $0.id == mediaID }),
                  document.mediaRegistry[index].locator == before else {
                throw ProjectError.invalidOperation("Schema 1 relink precondition failed.")
            }
            document.mediaRegistry[index].locator = after
            document.mediaRegistry[index].availabilityStatus = after.embeddedPath == nil ? .external : .embedded

        case .setEmbeddedPath(let mediaID, let before, let after):
            guard let index = document.mediaRegistry.firstIndex(where: { $0.id == mediaID }),
                  document.mediaRegistry[index].locator.embeddedPath == before else {
                throw ProjectError.invalidOperation("Schema 1 embedded-path precondition failed.")
            }
            document.mediaRegistry[index].locator.embeddedPath = after
            document.mediaRegistry[index].availabilityStatus = after == nil ? .external : .embedded

        case .selectMedia(let before, let after):
            guard document.selectedMediaID == before else { throw ProjectError.invalidOperation("Schema 1 selection precondition failed.") }
            if let after, !document.mediaRegistry.contains(where: { $0.id == after }) { throw ProjectError.missingMedia(after.rawValue) }
            document.selectedMediaID = after

        case .setRenderParameter(let parameter, let before, let after):
            guard before.isFinite, after.isFinite, document.renderSettings.value(for: parameter) == before else {
                throw ProjectError.invalidOperation("Schema 1 render parameter precondition failed.")
            }
            document.renderSettings.set(after, for: parameter)
            _ = try document.renderSettings.validated()

        case .setRenderBoolean(let parameter, let before, let after):
            switch parameter {
            case .inverted:
                guard document.renderSettings.inverted == before else { throw ProjectError.invalidOperation("Schema 1 render boolean precondition failed.") }
                document.renderSettings.inverted = after
            }

        case .setOutputDimensions(let beforeWidth, let beforeHeight, let afterWidth, let afterHeight):
            guard document.renderSettings.outputWidth == beforeWidth,
                  document.renderSettings.outputHeight == beforeHeight else {
                throw ProjectError.invalidOperation("Schema 1 output dimension precondition failed.")
            }
            document.renderSettings.outputWidth = afterWidth
            document.renderSettings.outputHeight = afterHeight
            _ = try document.renderSettings.validated()

        case .setProjectColor(let before, let after):
            guard document.settings.color == before else { throw ProjectError.invalidOperation("Schema 1 color precondition failed.") }
            document.settings.color = after

        default:
            throw ProjectError.migrationFailure("A schema 2-only command appeared in a schema 1 journal.")
        }

        document.revision += 1
        document.metadata.modifiedAt = record.timestamp
        document.metadata.lastSavedByAppVersion = "5.0.0"
        document.appliedCommandIDs.append(record.commandID)
        if document.appliedCommandIDs.count > 1_000 {
            document.appliedCommandIDs.removeFirst(document.appliedCommandIDs.count - 1_000)
        }
        return try document.validated()
    }
}

package struct Schema1JournalReplayer {
    package init() {}

    package func replay(
        _ records: [ProjectJournalRecord],
        onto document: Schema1ProjectDocument,
        startingAfter committedSequence: UInt64
    ) throws -> Schema1RecoveredState {
        var project = try document.validated()
        var expected = committedSequence + 1
        var last = committedSequence
        var applied = 0
        let engine = Schema1CommandEngine()

        for record in records where record.sequence > committedSequence {
            _ = try record.validated()
            guard record.sequence == expected else {
                throw ProjectError.journalGap(expected: expected, actual: record.sequence)
            }
            expected += 1
            last = record.sequence
            if project.appliedCommandIDs.contains(record.command.commandID) { continue }
            project = try engine.apply(record.command, to: project)
            applied += 1
        }
        return Schema1RecoveredState(document: project, lastJournalSequence: last, appliedCount: applied)
    }
}
