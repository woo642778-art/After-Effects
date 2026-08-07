import Foundation

public extension VertexProjectPackageStore {
    func applyPending(in url: URL) throws -> ProjectPackageSnapshot {
        let layout = try VertexProjectPackageLayout(root: url)
        let envelopeData: Data
        do {
            envelopeData = try Data(contentsOf: layout.pendingSaveURL)
        } catch {
            throw ProjectPersistenceError.pendingSnapshotCorrupt(
                "Pending snapshot could not be read: \(error.localizedDescription)"
            )
        }

        let envelope = try PendingSaveEnvelopeCodec().decode(envelopeData)
        let pair = try envelope.verifiedPair()
        let io = DurableFileIO()
        do {
            try io.writeAndSynchronize(pair.projectData, to: layout.projectTemporaryURL)
            try io.writeAndSynchronize(pair.manifestData, to: layout.manifestTemporaryURL)
            try io.atomicPromote(layout.projectTemporaryURL, to: layout.projectURL)
            try io.atomicPromote(layout.manifestTemporaryURL, to: layout.manifestURL)
            try io.synchronizeDirectory(layout.root)
            try io.removeIfPresent(layout.pendingSaveURL)
            try io.removeIfPresent(layout.pendingSaveTemporaryURL)
            try io.synchronizeDirectory(layout.journalDirectoryURL)
        } catch let error as ProjectPersistenceError {
            throw error
        } catch {
            throw ProjectPersistenceError.atomicReplacementFailed(
                "Explicit pending snapshot application failed: \(error.localizedDescription)"
            )
        }

        guard case .opened(let snapshot) = try open(at: url) else {
            throw ProjectPersistenceError.pendingSnapshotCorrupt(
                "Applied pending snapshot did not reopen as a verified pair."
            )
        }
        return snapshot
    }
}
