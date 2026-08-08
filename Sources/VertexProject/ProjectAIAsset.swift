import Foundation
import VertexCore

public enum ProjectAIAssetKind: String, Codable, CaseIterable, Sendable {
    case depth
    case matte
    case derivedVideo
}

public struct ProjectAIRecipeReference: Codable, Equatable, Sendable {
    public let task: String
    public let modelID: String
    public let modelDigest: String
    public let recipeDigest: String
    public let qualityTier: String

    public init(
        task: String,
        modelID: String,
        modelDigest: String,
        recipeDigest: String,
        qualityTier: String
    ) {
        self.task = task
        self.modelID = modelID
        self.modelDigest = modelDigest
        self.recipeDigest = recipeDigest
        self.qualityTier = qualityTier
    }

    public func validated() throws -> Self {
        let required = [task, modelID, modelDigest, recipeDigest, qualityTier]
        guard required.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ProjectError.invalidValue("AI recipe references require task, model, digests, and quality tier.")
        }
        guard Self.isSHA256(modelDigest), Self.isSHA256(recipeDigest) else {
            throw ProjectError.invalidValue("AI recipe digests must be SHA-256 values.")
        }
        return self
    }

    private static func isSHA256(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (65...70).contains(byte) || (97...102).contains(byte)
        }
    }
}

public struct ProjectAIAsset: Codable, Equatable, Sendable, Identifiable {
    public let id: VertexID
    public let kind: ProjectAIAssetKind
    public let sourceMediaID: VertexID
    public let outputMediaID: VertexID
    /// Optional relative path for non-preview data such as float depth chunks.
    /// Runtime caches are never stored here; this points only to verified project-usable output.
    public let auxiliaryRelativePath: String?
    public let recipe: ProjectAIRecipeReference

    public init(
        id: VertexID = VertexID(),
        kind: ProjectAIAssetKind,
        sourceMediaID: VertexID,
        outputMediaID: VertexID,
        auxiliaryRelativePath: String? = nil,
        recipe: ProjectAIRecipeReference
    ) {
        self.id = id
        self.kind = kind
        self.sourceMediaID = sourceMediaID
        self.outputMediaID = outputMediaID
        self.auxiliaryRelativePath = auxiliaryRelativePath
        self.recipe = recipe
    }

    public func validated(in document: ProjectDocument) throws -> Self {
        guard sourceMediaID != outputMediaID else {
            throw ProjectError.invalidValue("AI source and output media identities must differ.")
        }
        guard document.mediaRegistry.contains(where: { $0.id == sourceMediaID }) else {
            throw ProjectError.missingMedia(sourceMediaID.rawValue)
        }
        guard document.mediaRegistry.contains(where: { $0.id == outputMediaID }) else {
            throw ProjectError.missingMedia(outputMediaID.rawValue)
        }
        if let path = auxiliaryRelativePath {
            let parts = path.split(separator: "/")
            guard !path.hasPrefix("/"), !parts.contains(".."), !parts.isEmpty else {
                throw ProjectError.invalidPackagePath("AI auxiliary asset paths must remain relative.")
            }
        }
        _ = try recipe.validated()
        return self
    }
}


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
