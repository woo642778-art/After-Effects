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
            guard !normalized.isEmpty else { throw ProjectError.invalidValue("Project name must not be empty.") }
            guard normalized != document.metadata.name else { throw ProjectError.invalidOperation("Project name is already set to the requested value.") }
            forward = .renameProject(before: document.metadata.name, after: normalized)

        case .registerMedia(let reference):
            _ = try reference.validated()
            guard !document.mediaRegistry.contains(where: { $0.id == reference.id }) else { throw ProjectError.duplicateIdentity("media") }
            forward = .registerMedia(reference)

        case .removeMedia(let mediaID):
            guard let reference = document.mediaRegistry.first(where: { $0.id == mediaID }) else { throw ProjectError.missingMedia(mediaID.rawValue) }
            forward = .removeMedia(reference)

        case .relinkMedia(let mediaID, let nextLocator):
            guard let reference = document.mediaRegistry.first(where: { $0.id == mediaID }) else { throw ProjectError.missingMedia(mediaID.rawValue) }
            guard reference.locator != nextLocator else { throw ProjectError.invalidOperation("Media locator is already set to the requested value.") }
            forward = .relinkMedia(mediaID: mediaID, before: reference.locator, after: nextLocator)

        case .setEmbeddedPath(let mediaID, let nextPath):
            guard let reference = document.mediaRegistry.first(where: { $0.id == mediaID }) else { throw ProjectError.missingMedia(mediaID.rawValue) }
            guard reference.locator.embeddedPath != nextPath else { throw ProjectError.invalidOperation("Embedded path is already set to the requested value.") }
            forward = .setEmbeddedPath(mediaID: mediaID, before: reference.locator.embeddedPath, after: nextPath)

        case .setRenderParameter(let parameter, let nextValue):
            guard nextValue.isFinite else { throw ProjectError.invalidValue("Render parameters must be finite.") }
            let previous = document.renderSettings.value(for: parameter)
            guard previous != nextValue else { throw ProjectError.invalidOperation("Render parameter is already set to the requested value.") }
            var settings = document.renderSettings
            settings.set(nextValue, for: parameter)
            _ = try settings.validated()
            forward = .setRenderParameter(parameter, before: previous, after: nextValue)

        case .setRenderBoolean(let parameter, let nextValue):
            switch parameter {
            case .inverted:
                let previous = document.renderSettings.inverted
                guard previous != nextValue else { throw ProjectError.invalidOperation("Render boolean is already set to the requested value.") }
                forward = .setRenderBoolean(parameter, before: previous, after: nextValue)
            }

        case .setOutputDimensions(let width, let height):
            var settings = document.renderSettings
            let previousWidth = settings.outputWidth
            let previousHeight = settings.outputHeight
            guard previousWidth != width || previousHeight != height else { throw ProjectError.invalidOperation("Output dimensions are already set to the requested values.") }
            settings.outputWidth = width
            settings.outputHeight = height
            _ = try settings.validated()
            forward = .setOutputDimensions(beforeWidth: previousWidth, beforeHeight: previousHeight, afterWidth: width, afterHeight: height)

        case .setProjectColor(let nextColor):
            let previous = document.settings.color
            guard previous != nextColor else { throw ProjectError.invalidOperation("Project color is already set to the requested value.") }
            forward = .setProjectColor(before: previous, after: nextColor)

        case .createComposition(let composition, let ownedLayers, let index):
            guard (0...document.compositionRegistry.count).contains(index) else { throw ProjectError.invalidOperation("Composition insertion index is outside the registry.") }
            try validateNewComposition(composition, ownedLayers: ownedLayers, against: document)
            forward = .createComposition(composition, ownedLayers: ownedLayers, registryIndex: index)

        case .removeComposition(let compositionID):
            guard document.compositionRegistry.count > 1 else { throw ProjectError.invalidOperation("A project must retain at least one composition.") }
            guard let index = document.compositionRegistry.firstIndex(where: { $0.id == compositionID }) else { throw ProjectError.invalidOperation("Composition does not exist.") }
            guard document.activeCompositionID != compositionID else { throw ProjectError.invalidOperation("The active composition cannot be removed.") }
            guard !document.layerRegistry.contains(where: { layer in
                guard layer.compositionID != compositionID else { return false }
                if case .composition(let targetID, _) = layer.source { return targetID == compositionID }
                return false
            }) else { throw ProjectError.invalidOperation("A referenced composition cannot be removed.") }
            let composition = document.compositionRegistry[index]
            let ownedLayers = composition.layerIDs.compactMap { document.layer(id: $0) }
            guard ownedLayers.count == composition.layerIDs.count else { throw ProjectError.invalidOperation("Composition ownership is incomplete.") }
            forward = .removeComposition(composition, ownedLayers: ownedLayers, registryIndex: index)

        case .duplicateComposition(let sourceID, let newCompositionID, let newLayerIDs):
            guard let sourceIndex = document.compositionRegistry.firstIndex(where: { $0.id == sourceID }) else { throw ProjectError.invalidOperation("Source composition does not exist.") }
            guard !document.compositionRegistry.contains(where: { $0.id == newCompositionID }) else { throw ProjectError.duplicateIdentity("composition") }
            let source = document.compositionRegistry[sourceIndex]
            guard newLayerIDs.count == source.layerIDs.count, Set(newLayerIDs).count == newLayerIDs.count else { throw ProjectError.invalidValue("Duplicated composition layer identities must match the source layer count and be unique.") }
            guard !newLayerIDs.contains(where: { id in document.layerRegistry.contains(where: { $0.id == id }) }) else { throw ProjectError.duplicateIdentity("layer") }
            let sourceLayers = source.layerIDs.compactMap { document.layer(id: $0) }
            guard sourceLayers.count == source.layerIDs.count else { throw ProjectError.invalidOperation("Source composition ownership is incomplete.") }
            let idMap = Dictionary(uniqueKeysWithValues: zip(source.layerIDs, newLayerIDs))
            let duplicateLayers = sourceLayers.map { sourceLayer -> ProjectLayer in
                var duplicate = sourceLayer
                duplicate.id = idMap[sourceLayer.id]!
                duplicate.compositionID = newCompositionID
                return duplicate
            }
            var duplicate = source
            duplicate.id = newCompositionID
            duplicate.name = source.name + " Copy"
            duplicate.layerIDs = source.layerIDs.compactMap { idMap[$0] }
            forward = .duplicateComposition(sourceID: sourceID, composition: duplicate, layers: duplicateLayers, registryIndex: sourceIndex + 1)

        case .renameComposition(let compositionID, let nextName):
            guard let composition = document.composition(id: compositionID) else { throw ProjectError.invalidOperation("Composition does not exist.") }
            let normalized = nextName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { throw ProjectError.invalidValue("Composition name must not be empty.") }
            guard normalized != composition.name else { throw ProjectError.invalidOperation("Composition name is already set to the requested value.") }
            forward = .renameComposition(id: compositionID, before: composition.name, after: normalized)

        case .setCompositionDimensions(let compositionID, let width, let height):
            guard let composition = document.composition(id: compositionID) else { throw ProjectError.invalidOperation("Composition does not exist.") }
            guard composition.width != width || composition.height != height else { throw ProjectError.invalidOperation("Composition dimensions are already set to the requested values.") }
            guard (1...8192).contains(width), (1...8192).contains(height) else { throw ProjectError.invalidValue("Composition dimensions must be between 1 and 8192 pixels.") }
            forward = .setCompositionDimensions(id: compositionID, beforeWidth: composition.width, beforeHeight: composition.height, afterWidth: width, afterHeight: height)

        case .setCompositionDuration(let compositionID, let duration):
            guard let composition = document.composition(id: compositionID) else { throw ProjectError.invalidOperation("Composition does not exist.") }
            guard duration > .zero else { throw ProjectError.invalidValue("Composition duration must be positive.") }
            guard duration != composition.duration else { throw ProjectError.invalidOperation("Composition duration is already set to the requested value.") }
            forward = .setCompositionDuration(id: compositionID, before: composition.duration, after: duration)

        case .setCompositionFrameRate(let compositionID, let frameRate):
            guard let composition = document.composition(id: compositionID) else { throw ProjectError.invalidOperation("Composition does not exist.") }
            guard frameRate > .zero else { throw ProjectError.invalidValue("Composition frame rate must be positive.") }
            guard frameRate != composition.frameRate else { throw ProjectError.invalidOperation("Composition frame rate is already set to the requested value.") }
            forward = .setCompositionFrameRate(id: compositionID, before: composition.frameRate, after: frameRate)

        case .setCompositionBackground(let compositionID, let color):
            guard let composition = document.composition(id: compositionID) else { throw ProjectError.invalidOperation("Composition does not exist.") }
            _ = try color.validated()
            guard color != composition.backgroundColor else { throw ProjectError.invalidOperation("Composition background is already set to the requested value.") }
            forward = .setCompositionBackground(id: compositionID, before: composition.backgroundColor, after: color)

        case .insertLayer(let layer, let compositionID, let index):
            guard let composition = document.composition(id: compositionID) else { throw ProjectError.invalidOperation("Composition does not exist.") }
            guard layer.compositionID == compositionID else { throw ProjectError.invalidValue("Inserted layer ownership does not match the requested composition.") }
            guard !document.layerRegistry.contains(where: { $0.id == layer.id }) else { throw ProjectError.duplicateIdentity("layer") }
            guard (0...composition.layerIDs.count).contains(index) else { throw ProjectError.invalidOperation("Layer insertion index is outside the composition order.") }
            forward = .insertLayer(layer, compositionID: compositionID, index: index)

        case .removeLayer(let layerID):
            let layer = try editableLayer(id: layerID, in: document)
            guard let composition = document.composition(id: layer.compositionID), let index = composition.layerIDs.firstIndex(of: layerID) else { throw ProjectError.invalidOperation("Layer ownership is inconsistent.") }
            forward = .removeLayer(layer, compositionID: composition.id, index: index)

        case .duplicateLayer(let sourceID, let duplicateID, let index):
            let source = try editableLayer(id: sourceID, in: document)
            guard !document.layerRegistry.contains(where: { $0.id == duplicateID }) else { throw ProjectError.duplicateIdentity("layer") }
            guard let composition = document.composition(id: source.compositionID), (0...composition.layerIDs.count).contains(index) else { throw ProjectError.invalidOperation("Duplicate layer insertion index is outside the composition order.") }
            var duplicate = source
            duplicate.id = duplicateID
            duplicate.name = source.name + " Copy"
            duplicate.locked = false
            forward = .duplicateLayer(sourceLayerID: sourceID, duplicate: duplicate, compositionID: source.compositionID, index: index)

        case .renameLayer(let layerID, let nextName):
            let layer = try editableLayer(id: layerID, in: document)
            let normalized = nextName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { throw ProjectError.invalidValue("Layer name must not be empty.") }
            guard normalized != layer.name else { throw ProjectError.invalidOperation("Layer name is already set to the requested value.") }
            forward = .renameLayer(id: layerID, before: layer.name, after: normalized)

        case .reorderLayer(let compositionID, let layerID, let toIndex):
            let layer = try editableLayer(id: layerID, in: document)
            guard layer.compositionID == compositionID, let composition = document.composition(id: compositionID), let beforeIndex = composition.layerIDs.firstIndex(of: layerID) else { throw ProjectError.invalidOperation("Layer does not belong to the requested composition.") }
            guard composition.layerIDs.indices.contains(toIndex) else { throw ProjectError.invalidOperation("Layer reorder index is outside the composition order.") }
            guard beforeIndex != toIndex else { throw ProjectError.invalidOperation("Layer is already at the requested index.") }
            forward = .reorderLayer(compositionID: compositionID, layerID: layerID, beforeIndex: beforeIndex, afterIndex: toIndex)

        case .setLayerEnabled(let layerID, let value):
            let layer = try editableLayer(id: layerID, in: document)
            guard layer.enabled != value else { throw ProjectError.invalidOperation("Layer enabled state is already set to the requested value.") }
            forward = .setLayerEnabled(id: layerID, before: layer.enabled, after: value)

        case .setLayerLocked(let layerID, let value):
            guard let layer = document.layer(id: layerID) else { throw ProjectError.invalidOperation("Layer does not exist.") }
            guard layer.locked != value else { throw ProjectError.invalidOperation("Layer locked state is already set to the requested value.") }
            forward = .setLayerLocked(id: layerID, before: layer.locked, after: value)

        case .setLayerSolo(let layerID, let value):
            let layer = try editableLayer(id: layerID, in: document)
            guard layer.solo != value else { throw ProjectError.invalidOperation("Layer solo state is already set to the requested value.") }
            forward = .setLayerSolo(id: layerID, before: layer.solo, after: value)

        case .setLayerTiming(let layerID, let value):
            let layer = try editableLayer(id: layerID, in: document)
            guard value != layer.timing else { throw ProjectError.invalidOperation("Layer timing is already set to the requested value.") }
            if let composition = document.composition(id: layer.compositionID) { _ = try value.validated(for: composition) }
            forward = .setLayerTiming(id: layerID, before: layer.timing, after: value)

        case .setLayerTransform(let layerID, let value):
            let layer = try editableLayer(id: layerID, in: document)
            _ = try value.validated()
            guard value != layer.transform else { throw ProjectError.invalidOperation("Layer transform is already set to the requested value.") }
            forward = .setLayerTransform(id: layerID, before: layer.transform, after: value)

        case .setLayerBlendMode(let layerID, let value):
            let layer = try editableLayer(id: layerID, in: document)
            guard value != layer.blendMode else { throw ProjectError.invalidOperation("Layer blend mode is already set to the requested value.") }
            forward = .setLayerBlendMode(id: layerID, before: layer.blendMode, after: value)

        case .setLayerSource(let layerID, let value):
            let layer = try editableLayer(id: layerID, in: document)
            guard value != layer.source else { throw ProjectError.invalidOperation("Layer source is already set to the requested value.") }
            forward = .setLayerSource(id: layerID, before: layer.source, after: value)

        case .setLayerOperations(let layerID, let value):
            let layer = try editableLayer(id: layerID, in: document)
            for operation in value { _ = try operation.validated() }
            guard value != layer.operations else { throw ProjectError.invalidOperation("Layer operations are already set to the requested value.") }
            forward = .setLayerOperations(id: layerID, before: layer.operations, after: value)
        }

        return ProjectTransition(commandID: request.commandID, projectID: request.projectID, baseRevision: request.baseRevision, timestamp: request.timestamp, mergeKey: request.mergeKey, forward: forward, inverse: forward.inverse)
    }

    public func apply(_ transition: ProjectTransition, to document: ProjectDocument) throws -> ProjectDocument {
        guard transition.projectID == document.projectID else { throw ProjectError.invalidProjectIdentity }
        guard transition.baseRevision == document.revision else { throw ProjectError.staleBaseRevision(expected: transition.baseRevision, actual: document.revision) }
        guard transition.inverse == transition.forward.inverse else { throw ProjectError.invalidInverseOperation("The transition inverse does not reverse the forward mutation.") }
        guard document.revision < UInt64.max else { throw ProjectError.invalidRevision }
        var changed = document
        try apply(transition.forward, to: &changed)
        changed.revision += 1
        changed.metadata.modifiedAt = transition.timestamp
        changed.metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion
        return try changed.validated()
    }

    public func apply(_ record: ProjectCommandRecord, to document: ProjectDocument) throws -> ProjectDocument {
        try apply(ProjectTransition(commandID: record.commandID, projectID: record.projectID, baseRevision: record.baseRevision, timestamp: record.timestamp, mergeKey: record.mergeKey, forward: record.forwardOperation, inverse: record.inverseOperation), to: document)
    }

    private func validateNewComposition(_ composition: ProjectComposition, ownedLayers: [ProjectLayer], against document: ProjectDocument) throws {
        guard !document.compositionRegistry.contains(where: { $0.id == composition.id }) else { throw ProjectError.duplicateIdentity("composition") }
        let layerIDs = ownedLayers.map(\.id)
        guard Set(layerIDs).count == layerIDs.count, Set(layerIDs) == Set(composition.layerIDs), layerIDs.count == composition.layerIDs.count else { throw ProjectError.invalidValue("Owned layers must exactly match the composition layer order identities.") }
        guard ownedLayers.allSatisfy({ $0.compositionID == composition.id }) else { throw ProjectError.invalidValue("Owned layers must belong to the created composition.") }
        guard !layerIDs.contains(where: { id in document.layerRegistry.contains(where: { $0.id == id }) }) else { throw ProjectError.duplicateIdentity("layer") }
    }

    private func editableLayer(id: VertexID, in document: ProjectDocument) throws -> ProjectLayer {
        guard let layer = document.layer(id: id) else { throw ProjectError.invalidOperation("Layer does not exist.") }
        guard !layer.locked else { throw ProjectError.invalidOperation("Locked layers must be explicitly unlocked before editing.") }
        return layer
    }

    private func apply(_ mutation: ProjectMutation, to document: inout ProjectDocument) throws {
        switch mutation {
        case .renameProject(let before, let after):
            guard document.metadata.name == before else { throw ProjectError.invalidOperation("Project name precondition did not match.") }
            guard !after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ProjectError.invalidValue("Project name must not be empty.") }
            document.metadata.name = after
        case .registerMedia(let reference):
            _ = try reference.validated()
            guard !document.mediaRegistry.contains(where: { $0.id == reference.id }) else { throw ProjectError.duplicateIdentity("media") }
            document.mediaRegistry.append(reference)
        case .removeMedia(let reference):
            guard let index = document.mediaRegistry.firstIndex(of: reference) else { throw ProjectError.invalidOperation("The media reference to remove does not match project state.") }
            document.mediaRegistry.remove(at: index)
            if document.selectedMediaID == reference.id { document.selectedMediaID = nil }
        case .relinkMedia(let mediaID, let before, let after):
            guard let index = document.mediaRegistry.firstIndex(where: { $0.id == mediaID }) else { throw ProjectError.missingMedia(mediaID.rawValue) }
            guard document.mediaRegistry[index].locator == before else { throw ProjectError.invalidOperation("Media locator precondition did not match.") }
            document.mediaRegistry[index].locator = after
            document.mediaRegistry[index].availabilityStatus = after.embeddedPath == nil ? .external : .embedded
        case .setEmbeddedPath(let mediaID, let before, let after):
            guard let index = document.mediaRegistry.firstIndex(where: { $0.id == mediaID }) else { throw ProjectError.missingMedia(mediaID.rawValue) }
            guard document.mediaRegistry[index].locator.embeddedPath == before else { throw ProjectError.invalidOperation("Embedded-path precondition did not match.") }
            document.mediaRegistry[index].locator.embeddedPath = after
            document.mediaRegistry[index].availabilityStatus = after == nil ? .external : .embedded
        case .selectMedia(let before, let after):
            guard document.selectedMediaID == before else { throw ProjectError.invalidOperation("Selected-media precondition did not match.") }
            if let after, !document.mediaRegistry.contains(where: { $0.id == after }) { throw ProjectError.missingMedia(after.rawValue) }
            document.selectedMediaID = after
        case .setRenderParameter(let parameter, let before, let after):
            guard before.isFinite, after.isFinite else { throw ProjectError.invalidValue("Render parameters must be finite.") }
            guard document.renderSettings.value(for: parameter) == before else { throw ProjectError.invalidOperation("Render-parameter precondition did not match.") }
            document.renderSettings.set(after, for: parameter)
            _ = try document.renderSettings.validated()
        case .setRenderBoolean(let parameter, let before, let after):
            switch parameter {
            case .inverted:
                guard document.renderSettings.inverted == before else { throw ProjectError.invalidOperation("Render-boolean precondition did not match.") }
                document.renderSettings.inverted = after
            }
        case .setOutputDimensions(let beforeWidth, let beforeHeight, let afterWidth, let afterHeight):
            guard document.renderSettings.outputWidth == beforeWidth, document.renderSettings.outputHeight == beforeHeight else { throw ProjectError.invalidOperation("Output-dimension precondition did not match.") }
            document.renderSettings.outputWidth = afterWidth
            document.renderSettings.outputHeight = afterHeight
            _ = try document.renderSettings.validated()
        case .setProjectColor(let before, let after):
            guard document.settings.color == before else { throw ProjectError.invalidOperation("Project-color precondition did not match.") }
            document.settings.color = after
        case .createComposition(let composition, let ownedLayers, let registryIndex):
            guard (0...document.compositionRegistry.count).contains(registryIndex), !document.compositionRegistry.contains(where: { $0.id == composition.id }) else { throw ProjectError.invalidOperation("Composition creation precondition did not match.") }
            try validateNewComposition(composition, ownedLayers: ownedLayers, against: document)
            document.compositionRegistry.insert(composition, at: registryIndex)
            document.layerRegistry.append(contentsOf: ownedLayers)
        case .removeComposition(let composition, let ownedLayers, let registryIndex):
            guard document.compositionRegistry.indices.contains(registryIndex), document.compositionRegistry[registryIndex] == composition else { throw ProjectError.invalidOperation("Composition removal precondition did not match.") }
            guard document.activeCompositionID != composition.id else { throw ProjectError.invalidOperation("The active composition cannot be removed.") }
            guard !document.layerRegistry.contains(where: { layer in
                guard layer.compositionID != composition.id else { return false }
                if case .composition(let targetID, _) = layer.source { return targetID == composition.id }
                return false
            }) else { throw ProjectError.invalidOperation("A referenced composition cannot be removed.") }
            let actualLayers = composition.layerIDs.compactMap { document.layer(id: $0) }
            guard actualLayers == ownedLayers else { throw ProjectError.invalidOperation("Owned-layer removal precondition did not match.") }
            let ownedIDs = Set(ownedLayers.map(\.id))
            document.layerRegistry.removeAll { ownedIDs.contains($0.id) }
            document.compositionRegistry.remove(at: registryIndex)
            if let selectedLayerID = document.selectedLayerID, ownedIDs.contains(selectedLayerID) { document.selectedLayerID = nil }
        case .duplicateComposition(let sourceID, let composition, let layers, let registryIndex):
            guard document.composition(id: sourceID) != nil else { throw ProjectError.invalidOperation("Duplicate source composition no longer exists.") }
            try validateNewComposition(composition, ownedLayers: layers, against: document)
            guard (0...document.compositionRegistry.count).contains(registryIndex) else { throw ProjectError.invalidOperation("Duplicate composition insertion index is outside the registry.") }
            document.compositionRegistry.insert(composition, at: registryIndex)
            document.layerRegistry.append(contentsOf: layers)
        case .removeDuplicatedComposition(let sourceID, let composition, let layers, let registryIndex):
            guard document.composition(id: sourceID) != nil, document.compositionRegistry.indices.contains(registryIndex), document.compositionRegistry[registryIndex] == composition else { throw ProjectError.invalidOperation("Duplicated composition removal precondition did not match.") }
            let actualLayers = composition.layerIDs.compactMap { document.layer(id: $0) }
            guard actualLayers == layers else { throw ProjectError.invalidOperation("Duplicated composition layers no longer match.") }
            let layerIDs = Set(layers.map(\.id))
            document.layerRegistry.removeAll { layerIDs.contains($0.id) }
            document.compositionRegistry.remove(at: registryIndex)
            if let selectedLayerID = document.selectedLayerID, layerIDs.contains(selectedLayerID) { document.selectedLayerID = nil }
        case .renameComposition(let id, let before, let after):
            guard let index = document.compositionRegistry.firstIndex(where: { $0.id == id }), document.compositionRegistry[index].name == before else { throw ProjectError.invalidOperation("Composition-name precondition did not match.") }
            document.compositionRegistry[index].name = after
        case .setCompositionDimensions(let id, let beforeWidth, let beforeHeight, let afterWidth, let afterHeight):
            guard let index = document.compositionRegistry.firstIndex(where: { $0.id == id }), document.compositionRegistry[index].width == beforeWidth, document.compositionRegistry[index].height == beforeHeight else { throw ProjectError.invalidOperation("Composition-dimension precondition did not match.") }
            document.compositionRegistry[index].width = afterWidth
            document.compositionRegistry[index].height = afterHeight
        case .setCompositionDuration(let id, let before, let after):
            guard let index = document.compositionRegistry.firstIndex(where: { $0.id == id }), document.compositionRegistry[index].duration == before else { throw ProjectError.invalidOperation("Composition-duration precondition did not match.") }
            document.compositionRegistry[index].duration = after
        case .setCompositionFrameRate(let id, let before, let after):
            guard let index = document.compositionRegistry.firstIndex(where: { $0.id == id }), document.compositionRegistry[index].frameRate == before else { throw ProjectError.invalidOperation("Composition-frame-rate precondition did not match.") }
            document.compositionRegistry[index].frameRate = after
        case .setCompositionBackground(let id, let before, let after):
            guard let index = document.compositionRegistry.firstIndex(where: { $0.id == id }), document.compositionRegistry[index].backgroundColor == before else { throw ProjectError.invalidOperation("Composition-background precondition did not match.") }
            document.compositionRegistry[index].backgroundColor = after
        case .insertLayer(let layer, let compositionID, let index):
            guard let compositionIndex = document.compositionRegistry.firstIndex(where: { $0.id == compositionID }), (0...document.compositionRegistry[compositionIndex].layerIDs.count).contains(index), layer.compositionID == compositionID, !document.layerRegistry.contains(where: { $0.id == layer.id }) else { throw ProjectError.invalidOperation("Layer insertion precondition did not match.") }
            document.layerRegistry.append(layer)
            document.compositionRegistry[compositionIndex].layerIDs.insert(layer.id, at: index)
        case .removeLayer(let layer, let compositionID, let index):
            guard let compositionIndex = document.compositionRegistry.firstIndex(where: { $0.id == compositionID }), document.compositionRegistry[compositionIndex].layerIDs.indices.contains(index), document.compositionRegistry[compositionIndex].layerIDs[index] == layer.id, let registryIndex = document.layerRegistry.firstIndex(of: layer) else { throw ProjectError.invalidOperation("Layer removal precondition did not match.") }
            document.compositionRegistry[compositionIndex].layerIDs.remove(at: index)
            document.layerRegistry.remove(at: registryIndex)
            if document.selectedLayerID == layer.id { document.selectedLayerID = nil }
        case .duplicateLayer(let sourceLayerID, let duplicate, let compositionID, let index):
            guard document.layer(id: sourceLayerID) != nil, let compositionIndex = document.compositionRegistry.firstIndex(where: { $0.id == compositionID }), (0...document.compositionRegistry[compositionIndex].layerIDs.count).contains(index), duplicate.compositionID == compositionID, !document.layerRegistry.contains(where: { $0.id == duplicate.id }) else { throw ProjectError.invalidOperation("Layer duplication precondition did not match.") }
            document.layerRegistry.append(duplicate)
            document.compositionRegistry[compositionIndex].layerIDs.insert(duplicate.id, at: index)
        case .removeDuplicatedLayer(let sourceLayerID, let duplicate, let compositionID, let index):
            guard document.layer(id: sourceLayerID) != nil, let compositionIndex = document.compositionRegistry.firstIndex(where: { $0.id == compositionID }), document.compositionRegistry[compositionIndex].layerIDs.indices.contains(index), document.compositionRegistry[compositionIndex].layerIDs[index] == duplicate.id, let registryIndex = document.layerRegistry.firstIndex(of: duplicate) else { throw ProjectError.invalidOperation("Duplicated-layer removal precondition did not match.") }
            document.compositionRegistry[compositionIndex].layerIDs.remove(at: index)
            document.layerRegistry.remove(at: registryIndex)
            if document.selectedLayerID == duplicate.id { document.selectedLayerID = nil }
        case .renameLayer(let id, let before, let after):
            guard let index = document.layerRegistry.firstIndex(where: { $0.id == id }), document.layerRegistry[index].name == before else { throw ProjectError.invalidOperation("Layer-name precondition did not match.") }
            document.layerRegistry[index].name = after
        case .reorderLayer(let compositionID, let layerID, let beforeIndex, let afterIndex):
            guard let compositionIndex = document.compositionRegistry.firstIndex(where: { $0.id == compositionID }) else { throw ProjectError.invalidOperation("Composition does not exist.") }
            var order = document.compositionRegistry[compositionIndex].layerIDs
            guard order.indices.contains(beforeIndex), order[beforeIndex] == layerID else { throw ProjectError.invalidOperation("Layer reorder precondition did not match.") }
            let removed = order.remove(at: beforeIndex)
            guard (0...order.count).contains(afterIndex) else { throw ProjectError.invalidOperation("Layer reorder destination is outside the composition order.") }
            order.insert(removed, at: afterIndex)
            document.compositionRegistry[compositionIndex].layerIDs = order
        case .setLayerEnabled(let id, let before, let after):
            try setLayer(id: id, in: &document, matching: { $0.enabled == before }) { $0.enabled = after }
        case .setLayerLocked(let id, let before, let after):
            try setLayer(id: id, in: &document, matching: { $0.locked == before }) { $0.locked = after }
        case .setLayerSolo(let id, let before, let after):
            try setLayer(id: id, in: &document, matching: { $0.solo == before }) { $0.solo = after }
        case .setLayerTiming(let id, let before, let after):
            try setLayer(id: id, in: &document, matching: { $0.timing == before }) { $0.timing = after }
        case .setLayerTransform(let id, let before, let after):
            try setLayer(id: id, in: &document, matching: { $0.transform == before }) { $0.transform = after }
        case .setLayerBlendMode(let id, let before, let after):
            try setLayer(id: id, in: &document, matching: { $0.blendMode == before }) { $0.blendMode = after }
        case .setLayerSource(let id, let before, let after):
            try setLayer(id: id, in: &document, matching: { $0.source == before }) { $0.source = after }
        case .setLayerOperations(let id, let before, let after):
            try setLayer(id: id, in: &document, matching: { $0.operations == before }) { $0.operations = after }
        }
    }

    private func setLayer(id: VertexID, in document: inout ProjectDocument, matching predicate: (ProjectLayer) -> Bool, mutate: (inout ProjectLayer) -> Void) throws {
        guard let index = document.layerRegistry.firstIndex(where: { $0.id == id }), predicate(document.layerRegistry[index]) else { throw ProjectError.invalidOperation("Layer property precondition did not match.") }
        mutate(&document.layerRegistry[index])
    }
}

