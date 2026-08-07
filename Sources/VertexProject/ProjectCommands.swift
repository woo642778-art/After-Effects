import Foundation
import VertexCore

public struct ProjectCommandEngine: Sendable {
    public init() {}

    public func prepare(
        _ request: ProjectCommandRequest,
        for document: ProjectDocument
    ) throws -> ProjectTransition {
        guard request.projectID == document.projectID else {
            throw ProjectError.invalidProjectIdentity
        }
        guard request.baseRevision == document.revision else {
            throw ProjectError.staleBaseRevision(
                expected: request.baseRevision,
                actual: document.revision
            )
        }

        let forward: ProjectMutation
        switch request.payload {
        case .renameProject(let nextName):
            let normalized = nextName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, normalized != document.metadata.name else {
                throw ProjectError.invalidOperation("Project name must change to a non-empty value.")
            }
            forward = .renameProject(before: document.metadata.name, after: normalized)

        case .registerMedia(let reference):
            _ = try reference.validated()
            guard !document.mediaRegistry.contains(where: { $0.id == reference.id }) else {
                throw ProjectError.duplicateIdentity("media")
            }
            forward = .registerMedia(reference)

        case .removeMedia(let id):
            guard let reference = document.mediaRegistry.first(where: { $0.id == id }) else {
                throw ProjectError.missingMedia(id.rawValue)
            }
            guard !document.layerRegistry.contains(where: {
                if case .media(let mediaID, _) = $0.source { return mediaID == id }
                return false
            }) else {
                throw ProjectError.invalidOperation("Media referenced by a layer cannot be removed.")
            }
            forward = .removeMedia(reference)

        case .relinkMedia(let id, let locator):
            guard let reference = document.mediaRegistry.first(where: { $0.id == id }) else {
                throw ProjectError.missingMedia(id.rawValue)
            }
            guard reference.locator != locator else {
                throw ProjectError.invalidOperation("Media locator is already set to the requested value.")
            }
            forward = .relinkMedia(mediaID: id, before: reference.locator, after: locator)

        case .setEmbeddedPath(let id, let path):
            guard let reference = document.mediaRegistry.first(where: { $0.id == id }) else {
                throw ProjectError.missingMedia(id.rawValue)
            }
            guard reference.locator.embeddedPath != path else {
                throw ProjectError.invalidOperation("Embedded path is already set to the requested value.")
            }
            forward = .setEmbeddedPath(
                mediaID: id,
                before: reference.locator.embeddedPath,
                after: path
            )

        case .setProjectColor(let color):
            guard document.settings.color != color else {
                throw ProjectError.invalidOperation("Project color is already set to the requested value.")
            }
            forward = .setProjectColor(before: document.settings.color, after: color)

        case .createComposition(let composition, let ownedLayers, let index):
            guard index >= 0, index <= document.compositionRegistry.count else {
                throw ProjectError.invalidValue("Composition insertion index is outside the registry.")
            }
            try validateNewComposition(
                composition,
                ownedLayers: ownedLayers,
                document: document
            )
            forward = .createComposition(
                composition,
                ownedLayers: ownedLayers,
                registryIndex: index
            )

        case .removeComposition(let id):
            guard document.compositionRegistry.count > 1 else {
                throw ProjectError.invalidOperation("The last composition cannot be removed.")
            }
            guard let index = document.compositionRegistry.firstIndex(where: { $0.id == id }) else {
                throw ProjectError.invalidOperation("Composition is missing.")
            }
            guard !isCompositionReferenced(id, in: document) else {
                throw ProjectError.invalidOperation("A nested layer references this composition.")
            }
            let composition = document.compositionRegistry[index]
            forward = .removeComposition(
                composition,
                ownedLayers: document.layers(in: id),
                registryIndex: index
            )

        case .duplicateComposition(let sourceID, let newCompositionID, let newLayerIDs):
            guard let sourceIndex = document.compositionRegistry.firstIndex(where: { $0.id == sourceID }) else {
                throw ProjectError.invalidOperation("Source composition is missing.")
            }
            guard !document.compositionRegistry.contains(where: { $0.id == newCompositionID }) else {
                throw ProjectError.duplicateIdentity("composition")
            }
            let source = document.compositionRegistry[sourceIndex]
            let sourceLayers = document.layers(in: sourceID)
            guard newLayerIDs.count == sourceLayers.count,
                  Set(newLayerIDs).count == newLayerIDs.count,
                  newLayerIDs.allSatisfy({ id in !document.layerRegistry.contains(where: { $0.id == id }) }) else {
                throw ProjectError.invalidValue("Duplicate layer IDs must uniquely match the source layer count.")
            }
            var duplicate = source
            duplicate.id = newCompositionID
            duplicate.name = source.name + " Copy"
            duplicate.layerIDs = newLayerIDs
            let layers = zip(sourceLayers, newLayerIDs).map { sourceLayer, newID in
                var copy = sourceLayer
                copy.id = newID
                copy.compositionID = newCompositionID
                copy.name = sourceLayer.name + " Copy"
                return copy
            }
            forward = .createComposition(
                duplicate,
                ownedLayers: layers,
                registryIndex: sourceIndex + 1
            )

        case .renameComposition(let id, let name):
            let composition = try requireComposition(id, in: document)
            let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, normalized != composition.name else {
                throw ProjectError.invalidOperation("Composition name must change to a non-empty value.")
            }
            forward = .renameComposition(
                compositionID: id,
                before: composition.name,
                after: normalized
            )

        case .setCompositionDimensions(let id, let width, let height):
            let composition = try requireComposition(id, in: document)
            guard composition.width != width || composition.height != height else {
                throw ProjectError.invalidOperation("Composition dimensions are unchanged.")
            }
            forward = .setCompositionDimensions(
                compositionID: id,
                beforeWidth: composition.width,
                beforeHeight: composition.height,
                afterWidth: width,
                afterHeight: height
            )

        case .setCompositionDuration(let id, let duration):
            let composition = try requireComposition(id, in: document)
            guard composition.duration != duration else {
                throw ProjectError.invalidOperation("Composition duration is unchanged.")
            }
            forward = .setCompositionDuration(
                compositionID: id,
                before: composition.duration,
                after: duration
            )

        case .setCompositionFrameRate(let id, let frameRate):
            let composition = try requireComposition(id, in: document)
            guard composition.frameRate != frameRate else {
                throw ProjectError.invalidOperation("Composition frame rate is unchanged.")
            }
            forward = .setCompositionFrameRate(
                compositionID: id,
                before: composition.frameRate,
                after: frameRate
            )

        case .setCompositionBackground(let id, let color):
            let composition = try requireComposition(id, in: document)
            guard composition.backgroundColor != color else {
                throw ProjectError.invalidOperation("Composition background is unchanged.")
            }
            forward = .setCompositionBackground(
                compositionID: id,
                before: composition.backgroundColor,
                after: color
            )

        case .insertLayer(let layer, let compositionID, let index):
            guard let composition = document.composition(id: compositionID),
                  index >= 0, index <= composition.layerIDs.count else {
                throw ProjectError.invalidValue("Layer insertion index is outside the composition.")
            }
            guard layer.compositionID == compositionID,
                  !document.layerRegistry.contains(where: { $0.id == layer.id }) else {
                throw ProjectError.invalidOperation("Layer identity or ownership is invalid for insertion.")
            }
            forward = .insertLayer(layer, compositionID: compositionID, index: index)

        case .removeLayer(let id):
            let layer = try requireEditableLayer(id, in: document)
            guard let composition = document.composition(id: layer.compositionID),
                  let index = composition.layerIDs.firstIndex(of: id) else {
                throw ProjectError.invalidOperation("Layer order is missing the layer.")
            }
            forward = .removeLayer(layer, compositionID: layer.compositionID, index: index)

        case .duplicateLayer(let sourceID, let duplicateID, let index):
            let source = try requireEditableLayer(sourceID, in: document)
            guard !document.layerRegistry.contains(where: { $0.id == duplicateID }) else {
                throw ProjectError.duplicateIdentity("layer")
            }
            guard let composition = document.composition(id: source.compositionID),
                  index >= 0, index <= composition.layerIDs.count else {
                throw ProjectError.invalidValue("Duplicate layer insertion index is invalid.")
            }
            var duplicate = source
            duplicate.id = duplicateID
            duplicate.name = source.name + " Copy"
            forward = .duplicateLayer(
                sourceLayerID: sourceID,
                duplicate: duplicate,
                compositionID: source.compositionID,
                index: index
            )

        case .renameLayer(let id, let name):
            let layer = try requireEditableLayer(id, in: document)
            let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, normalized != layer.name else {
                throw ProjectError.invalidOperation("Layer name must change to a non-empty value.")
            }
            forward = .renameLayer(layerID: id, before: layer.name, after: normalized)

        case .reorderLayer(let compositionID, let layerID, let toIndex):
            _ = try requireEditableLayer(layerID, in: document)
            guard let composition = document.composition(id: compositionID),
                  let beforeIndex = composition.layerIDs.firstIndex(of: layerID),
                  toIndex >= 0, toIndex < composition.layerIDs.count,
                  beforeIndex != toIndex else {
                throw ProjectError.invalidOperation("Layer reorder request is invalid or unchanged.")
            }
            forward = .reorderLayer(
                compositionID: compositionID,
                layerID: layerID,
                beforeIndex: beforeIndex,
                afterIndex: toIndex
            )

        case .setLayerLocked(let id, let value):
            let layer = try requireLayer(id, in: document)
            guard layer.locked != value else {
                throw ProjectError.invalidOperation("Layer lock state is unchanged.")
            }
            forward = .setLayerLocked(layerID: id, before: layer.locked, after: value)

        case .setLayerEnabled(let id, let value):
            let layer = try requireEditableLayer(id, in: document)
            guard layer.enabled != value else { throw ProjectError.invalidOperation("Layer enabled state is unchanged.") }
            forward = .setLayerEnabled(layerID: id, before: layer.enabled, after: value)

        case .setLayerSolo(let id, let value):
            let layer = try requireEditableLayer(id, in: document)
            guard layer.solo != value else { throw ProjectError.invalidOperation("Layer Solo state is unchanged.") }
            forward = .setLayerSolo(layerID: id, before: layer.solo, after: value)

        case .setLayerTiming(let id, let value):
            let layer = try requireEditableLayer(id, in: document)
            guard layer.timing != value else { throw ProjectError.invalidOperation("Layer timing is unchanged.") }
            forward = .setLayerTiming(layerID: id, before: layer.timing, after: value)

        case .setLayerTransform(let id, let value):
            let layer = try requireEditableLayer(id, in: document)
            guard layer.transform != value else { throw ProjectError.invalidOperation("Layer transform is unchanged.") }
            forward = .setLayerTransform(layerID: id, before: layer.transform, after: value)

        case .setLayerBlendMode(let id, let value):
            let layer = try requireEditableLayer(id, in: document)
            guard layer.blendMode != value else { throw ProjectError.invalidOperation("Layer blend mode is unchanged.") }
            forward = .setLayerBlendMode(layerID: id, before: layer.blendMode, after: value)

        case .setLayerSource(let id, let value):
            let layer = try requireEditableLayer(id, in: document)
            guard layer.source != value else { throw ProjectError.invalidOperation("Layer source is unchanged.") }
            forward = .setLayerSource(layerID: id, before: layer.source, after: value)

        case .setLayerOperations(let id, let value):
            let layer = try requireEditableLayer(id, in: document)
            guard layer.operations != value else { throw ProjectError.invalidOperation("Layer operations are unchanged.") }
            forward = .setLayerOperations(layerID: id, before: layer.operations, after: value)
        }

        return ProjectTransition(
            commandID: request.commandID,
            projectID: request.projectID,
            baseRevision: request.baseRevision,
            timestamp: request.timestamp,
            mergeKey: request.mergeKey,
            forward: forward,
            inverse: forward.inverse
        )
    }

