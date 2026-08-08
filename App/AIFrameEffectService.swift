import Foundation
import VertexAI
import VertexCore
import VertexMedia
import VertexProject

struct AIFrameEffectRequest: Sendable {
    var key: AIFrameEffectKey
    var effectID: VertexID
    var effect: ProjectEffect
    var qualityTier: AIQualityTier
    var input: PortableImage
}

protocol AIFrameEffectBackend: Sendable {
    func infer(_ request: AIFrameEffectRequest) async throws -> PortableImage
}

actor AIFrameEffectService {
    private struct CacheEnvelope: Codable {
        var keyDigest: String
        var effectID: VertexID
        var image: PortableImage
    }

    private struct MemoryEntry {
        var effectID: VertexID
        var image: PortableImage
        var cost: Int
        var stamp: UInt64
    }

    private struct Job {
        var request: AIFrameEffectRequest
        var priority: AIFramePriority
        var ordinal: UInt64
        var running: Bool
        var waiters: [CheckedContinuation<PortableImage, Error>]
        var task: Task<Void, Never>?
    }

    private let backend: any AIFrameEffectBackend
    private let cacheRoot: URL
    private let maxConcurrent: Int
    private let maxMemoryBytes: Int
    private var memory: [String: MemoryEntry] = [:]
    private var memoryBytes = 0
    private var jobs: [String: Job] = [:]
    private var runningCount = 0
    private var ordinal: UInt64 = 0
    private var stamp: UInt64 = 0
    private var effectStatus: [VertexID: AIFrameEffectStatus] = [:]

    init(
        backend: any AIFrameEffectBackend,
        cacheRoot: URL,
        maxConcurrent: Int = 1,
        maxMemoryBytes: Int = 48 * 1024 * 1024
    ) throws {
        guard maxConcurrent > 0, maxMemoryBytes > 0 else {
            throw AIError.invalidJobState("AI frame service limits must be positive.")
        }
        self.backend = backend
        self.cacheRoot = cacheRoot
        self.maxConcurrent = maxConcurrent
        self.maxMemoryBytes = maxMemoryBytes
        try FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
    }

    static func live(backend: any AIFrameEffectBackend) throws -> AIFrameEffectService {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Vertex2", isDirectory: true)
         .appendingPathComponent("AIFrameEffects", isDirectory: true)
        return try AIFrameEffectService(backend: backend, cacheRoot: root)
    }

    func resolve(request: AIFrameEffectRequest, priority: AIFramePriority) async throws -> PortableImage {
        if let cached = try cachedImage(for: request.key) {
            effectStatus[request.effectID] = .cached
            return cached
        }
        effectStatus[request.effectID] = .computing
        return try await withCheckedThrowingContinuation { continuation in
            enqueue(request: request, priority: priority, continuation: continuation)
        }
    }

    func prefetch(_ requests: [AIFrameEffectRequest], priority: AIFramePriority) async {
        for request in requests {
            Task {
                _ = try? await self.resolve(request: request, priority: priority)
            }
        }
    }

    func cancelObsolete(keeping keys: Set<AIFrameEffectKey>) async {
        let keep = Set(keys.map(\.digest))
        let obsolete = jobs.keys.filter { !keep.contains($0) }
        for digest in obsolete {
            guard let job = jobs.removeValue(forKey: digest) else { continue }
            if job.running {
                job.task?.cancel()
                runningCount = max(0, runningCount - 1)
            }
            for waiter in job.waiters { waiter.resume(throwing: CancellationError()) }
            effectStatus[job.request.effectID] = .stale
        }
        pump()
    }

    func purge(effectID: VertexID) async throws {
        let memoryKeys = memory.compactMap { key, value in value.effectID == effectID ? key : nil }
        for key in memoryKeys {
            if let removed = memory.removeValue(forKey: key) { memoryBytes -= removed.cost }
        }
        for url in try FileManager.default.contentsOfDirectory(at: cacheRoot, includingPropertiesForKeys: nil) where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let envelope = try? JSONDecoder().decode(CacheEnvelope.self, from: data),
                  envelope.effectID == effectID else { continue }
            try FileManager.default.removeItem(at: url)
        }
        effectStatus[effectID] = .stale
    }

    func status(for effectID: VertexID) -> AIFrameEffectStatus {
        effectStatus[effectID] ?? .ready
    }

    func cachedImage(for key: AIFrameEffectKey) throws -> PortableImage? {
        let digest = key.digest
        if var entry = memory[digest] {
            stamp &+= 1
            entry.stamp = stamp
            memory[digest] = entry
            return entry.image
        }
        let url = cacheURL(digest)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let envelope = try JSONDecoder().decode(CacheEnvelope.self, from: data)
        guard envelope.keyDigest == digest else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        insertMemory(digest: digest, effectID: envelope.effectID, image: envelope.image)
        return envelope.image
    }

    private func enqueue(
        request: AIFrameEffectRequest,
        priority: AIFramePriority,
        continuation: CheckedContinuation<PortableImage, Error>
    ) {
        let digest = request.key.digest
        if var existing = jobs[digest] {
            existing.waiters.append(continuation)
            if priority > existing.priority { existing.priority = priority }
            jobs[digest] = existing
        } else {
            ordinal &+= 1
            jobs[digest] = Job(
                request: request,
                priority: priority,
                ordinal: ordinal,
                running: false,
                waiters: [continuation],
                task: nil
            )
        }
        pump()
    }

    private func pump() {
        while runningCount < maxConcurrent {
            let candidates = jobs.filter { !$0.value.running }
            guard let next = candidates.max(by: { lhs, rhs in
                if lhs.value.priority != rhs.value.priority { return lhs.value.priority < rhs.value.priority }
                return lhs.value.ordinal > rhs.value.ordinal
            }) else { return }
            let digest = next.key
            guard var job = jobs[digest] else { return }
            job.running = true
            runningCount += 1
            let request = job.request
            let backend = self.backend
            job.task = Task {
                do {
                    let image = try await backend.infer(request)
                    try Task.checkCancellation()
                    await self.finish(digest: digest, result: .success(image))
                } catch {
                    await self.finish(digest: digest, result: .failure(error))
                }
            }
            jobs[digest] = job
        }
    }

    private func finish(digest: String, result: Result<PortableImage, Error>) {
        guard let job = jobs.removeValue(forKey: digest) else { return }
        if job.running { runningCount = max(0, runningCount - 1) }
        switch result {
        case .success(let image):
            do {
                try writeDisk(digest: digest, effectID: job.request.effectID, image: image)
                insertMemory(digest: digest, effectID: job.request.effectID, image: image)
                effectStatus[job.request.effectID] = .cached
                for waiter in job.waiters { waiter.resume(returning: image) }
            } catch {
                effectStatus[job.request.effectID] = .failed(error.localizedDescription)
                for waiter in job.waiters { waiter.resume(throwing: error) }
            }
        case .failure(let error):
            effectStatus[job.request.effectID] = error is CancellationError ? .stale : .failed(error.localizedDescription)
            for waiter in job.waiters { waiter.resume(throwing: error) }
        }
        pump()
    }

    private func insertMemory(digest: String, effectID: VertexID, image: PortableImage) {
        let cost = image.data.count
        stamp &+= 1
        if let prior = memory.removeValue(forKey: digest) { memoryBytes -= prior.cost }
        memory[digest] = MemoryEntry(effectID: effectID, image: image, cost: cost, stamp: stamp)
        memoryBytes += cost
        while memoryBytes > maxMemoryBytes, let oldest = memory.min(by: { $0.value.stamp < $1.value.stamp }) {
            memory.removeValue(forKey: oldest.key)
            memoryBytes -= oldest.value.cost
        }
    }

    private func writeDisk(digest: String, effectID: VertexID, image: PortableImage) throws {
        let envelope = CacheEnvelope(keyDigest: digest, effectID: effectID, image: image)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(envelope)
        let destination = cacheURL(digest)
        let temporary = cacheRoot.appendingPathComponent(".\(digest).\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: .atomic)
        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.moveItem(at: temporary, to: destination)
    }

    private func cacheURL(_ digest: String) -> URL {
        cacheRoot.appendingPathComponent(digest).appendingPathExtension("json")
    }
}
