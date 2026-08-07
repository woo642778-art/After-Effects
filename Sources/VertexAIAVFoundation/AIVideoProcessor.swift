import Foundation
@preconcurrency import AVFoundation
import VertexAI
import VertexAICoreML

public struct AIVideoProcessRequest: Sendable {
    public let sourceURL: URL
    public let sourceFingerprint: String
    public let recipe: AITaskRecipe
    public let requestedTier: AIQualityTier
    public let capabilityProfile: AICapabilityProfile
    public let modelID: String
    public let modelDigest: String
    public let outputRoot: URL
    public let framesPerChunk: Int
    public let preserveAudio: Bool

    public init(
        sourceURL: URL,
        sourceFingerprint: String,
        recipe: AITaskRecipe,
        requestedTier: AIQualityTier,
        capabilityProfile: AICapabilityProfile,
        modelID: String,
        modelDigest: String,
        outputRoot: URL,
        framesPerChunk: Int = 120,
        preserveAudio: Bool = true
    ) {
        self.sourceURL = sourceURL
        self.sourceFingerprint = sourceFingerprint
        self.recipe = recipe
        self.requestedTier = requestedTier
        self.capabilityProfile = capabilityProfile
        self.modelID = modelID
        self.modelDigest = modelDigest
        self.outputRoot = outputRoot
        self.framesPerChunk = framesPerChunk
        self.preserveAudio = preserveAudio
    }
}

public struct AIVideoProgress: Equatable, Sendable {
    public let completedFrames: Int64
    public let totalFrames: Int64
    public let chunkIndex: Int
    public let chunkCount: Int

    public var fraction: Double {
        guard totalFrames > 0 else { return 0 }
        return min(max(Double(completedFrames) / Double(totalFrames), 0), 1)
    }
}

public struct AIVideoProcessResult: Sendable {
    public let job: AIJob
    public let result: AIResultDescriptor
    public let finalVideoURL: URL
    public let auxiliaryRelativePath: String?
}

public final class AIVideoProcessor: @unchecked Sendable {
    private let registry: AIModelRegistry
    private let frameProcessor: AIFrameProcessor
    private let finalizer = AIVideoFinalizer()

    public init(registry: AIModelRegistry) {
        self.registry = registry
        self.frameProcessor = AIFrameProcessor(registry: registry)
    }