    public func apply(
        _ transition: ProjectTransition,
        to document: ProjectDocument
    ) throws -> ProjectDocument {
        guard transition.projectID == document.projectID else {
            throw ProjectError.invalidProjectIdentity
        }
        guard transition.baseRevision == document.revision else {
            throw ProjectError.staleBaseRevision(
                expected: transition.baseRevision,
                actual: document.revision
            )
        }
        guard transition.inverse == transition.forward.inverse else {
            throw ProjectError.invalidInverseOperation("The transition inverse does not reverse the forward mutation.")
        }
        guard document.revision < UInt64.max else { throw ProjectError.invalidRevision }

        var changed = document
        try apply(transition.forward, to: &changed)
        changed.revision += 1
        changed.metadata.modifiedAt = transition.timestamp
        changed.metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion
        return try changed.validated()
    }

    @available(*, deprecated, message: "Legacy WAL compatibility only; use ProjectTransition.")
    public func apply(
        _ record: ProjectCommandRecord,
        to document: ProjectDocument
    ) throws -> ProjectDocument {
        try apply(
            ProjectTransition(
                commandID: record.commandID,
                projectID: record.projectID,
                baseRevision: record.baseRevision,
                timestamp: record.timestamp,
                mergeKey: record.mergeKey,
                forward: record.forwardOperation,
                inverse: record.inverseOperation
            ),
            to: document
        )
    }

