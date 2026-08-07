from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def write(p,t): q=ROOT/p; q.parent.mkdir(parents=True,exist_ok=True); q.write_text(t)

write('App/AIFrameEffectService.swift', r'''import Foundation
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
''')

write('App/BundledAIEnvironment+FrameEffects.swift', r'''import CoreImage
import CoreVideo
import Foundation
import UIKit
import VertexAI
import VertexAICoreML
import VertexMedia
import VertexProject

extension ProjectEffect {
    func aiRecipeAndTier() throws -> (AITaskRecipe, AIQualityTier) {
        func scalar(_ id: String) throws -> Double {
            guard case .scalar(let value)? = parameter(id: id)?.value else { throw AIError.invalidRecipe("Missing scalar parameter \(id).") }
            return value
        }
        func boolean(_ id: String) throws -> Bool {
            guard case .boolean(let value)? = parameter(id: id)?.value else { throw AIError.invalidRecipe("Missing boolean parameter \(id).") }
            return value
        }
        func text(_ id: String) throws -> String {
            guard case .text(let value)? = parameter(id: id)?.value else { throw AIError.invalidRecipe("Missing text parameter \(id).") }
            return value
        }
        func integer(_ id: String) throws -> Int {
            guard case .integer(let value)? = parameter(id: id)?.value else { throw AIError.invalidRecipe("Missing integer parameter \(id).") }
            return value
        }
        let qualityText: String
        switch type {
        case .depthMap: qualityText = try text(DepthMapParameterID.quality)
        case .cutout: qualityText = try text(CutoutParameterID.quality)
        case .upscale: qualityText = try text(UpscaleParameterID.quality)
        case .restore: qualityText = try text(RestorationParameterID.quality)
        }
        let tier: AIQualityTier = qualityText == "preview" ? .preview : (qualityText == "quality" ? .maxQuality : .balanced)
        switch type {
        case .depthMap:
            return (.depth(DepthRecipe(
                invert: try boolean(DepthMapParameterID.invert),
                nearValue: Float(try scalar(DepthMapParameterID.near)),
                farValue: Float(try scalar(DepthMapParameterID.far)),
                smoothing: Float(try scalar(DepthMapParameterID.smoothing)),
                edgeRefinement: Float(try scalar(DepthMapParameterID.edgeRefinement)),
                temporalSmoothing: Float(try scalar(DepthMapParameterID.temporalSmoothing))
            )), tier)
        case .cutout:
            let mode = CutoutMode(rawValue: try text(CutoutParameterID.mode)) ?? .foregroundFast
            let prompts: [CutoutPrompt] = mode == .promptQuality ? [.point(x: try scalar(CutoutParameterID.promptX), y: try scalar(CutoutParameterID.promptY), foreground: true)] : []
            return (.cutout(CutoutRecipe(
                mode: mode, prompts: prompts,
                feather: Float(try scalar(CutoutParameterID.feather)),
                edgeCleanup: Float(try scalar(CutoutParameterID.edgeCleanup)),
                temporalSmoothing: Float(try scalar(CutoutParameterID.temporalSmoothing))
            )), tier)
        case .upscale:
            let profile = UpscaleProfile(rawValue: try text(UpscaleParameterID.profile)) ?? .general
            return (.upscale(UpscaleRecipe(profile: profile, scale: try scalar(UpscaleParameterID.scale), tileOverlap: try integer(UpscaleParameterID.tileOverlap))), tier)
        case .restore:
            return (.restoration(RestorationRecipe(
                denoise: Float(try scalar(RestorationParameterID.denoise)),
                deblur: Float(try scalar(RestorationParameterID.deblur)),
                artifactRemoval: Float(try scalar(RestorationParameterID.artifactRemoval)),
                detailRecovery: Float(try scalar(RestorationParameterID.detailRecovery)),
                faceRestoration: try boolean(RestorationParameterID.faceRestoration)
            )), tier)
        }
    }
}

actor BundledAIFrameEffectBackend: AIFrameEffectBackend {
    private let environment: BundledAIEnvironment
    private let depth: DepthInferenceEngine
    private let cutout = VisionCutoutEngine()
    private let upscale: UpscaleInferenceEngine
    private let restoration: RestorationInferenceEngine
    private var previousDepth: [VertexID: DepthFrame] = [:]
    private var previousMask: [VertexID: CutoutMaskFrame] = [:]
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    init(environment: BundledAIEnvironment) {
        self.environment = environment
        depth = DepthInferenceEngine(registry: environment.registry)
        upscale = UpscaleInferenceEngine(registry: environment.registry)
        restoration = RestorationInferenceEngine(registry: environment.registry)
    }

    func infer(_ request: AIFrameEffectRequest) async throws -> PortableImage {
        try Task.checkCancellation()
        let (recipe, tier) = try request.effect.aiRecipeAndTier()
        let input = try pixelBuffer(from: request.input)
        let output: CVPixelBuffer
        switch recipe {
        case .depth(let value):
            let result = try depth.infer(pixelBuffer: input, recipe: value, previousFrame: previousDepth[request.effectID])
            previousDepth[request.effectID] = result
            output = try depthPreview(result)
        case .cutout(let value):
            let mask = try cutout.infer(pixelBuffer: input, recipe: value, previousFrame: previousMask[request.effectID])
            previousMask[request.effectID] = mask
            output = try applyingAlpha(mask, to: input)
        case .upscale(let value):
            output = try upscale.infer(pixelBuffer: input, recipe: value)
        case .restoration(let value):
            output = try restoration.infer(pixelBuffer: input, recipe: value, qualityTier: tier)
        }
        try Task.checkCancellation()
        return try portableImage(from: output)
    }

    private func pixelBuffer(from image: PortableImage) throws -> CVPixelBuffer {
        guard let uiImage = UIImage(data: image.data), let cgImage = uiImage.cgImage else {
            throw AIError.inferenceFailed("AI frame input is not a decodable image.")
        }
        let width = cgImage.width, height = cgImage.height
        let buffer = try makeBGRA(width: width, height: height)
        ciContext.render(CIImage(cgImage: cgImage), to: buffer, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: CGColorSpaceCreateDeviceRGB())
        return buffer
    }

    private func portableImage(from buffer: CVPixelBuffer) throws -> PortableImage {
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        guard let cg = ciContext.createCGImage(CIImage(cvPixelBuffer: buffer), from: CGRect(x: 0, y: 0, width: width, height: height)),
              let data = UIImage(cgImage: cg).pngData() else {
            throw AIError.inferenceFailed("AI frame output could not be encoded as PNG.")
        }
        return try PortableImage(data: data, format: .png, pixelSize: VertexSize(width: Double(width), height: Double(height)))
    }

    private func depthPreview(_ frame: DepthFrame) throws -> CVPixelBuffer {
        let buffer = try makeBGRA(width: frame.width, height: frame.height)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw AIError.inferenceFailed("Depth preview allocation failed.") }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<frame.height {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
            for x in 0..<frame.width {
                let v = UInt8((min(max(frame.values[y * frame.width + x], 0), 1) * 255).rounded())
                let o = x * 4; row[o] = v; row[o+1] = v; row[o+2] = v; row[o+3] = 255
            }
        }
        return buffer
    }

    private func applyingAlpha(_ mask: CutoutMaskFrame, to source: CVPixelBuffer) throws -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(source), height = CVPixelBufferGetHeight(source)
        guard mask.width == width, mask.height == height else { throw AIError.inferenceFailed("Cutout mask does not align to source.") }
        let output = try makeBGRA(width: width, height: height)
        CVPixelBufferLockBaseAddress(source, .readOnly); CVPixelBufferLockBaseAddress(output, [])
        defer { CVPixelBufferUnlockBaseAddress(output, []); CVPixelBufferUnlockBaseAddress(source, .readOnly) }
        guard let src = CVPixelBufferGetBaseAddress(source), let dst = CVPixelBufferGetBaseAddress(output) else { throw AIError.inferenceFailed("Cutout pixels unavailable.") }
        let sr = CVPixelBufferGetBytesPerRow(source), dr = CVPixelBufferGetBytesPerRow(output)
        for y in 0..<height {
            let s = src.advanced(by: y*sr).assumingMemoryBound(to: UInt8.self), d = dst.advanced(by: y*dr).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width { let o=x*4; d[o]=s[o]; d[o+1]=s[o+1]; d[o+2]=s[o+2]; d[o+3]=UInt8((mask.alpha[y*width+x]*255).rounded()) }
        }
        return output
    }

    private func makeBGRA(width: Int, height: Int) throws -> CVPixelBuffer {
        var result: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferCGImageCompatibilityKey: true,
             kCVPixelBufferCGBitmapContextCompatibilityKey: true,
             kCVPixelBufferMetalCompatibilityKey: true,
             kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &result)
        guard status == kCVReturnSuccess, let result else { throw AIError.inferenceFailed("Could not allocate BGRA frame (\(status)).") }
        return result
    }
}
''')