    public func process(
        _ request: AIVideoProcessRequest,
        onProgress: @escaping @Sendable (AIVideoProgress) -> Void = { _ in }
    ) async throws -> AIVideoProcessResult {
        _ = try request.recipe.validated()
        guard !request.sourceFingerprint.isEmpty, request.modelDigest.count == 64 else {
            throw AIError.invalidJobState("AI video request requires a source fingerprint and model SHA-256.")
        }
        let sourceInfo = try await AIVideoSourceInspector.inspect(url: request.sourceURL)
        let quality = AIQualityPolicy.decide(requested: request.requestedTier, profile: request.capabilityProfile)
        let recipeDigest = try AIRecipeCodec.digest(request.recipe)
        let dimensions = try outputDimensions(sourceInfo: sourceInfo, recipe: request.recipe)
        let outputIdentity = "mov|\(dimensions.width)x\(dimensions.height)|audio:\(request.preserveAudio)|task:\(taskName(request.recipe))"
        let identity = try AIJobIdentity(
            sourceFingerprint: request.sourceFingerprint,
            sourceRangeDigest: sourceInfo.sourceRangeDigest,
            modelDigest: request.modelDigest,
            recipeDigest: recipeDigest,
            outputDigest: AIDigest.sha256(Data(outputIdentity.utf8))
        )

        let checkpointRoot = request.outputRoot.appendingPathComponent("JobCheckpoints", isDirectory: true)
        let jobStore = AIJobStore(rootURL: checkpointRoot)
        let jobRoot = request.outputRoot
            .appendingPathComponent("Chunks", isDirectory: true)
            .appendingPathComponent(identity.digest, isDirectory: true)
        let artifactStore = AIChunkArtifactStore(jobRoot: jobRoot)
        var job: AIJob
        if let stored = try await jobStore.load(identity: identity) {
            job = stored
        } else {
            job = try AIJob(
                identity: identity,
                recipe: request.recipe,
                requestedTier: request.requestedTier,
                effectiveTier: quality.effective,
                fallbackReason: quality.fallbackReason,
                chunks: try AIVideoChunkPlan.make(
                    frameCount: sourceInfo.frameCount,
                    framesPerChunk: request.framesPerChunk
                )
            )
        }

        for index in job.chunks.indices where job.chunks[index].state == .completed {
            if try !artifactStore.verify(chunk: job.chunks[index]) {
                try job.invalidateChunk(index: index)
                artifactStore.remove(chunkIndex: index)
            }
        }
        if job.terminalState == .completed, job.chunks.contains(where: { $0.state != .completed }) {
            // Defensive consistency: invalidation above should already clear completion.
            throw AIError.invalidJobState("AI job completion state disagrees with chunk state.")
        }
        try await jobStore.save(job)

        if job.terminalState != .completed {
            do {
                try await processPendingChunks(
                    request: request,
                    sourceInfo: sourceInfo,
                    dimensions: dimensions,
                    artifactStore: artifactStore,
                    jobStore: jobStore,
                    job: &job,
                    onProgress: onProgress
                )
            } catch AIError.cancelled {
                job.cancel()
                try? await jobStore.save(job)
                throw AIError.cancelled
            }
        }

        guard job.terminalState == .completed else {
            throw AIError.invalidJobState("AI video processing ended without completing all chunks.")
        }
        let manifests = try artifactStore.manifests(for: job)
        let resultsRoot = request.outputRoot.appendingPathComponent("Results", isDirectory: true)
        try FileManager.default.createDirectory(at: resultsRoot, withIntermediateDirectories: true)
        let finalVideo = resultsRoot.appendingPathComponent("\(identity.digest).mov")
        try await finalizer.finalize(
            sourceURL: request.sourceURL,
            chunkManifests: manifests,
            jobRoot: jobRoot,
            destinationURL: finalVideo,
            preserveAudio: request.preserveAudio && sourceInfo.hasAudio
        )
        let outputSHA = try AIDigest.sha256(fileAt: finalVideo)
        let relativeVideoPath = relativePath(of: finalVideo, under: request.outputRoot)
        let auxiliary = try buildDepthManifestIfNeeded(
            recipe: request.recipe,
            manifests: manifests,
            jobRoot: jobRoot,
            resultsRoot: resultsRoot,
            outputRoot: request.outputRoot,
            jobDigest: identity.digest
        )
        let descriptor = try AIResultDescriptor(
            kind: resultKind(request.recipe),
            sourceFingerprint: request.sourceFingerprint,
            jobDigest: identity.digest,
            outputRelativePath: relativeVideoPath,
            outputSHA256: outputSHA,
            width: dimensions.width,
            height: dimensions.height,
            frameCount: sourceInfo.frameCount,
            highPrecision: auxiliary != nil
        )
        return AIVideoProcessResult(
            job: job,
            result: descriptor,
            finalVideoURL: finalVideo,
            auxiliaryRelativePath: auxiliary
        )
    }

