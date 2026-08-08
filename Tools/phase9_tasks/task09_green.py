from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def read(p): return (ROOT/p).read_text()
def write(p,t): q=ROOT/p; q.parent.mkdir(parents=True,exist_ok=True); q.write_text(t)

# Registration model.
p='Sources/VertexProject/ProjectAIAsset.swift'; t=read(p)
addition=r'''

public struct ProjectAIEffectBakeRegistration: Codable, Equatable, Sendable {
    public var media: MediaReference
    public var aiAsset: ProjectAIAsset
    public var layer: ProjectLayer
    public var insertionIndex: Int

    public init(media: MediaReference, aiAsset: ProjectAIAsset, layer: ProjectLayer, insertionIndex: Int) {
        self.media = media
        self.aiAsset = aiAsset
        self.layer = layer
        self.insertionIndex = insertionIndex
    }

    public func validated(in document: ProjectDocument) throws -> Self {
        _ = try media.validated()
        guard insertionIndex >= 0,
              let composition = document.composition(id: layer.compositionID),
              insertionIndex <= composition.layerIDs.count else {
            throw ProjectError.invalidValue("Baked AI layer insertion index is invalid.")
        }
        guard document.mediaRegistry.allSatisfy({ $0.id != media.id }),
              document.aiAssetRegistry.allSatisfy({ $0.id != aiAsset.id }),
              document.layerRegistry.allSatisfy({ $0.id != layer.id }) else {
            throw ProjectError.duplicateIdentity("baked AI registration")
        }
        guard case .media(let outputMediaID, _) = layer.source, outputMediaID == media.id,
              aiAsset.outputMediaID == media.id,
              document.mediaRegistry.contains(where: { $0.id == aiAsset.sourceMediaID }) else {
            throw ProjectError.invalidValue("Baked AI registration media relationships are inconsistent.")
        }
        var candidate = document
        candidate.mediaRegistry.append(media)
        candidate.aiAssetRegistry.append(aiAsset)
        candidate.layerRegistry.append(layer)
        candidate.compositionRegistry[candidate.compositionRegistry.firstIndex(where: { $0.id == layer.compositionID })!].layerIDs.insert(layer.id, at: insertionIndex)
        candidate.selectedLayerID = layer.id
        _ = try candidate.validated()
        return self
    }
}
'''
if 'public struct ProjectAIEffectBakeRegistration' not in t: write(p,t+addition)

# Payload.
p='Sources/VertexProject/ProjectCommandPayload.swift'; t=read(p)
anchor='    case removeAIAsset(id: VertexID)\n'
if 'case registerBakedAIEffect' not in t:
    t=t.replace(anchor,anchor+'    case registerBakedAIEffect(ProjectAIEffectBakeRegistration)\n',1)
write(p,t)

# Mutation.
p='Sources/VertexProject/ProjectMutation.swift'; t=read(p)
anchor='    case removeAIAsset(ProjectAIAsset, index: Int)\n'
if 'case registerBakedAIEffect' not in t:
    t=t.replace(anchor,anchor+'    case registerBakedAIEffect(ProjectAIEffectBakeRegistration, previousSelectedLayerID: VertexID?)\n    case removeBakedAIEffect(ProjectAIEffectBakeRegistration, restoreSelectedLayerID: VertexID?)\n',1)
inv_anchor='        case .removeAIAsset(let asset, let index): .registerAIAsset(asset, index: index)\n'
if 'case .registerBakedAIEffect' not in t:
    t=t.replace(inv_anchor,inv_anchor+'        case .registerBakedAIEffect(let registration, let previous): .removeBakedAIEffect(registration, restoreSelectedLayerID: previous)\n        case .removeBakedAIEffect(let registration, let restore): .registerBakedAIEffect(registration, previousSelectedLayerID: restore)\n',1)
write(p,t)

# Commands prepare/apply.
p='Sources/VertexProject/ProjectCommands.swift'; t=read(p)
prepare_anchor='''        case .removeAIAsset(let id):
            guard let index = document.aiAssetRegistry.firstIndex(where: { $0.id == id }) else {
                throw ProjectError.invalidOperation("AI asset is missing.")
            }
            forward = .removeAIAsset(document.aiAssetRegistry[index], index: index)
'''
if 'case .registerBakedAIEffect(let registration):' not in t:
    insert=prepare_anchor+r'''

        case .registerBakedAIEffect(let registration):
            _ = try registration.validated(in: document)
            forward = .registerBakedAIEffect(registration, previousSelectedLayerID: document.selectedLayerID)
'''
    if prepare_anchor not in t: raise RuntimeError('AI asset prepare anchor missing')
    t=t.replace(prepare_anchor,insert,1)
