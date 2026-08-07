import Foundation

public enum ProjectError: Error, Equatable, Sendable, LocalizedError {
    case unsupportedSchema(found: Int, supported: Int)
    case invalidRevision
    case invalidProjectIdentity
    case invalidValue(String)
    case duplicateIdentity(String)
    case deterministicEncodingFailure(String)
    case decodingFailure(String)
    case checksumMismatch(expected: String, actual: String)
    case staleBaseRevision(expected: UInt64, actual: UInt64)
    case duplicateCommand(String)
    case invalidOperation(String)
    case invalidInverseOperation(String)
    case journalGap(expected: UInt64, actual: UInt64)
    case journalCorruption(String)
    case journalIncompatibility(String)
    case packageCorruption(String)
    case manifestCorruption(String)
    case atomicReplacementFailure(String)
    case autosaveRotationFailure(String)
    case migrationFailure(String)
    case missingMedia(String)
    case bookmarkFailure(String)
    case relinkMismatch(String)
    case embeddingFailure(String)
    case invalidPackagePath(String)
    case cancelled

    public var code: String {
        switch self {
        case .unsupportedSchema: "project.unsupported-schema"
        case .invalidRevision: "project.invalid-revision"
        case .invalidProjectIdentity: "project.invalid-identity"
        case .invalidValue: "project.invalid-value"
        case .duplicateIdentity: "project.duplicate-identity"
        case .deterministicEncodingFailure: "project.encoding-failure"
        case .decodingFailure: "project.decoding-failure"
        case .checksumMismatch: "project.checksum-mismatch"
        case .staleBaseRevision: "project.stale-revision"
        case .duplicateCommand: "project.duplicate-command"
        case .invalidOperation: "project.invalid-operation"
        case .invalidInverseOperation: "project.invalid-inverse"
        case .journalGap: "project.journal-gap"
        case .journalCorruption: "project.journal-corruption"
        case .journalIncompatibility: "project.journal-incompatibility"
        case .packageCorruption: "project.package-corruption"
        case .manifestCorruption: "project.manifest-corruption"
        case .atomicReplacementFailure: "project.atomic-replacement-failure"
        case .autosaveRotationFailure: "project.autosave-failure"
        case .migrationFailure: "project.migration-failure"
        case .missingMedia: "project.missing-media"
        case .bookmarkFailure: "project.bookmark-failure"
        case .relinkMismatch: "project.relink-mismatch"
        case .embeddingFailure: "project.embedding-failure"
        case .invalidPackagePath: "project.invalid-package-path"
        case .cancelled: "project.cancelled"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let found, let supported):
            "Project schema \(found) is newer than supported schema \(supported)."
        case .invalidRevision:
            "The project revision is invalid."
        case .invalidProjectIdentity:
            "The project identity is invalid."
        case .invalidValue(let message),
             .deterministicEncodingFailure(let message),
             .decodingFailure(let message),
             .invalidOperation(let message),
             .invalidInverseOperation(let message),
             .journalCorruption(let message),
             .journalIncompatibility(let message),
             .packageCorruption(let message),
             .manifestCorruption(let message),
             .atomicReplacementFailure(let message),
             .autosaveRotationFailure(let message),
             .migrationFailure(let message),
             .missingMedia(let message),
             .bookmarkFailure(let message),
             .relinkMismatch(let message),
             .embeddingFailure(let message),
             .invalidPackagePath(let message):
            message
        case .duplicateIdentity(let kind):
            "The project contains a duplicate \(kind) identity."
        case .checksumMismatch(let expected, let actual):
            "Project checksum mismatch. Expected \(expected), found \(actual)."
        case .staleBaseRevision(let expected, let actual):
            "The command expected revision \(expected), but the project is at revision \(actual)."
        case .duplicateCommand(let commandID):
            "Command \(commandID) has already been applied."
        case .journalGap(let expected, let actual):
            "Journal sequence gap. Expected \(expected), found \(actual)."
        case .cancelled:
            "The project operation was cancelled."
        }
    }
}