write('App/CompositionEffectResolverAdapter.swift', r'''import Foundation
import VertexAI
import VertexComposition
import VertexMedia
import VertexProject

struct CompositionEffectResolverAdapter: CompositionEffectResolver {
    let service: AIFrameEffectService
    let environment: BundledAIEnvironment

    func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage {
        let (recipe, requestedTier) = try request.effect.aiRecipeAndTier()
        let identity = try environment.modelIdentity(for: recipe, qualityTier: requestedTier)
        let parameterDigest = try AIRecipeCodec.digest(recipe)
        let sourceFingerprint = AIDigest.sha256(request.input.data)
        let key = try AIFrameEffectKey(
            sourceFingerprint: sourceFingerprint,
            exactTime: request.exactSourceTime,
            modelID: identity.id,
            modelDigest: identity.digest,
            effectType: request.effect.type.rawValue,
            algorithmVersion: 1,
            parameterDigest: parameterDigest,
            qualityTier: requestedTier.rawValue,
            width: Int(request.targetSize.width.rounded()),
            height: Int(request.targetSize.height.rounded()),
            orientationDigest: "upright",
            colorDigest: "rec709"
        )
        let frameRequest = AIFrameEffectRequest(key: key, effectID: request.effect.id, effect: request.effect, qualityTier: requestedTier, input: request.input)
        return try await service.resolve(request: frameRequest, priority: .currentFrame)
    }
}
''')
print('Task 8 GREEN implementation applied')
