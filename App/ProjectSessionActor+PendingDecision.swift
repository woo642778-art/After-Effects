import Foundation
import VertexProjectPersistence

extension ProjectSessionActor {
    func applyPendingAndOpen(packageURL: URL) async throws -> ProjectSessionSnapshot {
        _ = try VertexProjectPackageStore().applyPending(in: packageURL)
        guard case .opened(let snapshot) = try await openCanonical(packageURL: packageURL) else {
            throw ProjectPersistenceError.pendingSnapshotCorrupt(
                "Applied pending snapshot did not open directly."
            )
        }
        return snapshot
    }
}
