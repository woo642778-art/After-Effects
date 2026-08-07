import Foundation
import Testing
@testable import VertexAI

private func identity(model: Character = "a") throws -> AIJobIdentity {
    try AIJobIdentity(
        sourceFingerprint: "source-fingerprint",
        sourceRangeDigest: String(repeating: "1", count: 64),
        modelDigest: String(repeating: model, count: 64),
        recipeDigest: String(repeating: "2", count: 64),
        outputDigest: String(repeating: "3", count: 64)
    )
}

private func job(identity value: AIJobIdentity) throws -> AIJob {
    try AIJob(
        identity: value,
        recipe: .depth(DepthRecipe()),
        requestedTier: .balanced,
        effectiveTier: .balanced,
        chunks: [
            try AIJobChunk(index: 0, startFrame: 0, endFrameExclusive: 10),
            try AIJobChunk(index: 1, startFrame: 10, endFrameExclusive: 20)
        ]
    )
}

@Test("Completed chunks survive cancellation and resume")
func completedChunksSurviveResume() throws {
    let id = try identity()
    var value = try job(identity: id)
    try value.beginChunk(index: 0)
    try value.completeChunk(index: 0, artifactDigest: String(repeating: "c", count: 64))
    try value.beginChunk(index: 1)
    value.cancel()

    let resumed = try value.resumeCandidate(for: id)
    #expect(resumed.terminalState == nil)
    #expect(resumed.chunks[0].state == .completed)
    #expect(resumed.chunks[0].artifactDigest == String(repeating: "c", count: 64))
    #expect(resumed.chunks[1].state == .pending)
    #expect(resumed.progress == 0.5)
}

@Test("Corrupt or missing completed chunk is invalidated for deterministic reprocessing")
func completedChunkCanBeInvalidated() throws {
    let id = try identity()
    var value = try job(identity: id)
    try value.beginChunk(index: 0)
    try value.completeChunk(index: 0, artifactDigest: String(repeating: "c", count: 64))
    try value.invalidateChunk(index: 0)

    #expect(value.chunks[0].state == .pending)
    #expect(value.chunks[0].artifactDigest == nil)
    #expect(value.nextPendingChunk?.index == 0)
    #expect(value.terminalState == nil)
}

@Test("Resume rejects changed model identity")
func resumeRejectsDifferentIdentity() throws {
    let original = try identity(model: "a")
    let changed = try identity(model: "b")
    let value = try job(identity: original)
    #expect(throws: AIError.self) {
        _ = try value.resumeCandidate(for: changed)
    }
}

@Test("Job store persists verified checkpoint outside project JSON")
func jobStoreRoundTrip() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("vertex-ai-job-tests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let id = try identity()
    var value = try job(identity: id)
    try value.beginChunk(index: 0)
    try value.completeChunk(index: 0, artifactDigest: String(repeating: "d", count: 64))

    let store = AIJobStore(rootURL: root)
    try await store.save(value)
    let loaded = try #require(await store.load(identity: id))
    #expect(loaded.chunks[0].state == .completed)
    #expect(loaded.chunks[1].state == .pending)
    #expect(loaded.id == id.digest)
}