    private func processPendingChunks(
        request: AIVideoProcessRequest,
        sourceInfo: AIVideoSourceInfo,
        dimensions: (width: Int, height: Int),
        artifactStore: AIChunkArtifactStore,
        jobStore: AIJobStore,
        job: inout AIJob,
        onProgress: @escaping @Sendable (AIVideoProgress) -> Void
    ) async throws {
        let asset = AVURLAsset(url: request.sourceURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { throw AIError.invalidJobState("AI source lost its video track.") }
        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let assetDuration = try await asset.load(.duration)
        let nominalFrameRate = try await track.load(.nominalFrameRate)
        let transformer = try AIOrientedFrameTransformer(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform
        )
        guard transformer.outputWidth == sourceInfo.width,
              transformer.outputHeight == sourceInfo.height else {
            throw AIError.invalidJobState("AI source orientation changed between inspection and processing.")
        }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw AIError.invalidJobState("Could not attach AI frame reader.") }
        reader.add(output)
        guard reader.startReading() else {
            throw AIError.invalidJobState("AI frame reader could not start: \(reader.error?.localizedDescription ?? "unknown error")")
        }

        var frameIndex: Int64 = 0
        var chunkCursor = 0
        var currentWriter: AIFrameWriter?
        var depthWriter: AIDepthChunkWriter?
        var currentChunkIndex: Int?
        var currentChunkOutputFrames: Int64 = 0
        var temporalState = AIFrameTemporalState()
        let sceneDetector = AISceneBoundaryDetector()
        var pending: PendingOutputFrame?

        func isCancelled() -> Bool { Task<Never, Never>.isCancelled }

        func chunkForFrame(_ index: Int64) -> Int? {
            while chunkCursor < job.chunks.count && index >= job.chunks[chunkCursor].endFrameExclusive {
                chunkCursor += 1
            }
            guard chunkCursor < job.chunks.count,
                  index >= job.chunks[chunkCursor].startFrame,
                  index < job.chunks[chunkCursor].endFrameExclusive else { return nil }
            return chunkCursor
        }

        func closeCurrentChunk() async throws {
            guard let index = currentChunkIndex, let writer = currentWriter else { return }
            try await writer.finish()
            try depthWriter?.finish()
            let digest = try artifactStore.commit(
                chunkIndex: index,
                frameCount: currentChunkOutputFrames,
                hasDepth: depthWriter != nil
            )
            try job.completeChunk(index: index, artifactDigest: digest)
            try await jobStore.save(job)
            currentWriter = nil
            depthWriter = nil
            currentChunkIndex = nil
            currentChunkOutputFrames = 0
            temporalState.reset()
            sceneDetector.reset()
            let completedFrames = job.chunks
                .filter { $0.state == .completed }
                .reduce(Int64.zero) { $0 + ($1.endFrameExclusive - $1.startFrame) }
            onProgress(AIVideoProgress(
                completedFrames: completedFrames,
                totalFrames: sourceInfo.frameCount,
                chunkIndex: index,
                chunkCount: job.chunks.count
            ))
        }

        do {
            while let sample = output.copyNextSampleBuffer() {
                if isCancelled() { throw AIError.cancelled }
                let pts = CMSampleBufferGetPresentationTimeStamp(sample)
                guard pts.isNumeric else { throw AIError.invalidJobState("Video frame has invalid PTS.") }

                if let previous = pending {
                    let duration = CMTimeSubtract(pts, previous.presentationTime)
                    guard duration.isNumeric, duration > .zero else {
                        throw AIError.invalidJobState("Video frame PTS must increase monotonically for Phase 7 AI processing.")
                    }
                    try currentWriter?.append(
                        pixelBuffer: previous.pixelBuffer,
                        presentationTime: previous.presentationTime,
                        duration: duration,
                        shouldCancel: isCancelled
                    )
                    currentChunkOutputFrames += 1
                    pending = nil
                    if previous.isLastFrameInChunk { try await closeCurrentChunk() }
                }

                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
                    throw AIError.invalidJobState("Decoded AI source sample has no pixel buffer.")
                }
                guard let jobChunkIndex = chunkForFrame(frameIndex) else {
                    throw AIError.invalidJobState("Decoded frame index does not map to the prepared AI job.")
                }
                let chunk = job.chunks[jobChunkIndex]
                if chunk.state == .completed {
                    frameIndex += 1
                    continue
                }

                if currentChunkIndex == nil {
                    guard chunk.state == .pending || chunk.state == .failed else {
                        throw AIError.invalidJobState("Pending video processing reached a non-runnable chunk state.")
                    }
                    artifactStore.remove(chunkIndex: jobChunkIndex)
                    try job.beginChunk(index: jobChunkIndex)
                    try await jobStore.save(job)
                    currentChunkIndex = jobChunkIndex
                    currentWriter = try AIFrameWriter(
                        outputURL: artifactStore.videoURL(chunkIndex: jobChunkIndex),
                        width: dimensions.width,
                        height: dimensions.height,
                        recipe: request.recipe
                    )
                    if case .depth = request.recipe {
                        depthWriter = try AIDepthChunkWriter(
                            outputURL: artifactStore.depthURL(chunkIndex: jobChunkIndex),
                            width: sourceInfo.width,
                            height: sourceInfo.height
                        )
                    }
                    temporalState.reset()
                    sceneDetector.reset()
                }
                guard currentChunkIndex == jobChunkIndex else {
                    throw AIError.invalidJobState("AI chunk writer and decoded frame chunk diverged.")
                }

                let oriented = try transformer.transform(pixelBuffer)
                if try sceneDetector.isSceneBoundary(pixelBuffer: oriented) {
                    temporalState.reset()
                }
                let processed = try frameProcessor.process(
                    source: oriented,
                    recipe: request.recipe,
                    effectiveTier: job.effectiveTier,
                    temporalState: &temporalState
                )
                if let depth = processed.highPrecisionDepth {
                    try depthWriter?.append(frame: depth, presentationTime: pts)
                }
                let lastInChunk = frameIndex + 1 == chunk.endFrameExclusive
                pending = PendingOutputFrame(
                    pixelBuffer: processed.pixelBuffer,
                    presentationTime: pts,
                    originalDuration: CMSampleBufferGetDuration(sample),
                    isLastFrameInChunk: lastInChunk
                )
                frameIndex += 1
            }

            if let previous = pending {
                var duration = CMTimeSubtract(assetDuration, previous.presentationTime)
                if !duration.isNumeric || duration <= .zero {
                    if previous.originalDuration.isNumeric, previous.originalDuration > .zero {
                        duration = previous.originalDuration
                    } else {
                        let rate = max(1, Int32(nominalFrameRate.rounded()))
                        duration = CMTime(value: 1, timescale: rate)
                    }
                }
                try currentWriter?.append(
                    pixelBuffer: previous.pixelBuffer,
                    presentationTime: previous.presentationTime,
                    duration: duration,
                    shouldCancel: isCancelled
                )
                currentChunkOutputFrames += 1
                pending = nil
                try await closeCurrentChunk()
            }
        } catch {
            let failedChunk = currentChunkIndex
            currentWriter?.cancelAndDelete()
            depthWriter?.cancelAndDelete()
            if let failedChunk, job.chunks[failedChunk].state == .processing {
                try? job.failChunk(index: failedChunk, message: String(describing: error))
                try? await jobStore.save(job)
                artifactStore.remove(chunkIndex: failedChunk)
            }
            reader.cancelReading()
            if error is CancellationError || (error as? AIError) == .cancelled || isCancelled() {
                throw AIError.cancelled
            }
            throw error
        }

