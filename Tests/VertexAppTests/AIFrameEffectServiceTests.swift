import Foundation
import Testing
import VertexAI
import VertexCore
import VertexMedia
import VertexProject
@testable import Vertex

private actor RecordingFrameBackend: AIFrameEffectBackend {
    var order: [String] = []
    var counts: [String: Int] = [:]
    let delay: Duration

    init(delay: Duration = .milliseconds(80)) { self.delay = delay }

    func infer(_ request: AIFrameEffectRequest) async throws -> PortableImage {
        try Task.checkCancellation()
        order.append(request.key.effectType)
        counts[request.key.digest, default: 0] += 1
        try await Task.sleep(for: delay)
        try Task.checkCancellation()
        return request.input
    }

    func recordedOrder() -> [String] { order }
    func count(for digest: String) -> Int { counts[digest, default: 0] }
}

private func fixtureImage() throws -> PortableImage {
    try PortableImage(data: Data([1,2,3]), format: .png, pixelSize: VertexSize(width: 2, height: 2))
}

private func request(label: String, parameter: String = "p") throws -> AIFrameEffectRequest {
    let key = try AIFrameEffectKey(
        sourceFingerprint: "source", exactTime: RationalTime(value: 1, timescale: 30),
        modelID: "model", modelDigest: String(repeating: "a", count: 64), effectType: label,
        algorithmVersion: 1, parameterDigest: parameter, qualityTier: "balanced",
        width: 2, height: 2, orientationDigest: "up", colorDigest: "rec709"
    )
    return AIFrameEffectRequest(
        key: key,
        effectID: VertexID(),
        effect: ProjectEffect.makeDefault(.depthMap),
        qualityTier: .balanced,
        input: try fixtureImage()
    )
}

@Test("Current frame overtakes queued background work")
func currentFramePriorityOvertakesQueuedBackground() async throws {
    let backend = RecordingFrameBackend()
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let service = try AIFrameEffectService(backend: backend, cacheRoot: cache, maxConcurrent: 1)
    let first = try request(label: "background-1")
    let second = try request(label: "background-2")
    let current = try request(label: "current")
    let t1 = Task { try await service.resolve(request: first, priority: .background) }
    try await Task.sleep(for: .milliseconds(20))
    let t2 = Task { try await service.resolve(request: second, priority: .background) }
    let t3 = Task { try await service.resolve(request: current, priority: .currentFrame) }
    _ = try await (t1.value, t2.value, t3.value)
    #expect(await backend.recordedOrder() == ["background-1", "current", "background-2"])
}

@Test("Duplicate cache keys coalesce to one inference")
func duplicateRequestsCoalesce() async throws {
    let backend = RecordingFrameBackend()
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let service = try AIFrameEffectService(backend: backend, cacheRoot: cache, maxConcurrent: 1)
    let same = try request(label: "same")
    async let a = service.resolve(request: same, priority: .currentFrame)
    async let b = service.resolve(request: same, priority: .currentFrame)
    _ = try await (a,b)
    #expect(await backend.count(for: same.key.digest) == 1)
}

@Test("Parameter digest change is a cache miss")
func parameterDigestChangeStartsNewInference() async throws {
    let backend = RecordingFrameBackend(delay: .milliseconds(5))
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let service = try AIFrameEffectService(backend: backend, cacheRoot: cache, maxConcurrent: 1)
    let a = try request(label: "depth", parameter: "A")
    let b = try request(label: "depth", parameter: "B")
    _ = try await service.resolve(request: a, priority: .currentFrame)
    _ = try await service.resolve(request: b, priority: .currentFrame)
    #expect(await backend.recordedOrder() == ["depth", "depth"])
}

@Test("Obsolete queued requests are cancelled and never cached")
func obsoleteRequestsAreCancelled() async throws {
    let backend = RecordingFrameBackend(delay: .milliseconds(300))
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let service = try AIFrameEffectService(backend: backend, cacheRoot: cache, maxConcurrent: 1)
    let active = try request(label: "active")
    let obsolete = try request(label: "obsolete")
    let first = Task { try await service.resolve(request: active, priority: .background) }
    try await Task.sleep(for: .milliseconds(20))
    let second = Task { try await service.resolve(request: obsolete, priority: .background) }
    try await Task.sleep(for: .milliseconds(20))
    await service.cancelObsolete(keeping: [active.key])
    do {
        _ = try await second.value
        Issue.record("Expected obsolete request cancellation")
    } catch is CancellationError {}
    _ = try await first.value
    #expect(try await service.cachedImage(for: obsolete.key) == nil)
}
