import Foundation
import VertexCore

public enum ProjectPersistenceError: Error, Equatable, Sendable {
    case unsupportedPackageExtension(found: String)
    case forbiddenPackageEntry(String)
    case invalidManifest(String)
    case checksumMismatch(expected: String, actual: String)
    case pendingSnapshotCorrupt(String)
    case pendingSnapshotOlderThanCurrent(pending: UInt64, current: UInt64)
    case atomicReplacementFailed(String)
    case autosaveVerificationFailed(String)
    case bookmarkMissing(VertexID)
    case bookmarkStale(VertexID)
    case embeddedMediaMismatch(VertexID)
    case legacyJournalCorrupt(sequence: UInt64?)
    case legacyImportIncomplete(stage: String)
    case concurrentRequestSuperseded
}

extension ProjectPersistenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedPackageExtension(let found):
            "Unsupported project package extension: \(found.isEmpty ? "(none)" : found)."
        case .forbiddenPackageEntry(let entry):
            "The project package contains a forbidden entry: \(entry)."
        case .invalidManifest(let reason):
            "The project manifest is invalid: \(reason)"
        case .checksumMismatch(let expected, let actual):
            "Project checksum mismatch. Expected \(expected), found \(actual)."
        case .pendingSnapshotCorrupt(let reason):
            "The pending project snapshot is corrupt: \(reason)"
        case .pendingSnapshotOlderThanCurrent(let pending, let current):
            "The pending project revision \(pending) is older than the current revision \(current)."
        case .atomicReplacementFailed(let reason):
            "Atomic project replacement failed: \(reason)"
        case .autosaveVerificationFailed(let reason):
            "Autosave verification failed: \(reason)"
        case .bookmarkMissing(let mediaID):
            "The bookmark sidecar is missing for media \(mediaID.rawValue)."
        case .bookmarkStale(let mediaID):
            "The bookmark sidecar is stale for media \(mediaID.rawValue)."
        case .embeddedMediaMismatch(let mediaID):
            "Embedded media verification failed for \(mediaID.rawValue)."
        case .legacyJournalCorrupt(let sequence):
            "The legacy project journal is corrupt\(sequence.map { " at sequence \($0)" } ?? "")."
        case .legacyImportIncomplete(let stage):
            "Legacy project import did not complete at stage: \(stage)."
        case .concurrentRequestSuperseded:
            "The project request was superseded by a newer operation."
        }
    }
}
