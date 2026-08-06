import Foundation
import VertexProject

public struct ProjectPackageSnapshot: Equatable, Sendable {
    public let layout: VertexProjectPackageLayout
    public let document: ProjectDocument
    public let manifest: VertexProjectManifest
    public let projectData: Data
    public let manifestData: Data

    public init(
        layout: VertexProjectPackageLayout,
        document: ProjectDocument,
        manifest: VertexProjectManifest,
        projectData: Data,
        manifestData: Data
    ) {
        self.layout = layout
        self.document = document
        self.manifest = manifest
        self.projectData = projectData
        self.manifestData = manifestData
    }
}

public struct PendingSnapshotDecisionContext: Equatable, Sendable {
    public let packageURL: URL
    public let currentSnapshot: ProjectPackageSnapshot?
    public let pendingRevision: UInt64?
    public let reason: ProjectPersistenceError

    public init(
        packageURL: URL,
        currentSnapshot: ProjectPackageSnapshot?,
        pendingRevision: UInt64?,
        reason: ProjectPersistenceError
    ) {
        self.packageURL = packageURL
        self.currentSnapshot = currentSnapshot
        self.pendingRevision = pendingRevision
        self.reason = reason
    }
}

public enum ProjectPackageOpenResult: Equatable, Sendable {
    case opened(ProjectPackageSnapshot)
    case pendingDecision(PendingSnapshotDecisionContext)
}

package enum VertexProjectPackageStoreFailurePoint: String, CaseIterable, Sendable {
    case beforePendingWrite
    case afterPendingFileSync
    case afterProjectTemporaryWrite
    case afterProjectReplacement
    case afterPairReplacement
    case afterVerification
}

public struct VertexProjectPackageStore: Sendable {
    private let failurePoint: VertexProjectPackageStoreFailurePoint?
    private let fixedTimestamp: Date?

    public init() {
        self.failurePoint = nil
        self.fixedTimestamp = nil
    }

    package init(
        failurePoint: VertexProjectPackageStoreFailurePoint? = nil,
        fixedTimestamp: Date? = nil
    ) {
        self.failurePoint = failurePoint
        self.fixedTimestamp = fixedTimestamp
    }

