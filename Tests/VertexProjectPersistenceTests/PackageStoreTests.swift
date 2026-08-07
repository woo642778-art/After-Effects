import Foundation
import Testing
import VertexCore
import VertexProject
@testable import VertexProjectPersistence

private func packageStoreTemporaryURL(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(name, isDirectory: true)
        .appendingPathExtension("vertexproject")
}

private func packageStoreDocument(
    name: String = "Package Store",
    revision: UInt64 = 0,
    timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000)
) throws -> ProjectDocument {
    var document = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "51000000-0000-0000-0000-000000000001"),
        name: name,
        timestamp: timestamp
    )
    document.revision = revision
    document.metadata.modifiedAt = timestamp.addingTimeInterval(TimeInterval(revision))
    return try document.validated()
}

@Test("Creating a canonical package writes a matching verified pair")
func canonicalPackageCreationRoundTrips() throws {
    let url = packageStoreTemporaryURL("Create")
    defer { try? FileManager.default.removeItem(at: url) }

    let document = try packageStoreDocument()
    let snapshot = try VertexProjectPackageStore(
        fixedTimestamp: Date(timeIntervalSince1970: 1_700_000_100)
    ).create(at: url, document: document)

    #expect(snapshot.document == document)
    #expect(snapshot.manifest.projectID == document.projectID)
    #expect(snapshot.manifest.projectRevision == document.revision)
    #expect(snapshot.manifest.projectChecksum == DeterministicProjectCodec().checksum(data: snapshot.projectData))

    let entries = try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
    #expect(entries == ["Autosaves", "Bookmarks", "Journal", "Media", "manifest.json", "project.json"])

    let opened = try VertexProjectPackageStore().open(at: url)
    guard case .opened(let reopened) = opened else {
        Issue.record("A newly created package must open without a pending decision.")
        return
    }
    #expect(reopened.document == document)
    #expect(reopened.manifest == snapshot.manifest)
}

@Test("Saving replaces project and manifest as one verified revision")
func canonicalPackageSaveRoundTrips() throws {
    let url = packageStoreTemporaryURL("Save")
    defer { try? FileManager.default.removeItem(at: url) }

    let store = VertexProjectPackageStore(fixedTimestamp: Date(timeIntervalSince1970: 1_700_000_100))
    let original = try packageStoreDocument(name: "Original")
    _ = try store.create(at: url, document: original)

    var changed = original
    changed.revision = 1
    changed.metadata.name = "Changed"
    changed.metadata.modifiedAt = Date(timeIntervalSince1970: 1_700_000_101)
    let saved = try VertexProjectPackageStore(
        fixedTimestamp: Date(timeIntervalSince1970: 1_700_000_102)
    ).save(changed, to: url)

    #expect(saved.document.metadata.name == "Changed")
    #expect(saved.manifest.projectRevision == 1)
    #expect(!FileManager.default.fileExists(atPath: saved.layout.pendingSaveURL.path))
    #expect(!FileManager.default.fileExists(atPath: saved.layout.projectTemporaryURL.path))
    #expect(!FileManager.default.fileExists(atPath: saved.layout.manifestTemporaryURL.path))

    guard case .opened(let reopened) = try VertexProjectPackageStore().open(at: url) else {
        Issue.record("A successfully saved package must open directly.")
        return
    }
    #expect(reopened.document == changed)
    #expect(reopened.manifest.projectChecksum == saved.manifest.projectChecksum)
}

@Test("Discarding uncertain pending data preserves the verified current pair")
func discardPendingPreservesCurrentPair() throws {
    let url = packageStoreTemporaryURL("DiscardPending")
    defer { try? FileManager.default.removeItem(at: url) }

    let original = try packageStoreDocument(name: "Verified")
    let store = VertexProjectPackageStore(fixedTimestamp: Date(timeIntervalSince1970: 1_700_000_100))
    _ = try store.create(at: url, document: original)
    let layout = try VertexProjectPackageLayout(root: url)
    try Data("not-json".utf8).write(to: layout.pendingSaveURL)

    guard case .pendingDecision(let context) = try store.open(at: url) else {
        Issue.record("Corrupt pending data must require an explicit decision.")
        return
    }
    #expect(context.currentSnapshot?.document == original)

    let reopened = try store.discardPending(in: url)
    #expect(reopened.document == original)
    #expect(!FileManager.default.fileExists(atPath: layout.pendingSaveURL.path))
}