    private func apply(_ mutation: ProjectMutation, to document: inout ProjectDocument) throws {
        switch mutation {
        case .renameProject(let before, let after):
            guard document.metadata.name == before,
                  !after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ProjectError.invalidOperation("Project name precondition did not match.")
            }
            document.metadata.name = after

        case .registerMedia(let reference):
            _ = try reference.validated()
            guard !document.mediaRegistry.contains(where: { $0.id == reference.id }) else {
                throw ProjectError.duplicateIdentity("media")
            }
            document.mediaRegistry.append(reference)

        case .removeMedia(let reference):
            guard let index = document.mediaRegistry.firstIndex(of: reference),
                  !document.layerRegistry.contains(where: {
                      if case .media(let mediaID, _) = $0.source { return mediaID == reference.id }
                      return false
                  }) else {
                throw ProjectError.invalidOperation("Media removal precondition did not match.")
            }
            document.mediaRegistry.remove(at: index)
            if document.selectedMediaID == reference.id { document.selectedMediaID = nil }

        case .relinkMedia(let mediaID, let before, let after):
            guard let index = document.mediaRegistry.firstIndex(where: { $0.id == mediaID }),
                  document.mediaRegistry[index].locator == before else {
                throw ProjectError.invalidOperation("Media locator precondition did not match.")
            }
            document.mediaRegistry[index].locator = after
            document.mediaRegistry[index].availabilityStatus = after.embeddedPath == nil ? .external : .embedded

        case .setEmbeddedPath(let mediaID, let before, let after):
            guard let index = document.mediaRegistry.firstIndex(where: { $0.id == mediaID }),
                  document.mediaRegistry[index].locator.embeddedPath == before else {
                throw ProjectError.invalidOperation("Embedded path precondition did not match.")
            }
            document.mediaRegistry[index].locator.embeddedPath = after
            document.mediaRegistry[index].availabilityStatus = after == nil ? .external : .embedded

        case .setProjectColor(let before, let after):
            guard document.settings.color == before else {
                throw ProjectError.invalidOperation("Project color precondition did not match.")
            }
            document.settings.color = after

        case .selectMedia:
            throw ProjectError.invalidOperation("Selection mutations are not valid in canonical schema 2 sessions.")
        case .setRenderParameter, .setRenderBoolean, .setOutputDimensions:
            throw ProjectError.invalidOperation("Render Lab compatibility mutations are not valid in canonical schema 2.")

        case .createComposition(let composition, let ownedLayers, let index):
            try insertComposition(composition, ownedLayers: ownedLayers, registryIndex: index, into: &document)

        case .duplicateComposition(let sourceID, let composition, let layers, let index):
            guard document.composition(id: sourceID) != nil else {
                throw ProjectError.invalidOperation("Source composition is missing.")
            }
            try insertComposition(composition, ownedLayers: layers, registryIndex: index, into: &document)

        case .removeComposition(let composition, let ownedLayers, let index):
            guard document.compositionRegistry.count > 1,
                  document.compositionRegistry.indices.contains(index),
                  document.compositionRegistry[index] == composition,
                  document.layers(in: composition.id) == ownedLayers,
                  !isCompositionReferenced(composition.id, in: document) else {
                throw ProjectError.invalidOperation("Composition removal precondition did not match.")
            }
            document.layerRegistry.removeAll { $0.compositionID == composition.id }
            document.compositionRegistry.remove(at: index)
            if document.activeCompositionID == composition.id {
                document.activeCompositionID = document.compositionRegistry.first?.id
            }
            if let selected = document.selectedLayerID,
               ownedLayers.contains(where: { $0.id == selected }) {
                document.selectedLayerID = nil
            }

        case .renameComposition(let compositionID, let before, let after):
            let index = try compositionIndex(compositionID, in: document)
            guard document.compositionRegistry[index].name == before else {
                throw ProjectError.invalidOperation("Composition name precondition did not match.")
            }
            document.compositionRegistry[index].name = after

        case .setCompositionDimensions(let id, let beforeWidth, let beforeHeight, let afterWidth, let afterHeight):
            let index = try compositionIndex(id, in: document)
            guard document.compositionRegistry[index].width == beforeWidth,
                  document.compositionRegistry[index].height == beforeHeight else {
                throw ProjectError.invalidOperation("Composition dimensions precondition did not match.")
            }
            document.compositionRegistry[index].width = afterWidth
            document.compositionRegistry[index].height = afterHeight

        case .setCompositionDuration(let id, let before, let after):
            let index = try compositionIndex(id, in: document)
            guard document.compositionRegistry[index].duration == before else {
                throw ProjectError.invalidOperation("Composition duration precondition did not match.")
            }
            document.compositionRegistry[index].duration = after

        case .setCompositionFrameRate(let id, let before, let after):
            let index = try compositionIndex(id, in: document)
            guard document.compositionRegistry[index].frameRate == before else {
                throw ProjectError.invalidOperation("Composition frame-rate precondition did not match.")
            }
            document.compositionRegistry[index].frameRate = after

        case .setCompositionBackground(let id, let before, let after):
            let index = try compositionIndex(id, in: document)
            guard document.compositionRegistry[index].backgroundColor == before else {
                throw ProjectError.invalidOperation("Composition background precondition did not match.")
            }
            document.compositionRegistry[index].backgroundColor = after

        case .insertLayer(let layer, let compositionID, let index):
            try insertLayer(layer, compositionID: compositionID, index: index, into: &document)

        case .duplicateLayer(let sourceLayerID, let duplicate, let compositionID, let index):
            guard document.layer(id: sourceLayerID) != nil else {
                throw ProjectError.invalidOperation("Source layer is missing.")
            }
            try insertLayer(duplicate, compositionID: compositionID, index: index, into: &document)

        case .removeLayer(let layer, let compositionID, let index):
            let compositionIndex = try compositionIndex(compositionID, in: document)
            guard document.compositionRegistry[compositionIndex].layerIDs.indices.contains(index),
                  document.compositionRegistry[compositionIndex].layerIDs[index] == layer.id,
                  document.layer(id: layer.id) == layer,
                  !layer.locked else {
                throw ProjectError.invalidOperation("Layer removal precondition did not match.")
            }
            document.compositionRegistry[compositionIndex].layerIDs.remove(at: index)
            document.layerRegistry.removeAll { $0.id == layer.id }
            if document.selectedLayerID == layer.id { document.selectedLayerID = nil }

        case .renameLayer(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].name == before else {
                throw ProjectError.invalidOperation("Layer name precondition did not match.")
            }
            document.layerRegistry[index].name = after

        case .reorderLayer(let compositionID, let layerID, let beforeIndex, let afterIndex):
            _ = try editableLayerIndex(layerID, in: document)
            let index = try compositionIndex(compositionID, in: document)
            var ids = document.compositionRegistry[index].layerIDs
            guard ids.indices.contains(beforeIndex), ids[beforeIndex] == layerID,
                  afterIndex >= 0, afterIndex < ids.count else {
                throw ProjectError.invalidOperation("Layer reorder precondition did not match.")
            }
            ids.remove(at: beforeIndex)
            ids.insert(layerID, at: afterIndex)
            document.compositionRegistry[index].layerIDs = ids

        case .setLayerLocked(let layerID, let before, let after):
            let index = try layerIndex(layerID, in: document)
            guard document.layerRegistry[index].locked == before else {
                throw ProjectError.invalidOperation("Layer lock precondition did not match.")
            }
            document.layerRegistry[index].locked = after

        case .setLayerEnabled(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].enabled == before else {
                throw ProjectError.invalidOperation("Layer enabled precondition did not match.")
            }
            document.layerRegistry[index].enabled = after

        case .setLayerSolo(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].solo == before else {
                throw ProjectError.invalidOperation("Layer Solo precondition did not match.")
            }
            document.layerRegistry[index].solo = after

        case .setLayerTiming(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].timing == before else {
                throw ProjectError.invalidOperation("Layer timing precondition did not match.")
            }
            document.layerRegistry[index].timing = after

        case .setLayerTransform(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].transform == before else {
                throw ProjectError.invalidOperation("Layer transform precondition did not match.")
            }
            document.layerRegistry[index].transform = after

        case .setLayerBlendMode(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].blendMode == before else {
                throw ProjectError.invalidOperation("Layer blend-mode precondition did not match.")
            }
            document.layerRegistry[index].blendMode = after

        case .setLayerSource(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].source == before else {
                throw ProjectError.invalidOperation("Layer source precondition did not match.")
            }
            document.layerRegistry[index].source = after

        case .setLayerOperations(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].operations == before else {
                throw ProjectError.invalidOperation("Layer operations precondition did not match.")
            }
            document.layerRegistry[index].operations = after
        }
    }

    private func validateNewComposition(
        _ composition: ProjectComposition,
        ownedLayers: [ProjectLayer],
        document: ProjectDocument
    ) throws {
        guard !document.compositionRegistry.contains(where: { $0.id == composition.id }),
              !ownedLayers.contains(where: { layer in document.layerRegistry.contains(where: { $0.id == layer.id }) }),
              ownedLayers.allSatisfy({ $0.compositionID == composition.id }),
              composition.layerIDs == ownedLayers.map(\.id) else {
            throw ProjectError.invalidOperation("New composition identity, ownership, or layer order is invalid.")
        }
    }

    private func insertComposition(
        _ composition: ProjectComposition,
        ownedLayers: [ProjectLayer],
        registryIndex: Int,
        into document: inout ProjectDocument
    ) throws {
        try validateNewComposition(composition, ownedLayers: ownedLayers, document: document)
        guard registryIndex >= 0, registryIndex <= document.compositionRegistry.count else {
            throw ProjectError.invalidOperation("Composition insertion index is invalid.")
        }
        document.compositionRegistry.insert(composition, at: registryIndex)
        document.layerRegistry.append(contentsOf: ownedLayers)
        if document.activeCompositionID == nil { document.activeCompositionID = composition.id }
    }

    private func insertLayer(
        _ layer: ProjectLayer,
        compositionID: VertexID,
        index: Int,
        into document: inout ProjectDocument
    ) throws {
        let compositionIndex = try compositionIndex(compositionID, in: document)
        guard layer.compositionID == compositionID,
              !document.layerRegistry.contains(where: { $0.id == layer.id }),
              index >= 0, index <= document.compositionRegistry[compositionIndex].layerIDs.count else {
            throw ProjectError.invalidOperation("Layer insertion precondition did not match.")
        }
        document.layerRegistry.append(layer)
        document.compositionRegistry[compositionIndex].layerIDs.insert(layer.id, at: index)
    }

    private func requireComposition(_ id: VertexID, in document: ProjectDocument) throws -> ProjectComposition {
        guard let composition = document.composition(id: id) else {
            throw ProjectError.invalidOperation("Composition is missing: \(id.rawValue).")
        }
        return composition
    }

    private func requireLayer(_ id: VertexID, in document: ProjectDocument) throws -> ProjectLayer {
        guard let layer = document.layer(id: id) else {
            throw ProjectError.invalidOperation("Layer is missing: \(id.rawValue).")
        }
        return layer
    }

    private func requireEditableLayer(_ id: VertexID, in document: ProjectDocument) throws -> ProjectLayer {
        let layer = try requireLayer(id, in: document)
        guard !layer.locked else { throw ProjectError.invalidOperation("Locked layers cannot be edited.") }
        return layer
    }

    private func compositionIndex(_ id: VertexID, in document: ProjectDocument) throws -> Int {
        guard let index = document.compositionRegistry.firstIndex(where: { $0.id == id }) else {
            throw ProjectError.invalidOperation("Composition is missing: \(id.rawValue).")
        }
        return index
    }

    private func layerIndex(_ id: VertexID, in document: ProjectDocument) throws -> Int {
        guard let index = document.layerRegistry.firstIndex(where: { $0.id == id }) else {
            throw ProjectError.invalidOperation("Layer is missing: \(id.rawValue).")
        }
        return index
    }

    private func editableLayerIndex(_ id: VertexID, in document: ProjectDocument) throws -> Int {
        let index = try layerIndex(id, in: document)
        guard !document.layerRegistry[index].locked else {
            throw ProjectError.invalidOperation("Locked layers cannot be edited.")
        }
        return index
    }

    private func isCompositionReferenced(_ id: VertexID, in document: ProjectDocument) -> Bool {
        document.layerRegistry.contains { layer in
            if case .composition(let target, _) = layer.source {
                return target == id && layer.compositionID != id
            }
            return false
        }
    }
}