    public func create(at url: URL, document: ProjectDocument) throws -> ProjectPackageSnapshot {
        let layout = try VertexProjectPackageLayout(root: url)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: layout.root.path) {
            let entries = try fileManager.contentsOfDirectory(atPath: layout.root.path)
            guard entries.isEmpty else {
                throw ProjectPersistenceError.forbiddenPackageEntry(
                    "destination package is not empty"
                )
            }
        }
        try layout.createRequiredDirectories(fileManager: fileManager)
        let snapshot = try performTransaction(document: document, layout: layout)
        try layout.validateAllowlist(fileManager: fileManager, mode: .steadyState)
        return snapshot
    }

    public func open(at url: URL) throws -> ProjectPackageOpenResult {
        let layout = try VertexProjectPackageLayout(root: url)
        let fileManager = FileManager.default
        try layout.validateAllowlist(fileManager: fileManager, mode: .transactionRecovery)

        let currentResult = Result { try loadCurrent(layout: layout) }
        guard fileManager.fileExists(atPath: layout.pendingSaveURL.path) else {
            try cleanupKnownTemporaries(layout: layout, removePending: false)
            try layout.validateAllowlist(fileManager: fileManager, mode: .steadyState)
            return .opened(try currentResult.get())
        }

        let pendingPair: VerifiedProjectPair
        do {
            let envelopeData = try Data(contentsOf: layout.pendingSaveURL)
            let envelope = try PendingSaveEnvelopeCodec().decode(envelopeData)
            pendingPair = try envelope.verifiedPair()
        } catch {
            let persistenceError = asPendingError(error)
            return .pendingDecision(PendingSnapshotDecisionContext(
                packageURL: layout.root,
                currentSnapshot: try? currentResult.get(),
                pendingRevision: nil,
                reason: persistenceError
            ))
        }

        guard let current = try? currentResult.get() else {
            let recovered = try install(pair: pendingPair, layout: layout)
            try cleanupKnownTemporaries(layout: layout, removePending: true)
            try layout.validateAllowlist(fileManager: fileManager, mode: .steadyState)
            return .opened(recovered)
        }

        if current.manifest.projectRevision == pendingPair.manifest.projectRevision,
           current.manifest.projectChecksum == pendingPair.manifest.projectChecksum {
            try cleanupKnownTemporaries(layout: layout, removePending: true)
            try layout.validateAllowlist(fileManager: fileManager, mode: .steadyState)
            return .opened(current)
        }

        if pendingPair.manifest.projectRevision > current.manifest.projectRevision {
            let recovered = try install(pair: pendingPair, layout: layout)
            try cleanupKnownTemporaries(layout: layout, removePending: true)
            try layout.validateAllowlist(fileManager: fileManager, mode: .steadyState)
            return .opened(recovered)
        }

        if pendingPair.manifest.projectRevision < current.manifest.projectRevision {
            return .pendingDecision(PendingSnapshotDecisionContext(
                packageURL: layout.root,
                currentSnapshot: current,
                pendingRevision: pendingPair.manifest.projectRevision,
                reason: .pendingSnapshotOlderThanCurrent(
                    pending: pendingPair.manifest.projectRevision,
                    current: current.manifest.projectRevision
                )
            ))
        }

        return .pendingDecision(PendingSnapshotDecisionContext(
            packageURL: layout.root,
            currentSnapshot: current,
            pendingRevision: pendingPair.manifest.projectRevision,
            reason: .pendingSnapshotCorrupt(
                "Pending data diverges from the verified current pair at the same revision."
            )
        ))
    }

    public func save(_ document: ProjectDocument, to url: URL) throws -> ProjectPackageSnapshot {
        let layout = try VertexProjectPackageLayout(root: url)
        let fileManager = FileManager.default
        try layout.validateAllowlist(fileManager: fileManager, mode: .transactionRecovery)

        if let current = try? loadCurrent(layout: layout) {
            guard current.document.projectID == document.projectID else {
                throw ProjectPersistenceError.invalidManifest(
                    "The document project ID does not match the destination package."
                )
            }
            guard document.revision >= current.document.revision else {
                throw ProjectPersistenceError.pendingSnapshotOlderThanCurrent(
                    pending: document.revision,
                    current: current.document.revision
                )
            }
        }

        let snapshot = try performTransaction(document: document, layout: layout)
        try layout.validateAllowlist(fileManager: fileManager, mode: .steadyState)
        return snapshot
    }

    public func discardPending(in url: URL) throws -> ProjectPackageSnapshot {
        let layout = try VertexProjectPackageLayout(root: url)
        try cleanupKnownTemporaries(layout: layout, removePending: true)
        try layout.validateAllowlist(fileManager: .default, mode: .steadyState)
        return try loadCurrent(layout: layout)
    }

    private func performTransaction(
        document: ProjectDocument,
        layout: VertexProjectPackageLayout
    ) throws -> ProjectPackageSnapshot {
        if failurePoint == .beforePendingWrite {
            throw injected(.beforePendingWrite)
        }

        let validated = try document.validated()
        let projectData = try DeterministicProjectCodec().encode(validated)
        let manifest = try VertexProjectManifest(
            document: validated,
            projectData: projectData,
            savedAt: fixedTimestamp ?? Date()
        )
        let manifestData = try VertexProjectManifestCodec().encode(manifest)
        let envelopeData = try PendingSaveEnvelopeCodec().encode(
            PendingSaveEnvelope(projectData: projectData, manifestData: manifestData)
        )
        let io = DurableFileIO()

        try io.writeAndSynchronize(envelopeData, to: layout.pendingSaveTemporaryURL)
        if failurePoint == .afterPendingFileSync {
            throw injected(.afterPendingFileSync)
        }
        try io.atomicPromote(layout.pendingSaveTemporaryURL, to: layout.pendingSaveURL)
        try io.synchronizeDirectory(layout.journalDirectoryURL)

        try io.writeAndSynchronize(projectData, to: layout.projectTemporaryURL)
        if failurePoint == .afterProjectTemporaryWrite {
            throw injected(.afterProjectTemporaryWrite)
        }
        try io.writeAndSynchronize(manifestData, to: layout.manifestTemporaryURL)

        try io.atomicPromote(layout.projectTemporaryURL, to: layout.projectURL)
        try io.synchronizeDirectory(layout.root)
        if failurePoint == .afterProjectReplacement {
            throw injected(.afterProjectReplacement)
        }

        try io.atomicPromote(layout.manifestTemporaryURL, to: layout.manifestURL)
        try io.synchronizeDirectory(layout.root)
        if failurePoint == .afterPairReplacement {
            throw injected(.afterPairReplacement)
        }

        let verified = try loadCurrent(layout: layout)
        if failurePoint == .afterVerification {
            throw injected(.afterVerification)
        }

        try cleanupKnownTemporaries(layout: layout, removePending: true)
        return verified
    }

    private func loadCurrent(layout: VertexProjectPackageLayout) throws -> ProjectPackageSnapshot {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: layout.projectURL.path),
              fileManager.fileExists(atPath: layout.manifestURL.path) else {
            throw ProjectPersistenceError.invalidManifest(
                "project.json and manifest.json must both exist."
            )
        }

        do {
            let projectData = try Data(contentsOf: layout.projectURL)
            let manifestData = try Data(contentsOf: layout.manifestURL)
            let document = try DeterministicProjectCodec().decode(projectData)
            let manifest = try VertexProjectManifestCodec().decode(manifestData)
            try manifest.validate(document: document, projectData: projectData)
            return ProjectPackageSnapshot(
                layout: layout,
                document: document,
                manifest: manifest,
                projectData: projectData,
                manifestData: manifestData
            )
        } catch let error as ProjectPersistenceError {
            throw error
        } catch {
            throw ProjectPersistenceError.invalidManifest(
                "The canonical project pair could not be opened: \(error.localizedDescription)"
            )
        }
    }

    private func install(
        pair: VerifiedProjectPair,
        layout: VertexProjectPackageLayout
    ) throws -> ProjectPackageSnapshot {
        let io = DurableFileIO()
        try io.writeAndSynchronize(pair.projectData, to: layout.projectTemporaryURL)
        try io.writeAndSynchronize(pair.manifestData, to: layout.manifestTemporaryURL)
        try io.atomicPromote(layout.projectTemporaryURL, to: layout.projectURL)
        try io.atomicPromote(layout.manifestTemporaryURL, to: layout.manifestURL)
        try io.synchronizeDirectory(layout.root)
        return try loadCurrent(layout: layout)
    }

    private func cleanupKnownTemporaries(
        layout: VertexProjectPackageLayout,
        removePending: Bool
    ) throws {
        let io = DurableFileIO()
        try io.removeIfPresent(layout.projectTemporaryURL)
        try io.removeIfPresent(layout.manifestTemporaryURL)
        try io.removeIfPresent(layout.pendingSaveTemporaryURL)
        if removePending {
            try io.removeIfPresent(layout.pendingSaveURL)
        }
        try io.synchronizeDirectory(layout.root)
        try io.synchronizeDirectory(layout.journalDirectoryURL)
    }

    private func injected(_ point: VertexProjectPackageStoreFailurePoint) -> ProjectPersistenceError {
        .atomicReplacementFailed("Injected package-store failure at \(point.rawValue).")
    }

    private func asPendingError(_ error: Error) -> ProjectPersistenceError {
        if let persistenceError = error as? ProjectPersistenceError {
            switch persistenceError {
            case .pendingSnapshotCorrupt:
                return persistenceError
            default:
                return .pendingSnapshotCorrupt(persistenceError.localizedDescription)
            }
        }
        return .pendingSnapshotCorrupt(error.localizedDescription)
    }
}