        guard reader.status == .completed, frameIndex == sourceInfo.frameCount else {
            throw AIError.invalidJobState(
                "AI frame scan ended at \(frameIndex)/\(sourceInfo.frameCount): \(reader.error?.localizedDescription ?? "unknown error")"
            )
        }
    }

    private func outputDimensions(
        sourceInfo: AIVideoSourceInfo,
        recipe: AITaskRecipe
    ) throws -> (width: Int, height: Int) {
        switch recipe {
        case .upscale(let upscale):
            let plan = try UpscaleOutputPlan.resolve(
                sourceWidth: sourceInfo.width,
                sourceHeight: sourceInfo.height,
                recipe: upscale,
                nativeScale: 4
            )
            return (plan.finalWidth, plan.finalHeight)
        default:
            return (sourceInfo.width, sourceInfo.height)
        }
    }

    private func buildDepthManifestIfNeeded(
        recipe: AITaskRecipe,
        manifests: [AIChunkArtifactManifest],
        jobRoot: URL,
        resultsRoot: URL,
        outputRoot: URL,
        jobDigest: String
    ) throws -> String? {
        guard case .depth = recipe else { return nil }
        let depthChunks = manifests.compactMap { manifest -> [String: String]? in
            guard let filename = manifest.depthFilename,
                  let digest = manifest.depthSHA256 else { return nil }
            return ["filename": filename, "sha256": digest]
        }
        guard depthChunks.count == manifests.count else {
            throw AIError.outputVerificationFailed("High-precision depth manifest is missing one or more chunk sidecars.")
        }
        let payload: [String: Any] = [
            "formatVersion": 1,
            "jobDigest": jobDigest,
            "storageRoot": relativePath(of: jobRoot, under: outputRoot),
            "chunks": depthChunks
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .prettyPrinted])
        let url = resultsRoot.appendingPathComponent("\(jobDigest)-depth.json")
        try data.write(to: url, options: .atomic)
        return relativePath(of: url, under: outputRoot)
    }

    private func relativePath(of url: URL, under root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        if filePath.hasPrefix(rootPath + "/") {
            return String(filePath.dropFirst(rootPath.count + 1))
        }
        return url.lastPathComponent
    }

    private func taskName(_ recipe: AITaskRecipe) -> String {
        switch recipe {
        case .depth: "depth"
        case .cutout: "cutout"
        case .upscale: "upscale"
        case .restoration: "restoration"
        }
    }

    private func resultKind(_ recipe: AITaskRecipe) -> AIResultKind {
        switch recipe {
        case .depth: .depth
        case .cutout: .matte
        case .upscale, .restoration: .derivedVideo
        }
    }
}

#if canImport(CoreVideo)
import CoreVideo

private struct PendingOutputFrame {
    let pixelBuffer: CVPixelBuffer
    let presentationTime: CMTime
    let originalDuration: CMTime
    let isLastFrameInChunk: Bool
}
#endif