apply_anchor='''        case .removeAIAsset(let asset, let index):
            guard document.aiAssetRegistry.indices.contains(index), document.aiAssetRegistry[index] == asset else {
                throw ProjectError.invalidOperation("AI asset removal precondition did not match.")
            }
            document.aiAssetRegistry.remove(at: index)
'''
if 'case .registerBakedAIEffect(let registration, let previousSelectedLayerID):' not in t:
    insert=apply_anchor+r'''

        case .registerBakedAIEffect(let registration, let previousSelectedLayerID):
            guard document.selectedLayerID == previousSelectedLayerID else {
                throw ProjectError.invalidOperation("Baked AI registration selection precondition did not match.")
            }
            _ = try registration.validated(in: document)
            guard let compositionIndex = document.compositionRegistry.firstIndex(where: { $0.id == registration.layer.compositionID }) else {
                throw ProjectError.invalidOperation("Baked AI owner composition is missing.")
            }
            document.mediaRegistry.append(registration.media)
            document.aiAssetRegistry.append(registration.aiAsset)
            document.layerRegistry.append(registration.layer)
            document.compositionRegistry[compositionIndex].layerIDs.insert(registration.layer.id, at: registration.insertionIndex)
            document.selectedLayerID = registration.layer.id

        case .removeBakedAIEffect(let registration, let restoreSelectedLayerID):
            guard document.selectedLayerID == registration.layer.id,
                  let compositionIndex = document.compositionRegistry.firstIndex(where: { $0.id == registration.layer.compositionID }),
                  document.compositionRegistry[compositionIndex].layerIDs.indices.contains(registration.insertionIndex),
                  document.compositionRegistry[compositionIndex].layerIDs[registration.insertionIndex] == registration.layer.id,
                  document.layer(id: registration.layer.id) == registration.layer,
                  document.mediaRegistry.contains(registration.media),
                  document.aiAssetRegistry.contains(registration.aiAsset) else {
                throw ProjectError.invalidOperation("Baked AI removal precondition did not match.")
            }
            document.compositionRegistry[compositionIndex].layerIDs.remove(at: registration.insertionIndex)
            document.layerRegistry.removeAll { $0.id == registration.layer.id }
            document.aiAssetRegistry.removeAll { $0.id == registration.aiAsset.id }
            document.mediaRegistry.removeAll { $0.id == registration.media.id }
            document.selectedLayerID = restoreSelectedLayerID
'''
    if apply_anchor not in t: raise RuntimeError('AI apply anchor missing')
    t=t.replace(apply_anchor,insert,1)
write(p,t)

write('App/AIEffectBakeCoordinator.swift', r'''import Foundation
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
    private let commit: Commit
    private(set) var progress: Double = 0

    init(processor: any AIEffectBakeProcessing = LiveAIEffectBakeProcessor(), commit: @escaping Commit) {
        self.processor = processor
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
''')

# ViewModel thin wrapper.
p='App/ProjectWorkspaceViewModel.swift'; t=read(p)
anchor='''    func setLayerMarkers(_ markers: [ProjectMarker]) {
        guard let layer = selectedLayer else { return }
        perform(.setLayerMarkers(id: layer.id, markers: markers), mergeKey: nil)
    }
'''
addition=anchor+r'''

    func bakeEffect(layerID: VertexID, effectID: VertexID) async throws {
        guard let project, let projectURL else { throw ProjectError.invalidOperation("Save the project package before baking AI output.") }
        let coordinator = AIEffectBakeCoordinator { [weak self] registration in
            self?.perform(.registerBakedAIEffect(registration), mergeKey: nil)
        }
        try await coordinator.bake(project: project, packageURL: projectURL, layerID: layerID, effectID: effectID)
    }
'''
if 'func bakeEffect(layerID:' not in t:
    if anchor not in t: raise RuntimeError('view model marker for bake missing')
    t=t.replace(anchor,addition,1)
write(p,t)
print('Task 9 GREEN implementation applied')