@available(*, deprecated, message: "Legacy WAL compatibility only; use ProjectCommandRequest and ProjectTransition.")
public struct ProjectCommandRecord: Codable, Equatable, Sendable, Identifiable {
    public var commandID: VertexID
    public var projectID: VertexID
    public var baseRevision: UInt64
    public var timestamp: Date
    public var mergeKey: String?
    public var forwardOperation: ProjectMutation
    public var inverseOperation: ProjectMutation

    public var id: VertexID { commandID }

    public init(
        commandID: VertexID = VertexID(),
        projectID: VertexID,
        baseRevision: UInt64,
        timestamp: Date = Date(),
        mergeKey: String? = nil,
        forwardOperation: ProjectMutation,
        inverseOperation: ProjectMutation
    ) {
        self.commandID = commandID
        self.projectID = projectID
        self.baseRevision = baseRevision
        self.timestamp = timestamp
        self.mergeKey = mergeKey
        self.forwardOperation = forwardOperation
        self.inverseOperation = inverseOperation
    }

    public init(
        project: ProjectDocument,
        commandID: VertexID = VertexID(),
        operation: ProjectMutation,
        mergeKey: String? = nil,
        timestamp: Date = Date()
    ) {
        self.init(
            commandID: commandID,
            projectID: project.projectID,
            baseRevision: project.revision,
            timestamp: timestamp,
            mergeKey: mergeKey,
            forwardOperation: operation,
            inverseOperation: operation.inverse
        )
    }

    public static func settingExposure(
        project: ProjectDocument,
        commandID: VertexID = VertexID(),
        from: Double,
        to: Double,
        timestamp: Date = Date()
    ) -> ProjectCommandRecord {
        ProjectCommandRecord(
            project: project,
            commandID: commandID,
            operation: .setRenderParameter(.exposure, before: from, after: to),
            mergeKey: "render.exposure",
            timestamp: timestamp
        )
    }
}
