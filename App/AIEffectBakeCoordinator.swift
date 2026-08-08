import Foundation
import VertexAI
import VertexAICoreML
import VertexAIAVFoundation
import VertexCore
import VertexProject
import VertexProjectPersistence

struct AIEffectBakeProcessedOutput: Sendable {
    var finalVideoURL: URL
    var modelID: String
    var modelDigest: String
    var recipeDigest: String
    var qualityTier: String
    var auxiliaryRelativePath: String?
}

protocol AIEffectBakeProcessing: Sendable {
    func process(
        sourceURL: URL,
        effect: ProjectEffect,
        outputRoot: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> AIEffectBakeProcessedOutput
}


protocol AIEffectBakeOutputValidating: Sendable {
    func validate(sourceURL: URL, outputURL: URL) async throws
}

struct LiveAIEffectBakeOutputValidator: AIEffectBakeOutputValidating {
    func validate(sourceURL: URL, outputURL: URL) async throws {
        guard sourceURL.isFileURL, outputURL.isFileURL else {
            throw AIError.invalidJobState("Bake validation requires file URLs.")
        }
        let source = try await AIVideoSourceInspector.inspect(url: sourceURL)
        let output = try await AIVideoSourceInspector.inspect(url: outputURL)
        guard output.frameCount == source.frameCount else {
            throw AIError.invalidJobState(
                "Baked AI output frame count mismatch: expected \(source.frameCount), got \(output.frameCount)."
            )
        }
        let frameDuration = source.duration.seconds / Double(source.frameCount)
        let tolerance = max(frameDuration, 1.0 / 120.0)
        guard abs(output.duration.seconds - source.duration.seconds) <= tolerance else {
            throw AIError.invalidJobState(
                "Baked AI output duration mismatch: expected \(source.duration.seconds)s, got \(output.duration.seconds)s."
            )
        }
    }
}

struct LiveAIEffectBakeProcessor: AIEffectBakeProcessing {
    func process(sourceURL: URL, effect: ProjectEffect, outputRoot: URL, onProgress: @escaping @Sendable (Double) -> Void) async throws -> AIEffectBakeProcessedOutput {
        let environment = try BundledAIEnvironment.load()
        let (recipe, requestedTier) = try effect.aiRecipeAndTier()
        let model = try environment.modelIdentity(for: recipe, qualityTier: requestedTier)
        let fingerprint = try await Task.detached(priority: .utility) { try AIDigest.sha256(fileAt: sourceURL) }.value
        let result = try await environment.processor.process(AIVideoProcessRequest(
            sourceURL: sourceURL,
            sourceFingerprint: fingerprint,
            recipe: recipe,
            requestedTier: requestedTier,
            capabilityProfile: CoreMLCapabilityProfiler.current(),
            modelID: model.id,
            modelDigest: model.digest,
            outputRoot: outputRoot,
            preserveAudio: true
        )) { progress in onProgress(progress.fraction) }
        return AIEffectBakeProcessedOutput(
            finalVideoURL: result.finalVideoURL,
            modelID: model.id,
            modelDigest: model.digest,
            recipeDigest: try AIRecipeCodec.digest(recipe),
            qualityTier: requestedTier.rawValue,
            auxiliaryRelativePath: result.auxiliaryRelativePath
        )
    }
}

@MainActor
final class AIEffectBakeCoordinator {
    typealias Commit = @MainActor (ProjectAIEffectBakeRegistration) -> Void
    private let processor: any AIEffectBakeProcessing
    private let validator: any AIEffectBakeOutputValidating
    private let commit: Commit
    private(set) var progress: Double = 0

    init(
        processor: any AIEffectBakeProcessing = LiveAIEffectBakeProcessor(),
        validator: any AIEffectBakeOutputValidating = LiveAIEffectBakeOutputValidator(),
        commit: @escaping Commit
    ) {
        self.processor = processor
        self.validator = validator
        self.commit = commit
    }