@available(*, deprecated, message: "Legacy WAL compatibility only; use ProjectCommandRequest and ProjectTransition.")
public struct ProjectCommandRecord: Codable, Equatable, Sendable, Identifiable {
    public var commandID: VertexID
    public var projectID: VertexID
    public var baseRevision: UInt64
    public var timestamp: Date
    public var mergeKey: String?
    public var forwardOperation: ProjectOperation
    public var inverseOperation: ProjectOperation
    public var id: VertexID { commandID }

    public init(commandID: VertexID = VertexID(), projectID: VertexID, baseRevision: UInt64, timestamp: Date = Date(), mergeKey: String? = nil, forwardOperation: ProjectOperation, inverseOperation: ProjectOperation) {
        self.commandID = commandID
        self.projectID = projectID
        self.baseRevision = baseRevision
        self.timestamp = timestamp
        self.mergeKey = mergeKey
        self.forwardOperation = forwardOperation
        self.inverseOperation = inverseOperation
    }

    public init(project: ProjectDocument, commandID: VertexID = VertexID(), operation: ProjectOperation, mergeKey: String? = nil, timestamp: Date = Date()) {
        self.init(commandID: commandID, projectID: project.projectID, baseRevision: project.revision, timestamp: timestamp, mergeKey: mergeKey, forwardOperation: operation, inverseOperation: operation.inverse)
    }

    public static func settingExposure(project: ProjectDocument, commandID: VertexID = VertexID(), from: Double, to: Double, timestamp: Date = Date()) -> ProjectCommandRecord {
        ProjectCommandRecord(project: project, commandID: commandID, operation: .setRenderParameter(.exposure, before: from, after: to), mergeKey: "render.exposure", timestamp: timestamp)
    }
}
