import Foundation
import Testing
import VertexProject
@testable import VertexProjectPersistence

@Test("Package creation accepts live Date precision and returns canonical bytes")
func packageCreationCanonicalizesLiveDatePrecision() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("Timestamp-\(UUID().uuidString)", isDirectory: true)
        .appendingPathExtension("vertexproject")
    defer { try? FileManager.default.removeItem(at: root) }

    let document = try ProjectDocument.makeNew(
        name: "Timestamp",
        timestamp: Date()
    )
    let snapshot = try VertexProjectPackageStore().create(
        at: root,
        document: document
    )

    let codec = DeterministicProjectCodec()
    #expect(try codec.encode(snapshot.document) == snapshot.projectData)
    #expect(snapshot.document.projectID == document.projectID)
    #expect(snapshot.document.revision == document.revision)

    guard case .opened(let reopened) = try VertexProjectPackageStore().open(at: root) else {
        Issue.record("A newly created canonical package must reopen without a recovery decision.")
        return
    }
    #expect(reopened.projectData == snapshot.projectData)
    #expect(reopened.document == snapshot.document)
}