    func bake(project: ProjectDocument, packageURL: URL, layerID: VertexID, effectID: VertexID) async throws {
        guard let layer = project.layer(id: layerID),
              let effect = layer.effects.first(where: { $0.id == effectID }),
              case .media(let sourceMediaID, _) = layer.source,
              let sourceReference = project.mediaRegistry.first(where: { $0.id == sourceMediaID }),
              let composition = project.composition(id: layer.compositionID),
              let sourceIndex = composition.layerIDs.firstIndex(of: layer.id) else {
            throw ProjectError.invalidOperation("Bake requires a selected media layer and effect.")
        }
        let sourceURL = try resolve(reference: sourceReference, packageURL: packageURL)
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Vertex2", isDirectory: true)
            .appendingPathComponent("AIBakes", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        progress = 0
        let processed = try await processor.process(sourceURL: sourceURL, effect: effect, outputRoot: root) { [weak self] fraction in
            Task { @MainActor in self?.progress = min(max(fraction, 0), 1) }
        }
        try Task.checkCancellation()
        guard FileManager.default.fileExists(atPath: processed.finalVideoURL.path) else {
            throw AIError.inferenceFailed("Baked AI output file is missing.")
        }
        try await validator.validate(sourceURL: sourceURL, outputURL: processed.finalVideoURL)
        try Task.checkCancellation()
        let data = try Data(contentsOf: processed.finalVideoURL, options: [.mappedIfSafe])
        guard !data.isEmpty else { throw AIError.inferenceFailed("Baked AI output file is empty.") }
        let mediaID = VertexID()
        let suffix: String
        let kind: ProjectAIAssetKind
        switch effect.type {
        case .depthMap: suffix = "Depth"; kind = .depth
        case .cutout: suffix = "Cutout"; kind = .matte
        case .upscale: suffix = "Upscale"; kind = .derivedVideo
        case .restore: suffix = "Restore"; kind = .derivedVideo
        }
        let filename = "\(layer.name)-\(suffix).mov"
        let draftMedia = MediaReference(
            id: mediaID, displayName: "\(layer.name) • \(suffix).mov", originalFilename: filename,
            fileSize: Int64(data.count), modificationDate: Date(), contentFingerprint: AIDigest.sha256(data),
            locator: MediaLocator(relativeHint: filename), kind: .video, availabilityStatus: .external
        )
        let embedded = try EmbeddedMediaStore().embed(reference: draftMedia, sourceURL: processed.finalVideoURL, packageURL: packageURL)
        guard let embeddedPath = embedded.locator.embeddedPath,
              embeddedPath.hasPrefix("Media/"),
              !embeddedPath.hasPrefix("/"),
              !embeddedPath.split(separator: "/").contains("..") else {
            throw ProjectError.invalidPackagePath("Baked AI media did not resolve to a package-relative Media path.")
        }
        let recipeReference = ProjectAIRecipeReference(
            task: effect.type.rawValue, modelID: processed.modelID, modelDigest: processed.modelDigest,
            recipeDigest: processed.recipeDigest, qualityTier: processed.qualityTier
        )
        let aiAsset = ProjectAIAsset(kind: kind, sourceMediaID: sourceMediaID, outputMediaID: embedded.id, auxiliaryRelativePath: nil, recipe: recipeReference)
        let layerChannels = layer.animationChannels.filter { if case .layer = $0.property { return true }; return false }
        let bakedLayer = ProjectLayer(
            compositionID: layer.compositionID,
            name: "\(layer.name) • \(suffix)",
            source: .media(mediaID: embedded.id, sourceStartTime: .zero),
            timing: layer.timing,
            transform: layer.transform,
            blendMode: layer.blendMode,
            animationChannels: layerChannels,
            parentLayerID: layer.parentLayerID,
            markers: layer.markers
        )
        let registration = ProjectAIEffectBakeRegistration(
            media: embedded, aiAsset: aiAsset, layer: bakedLayer, insertionIndex: sourceIndex
        )
        _ = try registration.validated(in: project)
        try Task.checkCancellation()
        commit(registration)
        progress = 1
    }

    private func resolve(reference: MediaReference, packageURL: URL) throws -> URL {
        if let embedded = try EmbeddedMediaStore().resolve(reference: reference, packageURL: packageURL) { return embedded }
        if let external = try BookmarkSidecarStore().resolveAndRefreshIfNeeded(mediaID: reference.id, in: packageURL) { return external }
        throw ProjectError.missingMedia(reference.id.rawValue)
    }
}
