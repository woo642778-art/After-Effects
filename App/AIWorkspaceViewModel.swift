import Foundation
import SwiftUI
import VertexAI
import VertexAICoreML
import VertexAIAVFoundation

@MainActor
final class AIWorkspaceViewModel: ObservableObject {
    enum Tool: String, CaseIterable, Identifiable {
        case depth = "Depth Map"
        case cutout = "Cutout"
        case upscale = "Upscale"
        case restoration = "Restore"
        var id: String { rawValue }
    }

    enum State: Equatable {
        case idle
        case ready
        case running
        case completed
        case failed(String)
        case cancelled
    }

    @Published var tool: Tool = .depth
    @Published var requestedTier: AIQualityTier = .balanced
    @Published private(set) var effectiveTier: AIQualityTier = .balanced
    @Published private(set) var fallbackReason: String?
    @Published private(set) var sourceURL: URL?
    @Published private(set) var resultURL: URL?
    @Published private(set) var resultDescriptor: AIResultDescriptor?
    @Published private(set) var state: State = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var progressText = ""
    @Published private(set) var activeModel = "Not loaded"

    // Depth
    @Published var depthInvert = false
    @Published var depthSmoothing: Double = 0.08
    @Published var depthEdgeRefinement: Double = 0.18
    @Published var depthTemporalSmoothing: Double = 0.12

    // Cutout
    @Published var cutoutMode: CutoutMode = .foregroundFast
    @Published var cutoutFeather: Double = 0.04
    @Published var cutoutEdgeCleanup: Double = 0.2
    @Published var cutoutTemporalSmoothing: Double = 0.15
    @Published var promptX: Double = 0.5
    @Published var promptY: Double = 0.5

    // Upscale
    @Published var upscaleProfile: UpscaleProfile = .general
    @Published var upscaleScale: Double = 2
    @Published var upscaleOverlap: Double = 32

    // Restoration
    @Published var denoise: Double = 0.45
    @Published var artifactRemoval: Double = 0.25
    @Published var detailRecovery: Double = 0.25

    private var processingTask: Task<Void, Never>?

    var sourceName: String {
        sourceURL?.lastPathComponent ?? "Choose a video"
    }

    var canStart: Bool {
        sourceURL != nil && processingTask == nil
    }

    var recipe: AITaskRecipe {
        switch tool {
        case .depth:
            .depth(DepthRecipe(
                invert: depthInvert,
                nearValue: 0,
                farValue: 1,
                smoothing: Float(depthSmoothing),
                edgeRefinement: Float(depthEdgeRefinement),
                temporalSmoothing: Float(depthTemporalSmoothing)
            ))
        case .cutout:
            .cutout(CutoutRecipe(
                mode: cutoutMode,
                prompts: cutoutMode == .promptQuality
                    ? [.point(x: promptX, y: promptY, foreground: true)]
                    : [],
                feather: Float(cutoutFeather),
                edgeCleanup: Float(cutoutEdgeCleanup),
                temporalSmoothing: Float(cutoutTemporalSmoothing)
            ))
        case .upscale:
            .upscale(UpscaleRecipe(
                profile: upscaleProfile,
                scale: upscaleScale,
                tileOverlap: Int(upscaleOverlap.rounded())
            ))
        case .restoration:
            .restoration(RestorationRecipe(
                denoise: Float(denoise),
                deblur: 0,
                artifactRemoval: Float(artifactRemoval),
                detailRecovery: Float(detailRecovery),
                faceRestoration: false
            ))
        }
    }

    func chooseSource(_ url: URL) {
        cancel()
        sourceURL = url
        resultURL = nil
        resultDescriptor = nil
        progress = 0
        progressText = ""
        activeModel = "Not loaded"
        state = .ready
    }

    func start() {
        guard let sourceURL, processingTask == nil else { return }
        resultURL = nil
        resultDescriptor = nil
        progress = 0
        fallbackReason = nil
        state = .running

        let selectedRecipe = recipe
        let requested = requestedTier
        processingTask = Task { [weak self] in
            guard let self else { return }
            let securityScoped = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if securityScoped { sourceURL.stopAccessingSecurityScopedResource() }
                Task { @MainActor [weak self] in self?.processingTask = nil }
            }
            do {
                let environment = try BundledAIEnvironment.load()
                let capability = CoreMLCapabilityProfiler.current()
                let decision = AIQualityPolicy.decide(requested: requested, profile: capability)
                self.effectiveTier = decision.effective
                self.fallbackReason = decision.fallbackReason
                let model = try environment.modelIdentity(for: selectedRecipe, qualityTier: decision.effective)
                self.activeModel = model.id

                let sourceFingerprint = try await Task.detached(priority: .utility) {
                    try AIDigest.sha256(fileAt: sourceURL)
                }.value
                let outputRoot = try Self.aiOutputRoot()
                let request = AIVideoProcessRequest(
                    sourceURL: sourceURL,
                    sourceFingerprint: sourceFingerprint,
                    recipe: selectedRecipe,
                    requestedTier: requested,
                    capabilityProfile: capability,
                    modelID: model.id,
                    modelDigest: model.digest,
                    outputRoot: outputRoot,
                    framesPerChunk: decision.effective == .preview ? 60 : 120,
                    preserveAudio: true
                )
                let result = try await environment.processor.process(request) { [weak self] progress in
                    Task { @MainActor in
                        guard let self else { return }
                        self.progress = progress.fraction
                        self.progressText = "Chunk \(progress.chunkIndex + 1)/\(progress.chunkCount) · \(progress.completedFrames)/\(progress.totalFrames) frames"
                    }
                }
                try Task.checkCancellation()
                self.resultURL = result.finalVideoURL
                self.resultDescriptor = result.result
                self.progress = 1
                self.progressText = "Completed \(result.result.frameCount) frames"
                self.state = .completed
            } catch is CancellationError {
                self.state = .cancelled
                self.progressText = "Cancelled — verified chunks were kept for resume"
            } catch AIError.cancelled {
                self.state = .cancelled
                self.progressText = "Cancelled — verified chunks were kept for resume"
            } catch {
                self.state = .failed(error.localizedDescription)
                self.progressText = error.localizedDescription
            }
        }
    }

    func cancel() {
        processingTask?.cancel()
    }

    func clearResult() {
        resultURL = nil
        resultDescriptor = nil
        progress = 0
        progressText = ""
        if sourceURL != nil { state = .ready } else { state = .idle }
    }

    private static func aiOutputRoot() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let destination = root
            .appendingPathComponent("AfterEffects", isDirectory: true)
            .appendingPathComponent("OfflineAI", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        return destination
    }
}
