import Foundation
import Testing
import VertexProject
@testable import VertexProjectPersistence

private func pendingTemporaryURL(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(name, isDirectory: true)
        .appendingPathExtension("vertexproject")
}

private func pendingDocument(
    name: String,
    revision: UInt64,
    timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000)
) throws -> ProjectDocument {
    var document = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "52000000-0000-0000-0000-000000000001"),
        name: name,
        timestamp: timestamp
    )
    document.revision = revision
    document.metadata.modifiedAt = timestamp.addingTimeInterval(TimeInterval(revision))
    return try document.validated()
}

@Test("Pending envelope preserves exact independently checksummed bytes")
func pendingEnvelopeRoundTripsExactBytes() throws {
    let document = try pendingDocument(name: "Envelope", revision: 4)
    let projectData = try DeterministicProjectCodec().encode(document)
    let manifest = try VertexProjectManifest(
        document: document,
        projectData: projectData,
        savedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
    let manifestData = try VertexProjectManifestCodec().encode(manifest)
    let envelope = PendingSaveEnvelope(projectData: projectData, manifestData: manifestData)
    let encoded = try PendingSaveEnvelopeCodec().encode(envelope)
    let decoded = try PendingSaveEnvelopeCodec().decode(encoded)
    let verified = try decoded.verifiedPair()

    #expect(decoded.projectData == projectData)
    #expect(decoded.manifestData == manifestData)
    #expect(verified.document == document)
    #expect(verified.manifest == manifest)
    #expect(encoded == try PendingSaveEnvelopeCodec().encode(decoded))

    let projectJSON = String(decoding: decoded.projectData, as: UTF8.self)
    for forbidden in ["bookmarkData", "appliedCommandIDs", "legacyRenderSettings", "inverseOperation", "history", "undo", "redo"] {
        #expect(!projectJSON.contains(forbidden))
    }
    #expect(!projectJSON.contains(FileManager.default.homeDirectoryForCurrentUser.path))
}

@Test("Pending envelope rejects independently corrupted payloads")
func pendingEnvelopeRejectsCorruption() throws {
    let document = try pendingDocument(name: "Corrupt", revision: 1)
    let projectData = try DeterministicProjectCodec().encode(document)
    let manifest = try VertexProjectManifest(
        document: document,
        projectData: projectData,
        savedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
    let manifestData = try VertexProjectManifestCodec().encode(manifest)

    var projectCorrupt = PendingSaveEnvelope(projectData: projectData, manifestData: manifestData)
    projectCorrupt.projectData.append(0)
    #expect(throws: ProjectPersistenceError.self) {
        try projectCorrupt.verifiedPair()
    }

    var manifestCorrupt = PendingSaveEnvelope(projectData: projectData, manifestData: manifestData)
    manifestCorrupt.manifestData.append(0)
    #expect(throws: ProjectPersistenceError.self) {
        try manifestCorrupt.verifiedPair()
    }
}

@Test("Every injected save boundary reopens to one complete verified pair")
func saveFailureBoundariesNeverExposeMixedPair() throws {
    for failurePoint in VertexProjectPackageStoreFailurePoint.allCases {
        let url = pendingTemporaryURL("Failure-\(failurePoint.rawValue)")
        defer { try? FileManager.default.removeItem(at: url) }

        let original = try pendingDocument(name: "Original", revision: 0)
        _ = try VertexProjectPackageStore(
            fixedTimestamp: Date(timeIntervalSince1970: 1_700_000_010)
        ).create(at: url, document: original)

        let candidate = try pendingDocument(name: "Candidate", revision: 1)
        let faulting = VertexProjectPackageStore(
            failurePoint: failurePoint,
            fixedTimestamp: Date(timeIntervalSince1970: 1_700_000_020)
        )
        #expect(throws: ProjectPersistenceError.self) {
            try faulting.save(candidate, to: url)
        }

        let result = try VertexProjectPackageStore().open(at: url)
        guard case .opened(let snapshot) = result else {
            Issue.record("Boundary \(failurePoint.rawValue) should be automatically recoverable.")
            continue
        }

        #expect(snapshot.document == original || snapshot.document == candidate)
        #expect(snapshot.manifest.projectRevision == snapshot.document.revision)
        #expect(snapshot.manifest.projectID == snapshot.document.projectID)
        #expect(snapshot.manifest.projectChecksum == DeterministicProjectCodec().checksum(data: snapshot.projectData))
        #expect(try VertexProjectManifestCodec().decode(snapshot.manifestData) == snapshot.manifest)
    }
}

@Test("Older and same-revision divergent pending candidates require a decision")
func uncertainPendingCandidatesRequireDecision() throws {
    let url = pendingTemporaryURL("Uncertain")
    defer { try? FileManager.default.removeItem(at: url) }

    let current = try pendingDocument(name: "Current", revision: 2)
    _ = try VertexProjectPackageStore(
        fixedTimestamp: Date(timeIntervalSince1970: 1_700_000_020)
    ).create(at: url, document: current)
    let layout = try VertexProjectPackageLayout(root: url)

    for pending in [
        try pendingDocument(name: "Older", revision: 1),
        try pendingDocument(name: "Divergent", revision: 2)
    ] {
        let projectData = try DeterministicProjectCodec().encode(pending)
        let manifest = try VertexProjectManifest(
            document: pending,
            projectData: projectData,
            savedAt: Date(timeIntervalSince1970: 1_700_000_030)
        )
        let manifestData = try VertexProjectManifestCodec().encode(manifest)
        let envelope = PendingSaveEnvelope(projectData: projectData, manifestData: manifestData)
        try PendingSaveEnvelopeCodec().encode(envelope).write(to: layout.pendingSaveURL, options: .atomic)

        guard case .pendingDecision(let context) = try VertexProjectPackageStore().open(at: url) else {
            Issue.record("An older or divergent pending pair must require a decision.")
            continue
        }
        #expect(context.currentSnapshot?.document == current)
        try FileManager.default.removeItem(at: layout.pendingSaveURL)
    }
}
