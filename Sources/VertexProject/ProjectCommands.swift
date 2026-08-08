import Foundation
import VertexCore

public struct ProjectCommandEngine: Sendable {
    public init() {}

    public func prepare(
        _ request: ProjectCommandRequest,
        for document: ProjectDocument
    ) throws -> ProjectTransition {
        guard request.projectID == document.projectID else { throw ProjectError.invalidProjectIdentity }
        guard request.baseRevision == document.revision else {
            throw ProjectError.staleBaseRevision(expected: request.baseRevision, actual: document.revision)
        }

        let forward: ProjectMutation
        switch request.payload {
        case .renameProject(let nextName):
            let next = nextName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !next.isEmpty, next != document.metadata.name else { throw ProjectError.invalidOperation("Project name is invalid or unchanged.") }
            forward = .renameProject(before: document.metadata.name, after: next)

        case .registerMedia(let reference):
            _ = try reference.validated()
            guard !document.mediaRegistry.contains(where: { $0.id == reference.id }) else { throw ProjectError.duplicateIdentity("media") }
            forward = .registerMedia(reference)

        case .removeMedia(let mediaID):
            guard let reference = document.mediaRegistry.first(where: { $0.id == mediaID }) else { throw ProjectError.missingMedia(mediaID.rawValue) }
            let layerReferenced = document.layerRegistry.contains { layer in
                if case .media(let id, _) = layer.source { return id == mediaID }
                return false
            }
            let aiReferenced = document.aiAssetRegistry.contains {
                $0.sourceMediaID == mediaID || $0.outputMediaID == mediaID
            }
            guard !layerReferenced, !aiReferenced else {
                throw ProjectError.invalidOperation("Media referenced by a layer or AI asset cannot be removed.")
            }
            forward = .removeMedia(reference)

        case .relinkMedia(let mediaID, let locator):
            guard let reference = document.mediaRegistry.first(where: { $0.id == mediaID }) else { throw ProjectError.missingMedia(mediaID.rawValue) }
            guard reference.locator != locator else { throw ProjectError.invalidOperation("Media locator is unchanged.") }
            forward = .relinkMedia(mediaID: mediaID, before: reference.locator, after: locator)

        case .setEmbeddedPath(let mediaID, let path):
            guard let reference = document.mediaRegistry.first(where: { $0.id == mediaID }) else { throw ProjectError.missingMedia(mediaID.rawValue) }
            guard reference.locator.embeddedPath != path else { throw ProjectError.invalidOperation("Embedded path is unchanged.") }
            forward = .setEmbeddedPath(mediaID: mediaID, before: reference.locator.embeddedPath, after: path)

        case .registerAIAsset(let asset):
            guard !document.aiAssetRegistry.contains(where: { $0.id == asset.id }) else { throw ProjectError.duplicateIdentity("AI asset") }
            guard !document.aiAssetRegistry.contains(where: { $0.outputMediaID == asset.outputMediaID }) else {
                throw ProjectError.invalidOperation("AI output media is already registered by another AI asset.")
            }
            _ = try asset.validated(in: document)
            forward = .registerAIAsset(asset)

        case .removeAIAsset(let id):
            guard let asset = document.aiAsset(id: id) else {
                throw ProjectError.invalidOperation("AI asset is missing.")
            }
            forward = .removeAIAsset(asset)


        case .registerBakedAIEffect(let registration):
            _ = try registration.validated(in: document)
            forward = .registerBakedAIEffect(registration, previousSelectedLayerID: document.selectedLayerID)

        case .setRenderParameter(let parameter, let value):
            guard value.isFinite else { throw ProjectError.invalidValue("Render parameter must be finite.") }
            let previous = document.renderSettings.value(for: parameter)
            guard previous != value else { throw ProjectError.invalidOperation("Render parameter is unchanged.") }
            var candidate = document.renderSettings
            candidate.set(value, for: parameter)
            _ = try candidate.validated()
            forward = .setRenderParameter(parameter, before: previous, after: value)

        case .setRenderBoolean(let parameter, let value):
            switch parameter {
            case .inverted:
                let previous = document.renderSettings.inverted
                guard previous != value else { throw ProjectError.invalidOperation("Render boolean is unchanged.") }
                forward = .setRenderBoolean(parameter, before: previous, after: value)
            }

        case .setOutputDimensions(let width, let height):
            let previous = document.renderSettings
            guard previous.outputWidth != width || previous.outputHeight != height else { throw ProjectError.invalidOperation("Output dimensions are unchanged.") }
            var candidate = previous
            candidate.outputWidth = width
            candidate.outputHeight = height
            _ = try candidate.validated()
            forward = .setOutputDimensions(beforeWidth: previous.outputWidth, beforeHeight: previous.outputHeight, afterWidth: width, afterHeight: height)

        case .setProjectColor(let color):
            guard color != document.settings.color else { throw ProjectError.invalidOperation("Project color is unchanged.") }
            forward = .setProjectColor(before: document.settings.color, after: color)

        case .insertComposition(let composition, let ownedLayers, let index):
            guard !document.compositionRegistry.contains(where: { $0.id == composition.id }) else { throw ProjectError.duplicateIdentity("composition") }
            guard document.compositionRegistry.indices.contains(index) || index == document.compositionRegistry.endIndex else { throw ProjectError.invalidOperation("Composition insertion index is invalid.") }
            guard Set(ownedLayers.map(\.id)).count == ownedLayers.count,
                  ownedLayers.allSatisfy({ $0.compositionID == composition.id }),
                  composition.layerIDs == ownedLayers.map(\.id) else {
                throw ProjectError.invalidOperation("Composition-owned layer payload is inconsistent.")
            }
            forward = .insertComposition(composition, ownedLayers: ownedLayers, registryIndex: index)

        case .removeComposition(let id):
            guard document.compositionRegistry.count > 1,
                  let index = document.compositionRegistry.firstIndex(where: { $0.id == id }) else {
                throw ProjectError.invalidOperation("Composition cannot be removed.")
            }
            guard document.activeCompositionID != id else { throw ProjectError.invalidOperation("Select another active composition before removal.") }
            let referenced = document.layerRegistry.contains { layer in
                guard layer.compositionID != id, case .composition(let target, _) = layer.source else { return false }
                return target == id
            }
            guard !referenced else { throw ProjectError.invalidOperation("A nested layer references this composition.") }
            forward = .removeComposition(document.compositionRegistry[index], ownedLayers: document.layers(in: id), registryIndex: index)

        case .renameComposition(let id, let name):
            guard let composition = document.composition(id: id) else { throw ProjectError.invalidOperation("Composition is missing.") }
            let next = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !next.isEmpty, next != composition.name else { throw ProjectError.invalidOperation("Composition name is invalid or unchanged.") }
            forward = .renameComposition(compositionID: id, before: composition.name, after: next)

        case .setCompositionDimensions(let id, let width, let height):
            guard let composition = document.composition(id: id), composition.width != width || composition.height != height else { throw ProjectError.invalidOperation("Composition dimensions are unchanged or composition is missing.") }
            guard (1...8192).contains(width), (1...8192).contains(height) else { throw ProjectError.invalidValue("Composition dimensions must be 1...8192.") }
            forward = .setCompositionDimensions(compositionID: id, beforeWidth: composition.width, beforeHeight: composition.height, afterWidth: width, afterHeight: height)

        case .setCompositionDuration(let id, let duration):
            guard let composition = document.composition(id: id), duration > .zero, duration != composition.duration else { throw ProjectError.invalidOperation("Composition duration is invalid or unchanged.") }
            guard document.layers(in: id).allSatisfy({ $0.timing.outPoint <= duration }) else { throw ProjectError.invalidOperation("A layer extends beyond the requested composition duration.") }
            forward = .setCompositionDuration(compositionID: id, before: composition.duration, after: duration)

        case .setCompositionFrameRate(let id, let frameRate):
            guard let composition = document.composition(id: id), frameRate > .zero, frameRate != composition.frameRate else { throw ProjectError.invalidOperation("Composition frame rate is invalid or unchanged.") }
            forward = .setCompositionFrameRate(compositionID: id, before: composition.frameRate, after: frameRate)

        case .setCompositionBackground(let id, let color):
            guard let composition = document.composition(id: id), color != composition.backgroundColor else { throw ProjectError.invalidOperation("Composition background is unchanged or composition is missing.") }
            _ = try color.validated()
            forward = .setCompositionBackground(compositionID: id, before: composition.backgroundColor, after: color)

        case .setCompositionWorkArea(let id, let workArea):
            guard let composition = document.composition(id: id), composition.workArea != workArea else {
                throw ProjectError.invalidOperation("Composition work area is unchanged or composition is missing.")
            }
            if let workArea { _ = try workArea.validated(compositionDuration: composition.duration) }
            forward = .setCompositionWorkArea(compositionID: id, before: composition.workArea, after: workArea)

        case .setCompositionMarkers(let id, let markers):
            guard let composition = document.composition(id: id), composition.markers != markers else {
                throw ProjectError.invalidOperation("Composition markers are unchanged or composition is missing.")
            }
            guard Set(markers.map(\.id)).count == markers.count else { throw ProjectError.duplicateIdentity("composition marker") }
            for marker in markers { _ = try marker.validated(compositionDuration: composition.duration) }
            forward = .setCompositionMarkers(compositionID: id, before: composition.markers, after: markers)

        case .applyTimelineEdit(let compositionID, let result):
            _ = try result.validated(compositionID: compositionID)
            guard let composition = document.composition(id: compositionID),
                  composition.layerIDs == result.beforeLayerOrder,
                  document.layers(in: compositionID) == result.beforeLayers,
                  document.selectedLayerID == result.beforeSelectedLayerID else {
                throw ProjectError.invalidOperation("Timeline mutation precondition does not match the current project.")
            }
            let mutation = ProjectMutation.applyTimelineEdit(compositionID: compositionID, change: result)
            var candidate = document
            try apply(mutation, to: &candidate)
            _ = try candidate.validated()
            forward = mutation

        case .insertLayer(let layer, let index):
            guard !document.layerRegistry.contains(where: { $0.id == layer.id }), let composition = document.composition(id: layer.compositionID) else { throw ProjectError.invalidOperation("Layer already exists or owner composition is missing.") }
            guard composition.layerIDs.indices.contains(index) || index == composition.layerIDs.endIndex else { throw ProjectError.invalidOperation("Layer insertion index is invalid.") }
            _ = try layer.validated(in: document)
            forward = .insertLayer(layer, compositionID: layer.compositionID, index: index)

        case .removeLayer(let id):
            guard let layer = document.layer(id: id), let composition = document.composition(id: layer.compositionID), let index = composition.layerIDs.firstIndex(of: id) else { throw ProjectError.invalidOperation("Layer is missing from its composition order.") }
            guard !layer.locked else { throw ProjectError.invalidOperation("Unlock the layer before removing it.") }
            guard !document.layerRegistry.contains(where: { $0.trackMatte?.sourceLayerID == id }) else {
                throw ProjectError.invalidOperation("A layer used as a track matte cannot be removed until matte references are cleared.")
            }
            guard !document.layerRegistry.contains(where: { $0.parentLayerID == id }) else {
                throw ProjectError.invalidOperation("A parent layer cannot be removed until child parent links are cleared.")
            }
            forward = .removeLayer(layer, compositionID: composition.id, index: index)

        case .reorderLayer(let id, let toIndex):
            let layer = try editableLayer(id, in: document)
            guard let composition = document.composition(id: layer.compositionID), let from = composition.layerIDs.firstIndex(of: id), composition.layerIDs.indices.contains(toIndex), from != toIndex else { throw ProjectError.invalidOperation("Layer reorder is invalid or unchanged.") }
            forward = .reorderLayer(compositionID: composition.id, layerID: id, beforeIndex: from, afterIndex: toIndex)

        case .renameLayer(let id, let name):
            let layer = try editableLayer(id, in: document)
            let next = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !next.isEmpty, next != layer.name else { throw ProjectError.invalidOperation("Layer name is invalid or unchanged.") }
            forward = .renameLayer(layerID: id, before: layer.name, after: next)

        case .setLayerEnabled(let id, let value):
            let layer = try editableLayer(id, in: document)
            guard layer.enabled != value else { throw ProjectError.invalidOperation("Layer enabled state is unchanged.") }
            forward = .setLayerEnabled(layerID: id, before: layer.enabled, after: value)

        case .setLayerLocked(let id, let value):
            guard let layer = document.layer(id: id), layer.locked != value else { throw ProjectError.invalidOperation("Layer lock state is unchanged or layer is missing.") }
            forward = .setLayerLocked(layerID: id, before: layer.locked, after: value)

        case .setLayerSolo(let id, let value):
            let layer = try editableLayer(id, in: document)
            guard layer.solo != value else { throw ProjectError.invalidOperation("Layer solo state is unchanged.") }
            forward = .setLayerSolo(layerID: id, before: layer.solo, after: value)

        case .setLayerTiming(let id, let timing):
            let layer = try editableLayer(id, in: document)
            guard timing != layer.timing, let composition = document.composition(id: layer.compositionID) else { throw ProjectError.invalidOperation("Layer timing is unchanged or owner composition is missing.") }
            _ = try timing.validated(for: composition)
            forward = .setLayerTiming(layerID: id, before: layer.timing, after: timing)

        case .setLayerTransform(let id, let transform):
            let layer = try editableLayer(id, in: document)
            guard transform != layer.transform else { throw ProjectError.invalidOperation("Layer transform is unchanged.") }
            _ = try transform.validated()
            forward = .setLayerTransform(layerID: id, before: layer.transform, after: transform)

        case .setLayerBlendMode(let id, let mode):
            let layer = try editableLayer(id, in: document)
            guard mode != layer.blendMode else { throw ProjectError.invalidOperation("Layer blend mode is unchanged.") }
            forward = .setLayerBlendMode(layerID: id, before: layer.blendMode, after: mode)

        case .setLayerSource(let id, let source):
            let layer = try editableLayer(id, in: document)
            guard source != layer.source else { throw ProjectError.invalidOperation("Layer source is unchanged.") }
            forward = .setLayerSource(layerID: id, before: layer.source, after: source)


        case .setLayerMarkers(let id, let markers):
            let layer = try editableLayer(id, in: document)
            guard layer.markers != markers, let composition = document.composition(id: layer.compositionID) else {
                throw ProjectError.invalidOperation("Layer markers are unchanged or owner composition is missing.")
            }
            guard Set(markers.map(\.id)).count == markers.count else { throw ProjectError.duplicateIdentity("layer marker") }
            for marker in markers { _ = try marker.validated(compositionDuration: composition.duration) }
            forward = .setLayerMarkers(layerID: id, before: layer.markers, after: markers)

        case .setLayerParent(let id, let parentLayerID):
            let layer = try editableLayer(id, in: document)
            guard layer.parentLayerID != parentLayerID else { throw ProjectError.invalidOperation("Layer parent is unchanged.") }
            var candidate = layer
            candidate.parentLayerID = parentLayerID
            var candidateDocument = document
            if let index = candidateDocument.layerRegistry.firstIndex(where: { $0.id == id }) {
                candidateDocument.layerRegistry[index] = candidate
            }
            _ = try candidate.validated(in: candidateDocument)
            forward = .setLayerParent(layerID: id, before: layer.parentLayerID, after: parentLayerID)

        case .setLayerOperations(let id, let operations):
            let layer = try editableLayer(id, in: document)
            guard operations != layer.operations else { throw ProjectError.invalidOperation("Layer operations are unchanged.") }
            for operation in operations { _ = try operation.validated() }
            forward = .setLayerOperations(layerID: id, before: layer.operations, after: operations)


        case .setLayerEffects(let id, let effects):
            let layer = try editableLayer(id, in: document)
            guard effects != layer.effects else { throw ProjectError.invalidOperation("Layer effect stack is unchanged.") }
            var candidate = layer
            candidate.effects = effects
            _ = try candidate.validated(in: document)
            forward = .setLayerEffects(layerID: id, before: layer.effects, after: effects)

        case .insertLayerEffect(let id, let effect, let index):
            let layer = try editableLayer(id, in: document)
            guard !layer.effects.contains(where: { $0.id == effect.id }),
                  layer.effects.indices.contains(index) || index == layer.effects.endIndex else {
                throw ProjectError.invalidOperation("Effect insertion index or identity is invalid.")
            }
            _ = try effect.validated()
            var next = layer.effects
            next.insert(effect, at: index)
            var candidate = layer; candidate.effects = next
            _ = try candidate.validated(in: document)
            forward = .setLayerEffects(layerID: id, before: layer.effects, after: next)

        case .removeLayerEffect(let id, let effectID):
            let layer = try editableLayer(id, in: document)
            guard let index = layer.effects.firstIndex(where: { $0.id == effectID }) else {
                throw ProjectError.invalidOperation("Effect is missing.")
            }
            guard !layer.animationChannels.contains(where: {
                if case .effect(let referenced, _, _) = $0.property { return referenced == effectID }
                return false
            }) else {
                throw ProjectError.invalidOperation("Remove effect animation channels before deleting the effect.")
            }
            var next = layer.effects; next.remove(at: index)
            forward = .setLayerEffects(layerID: id, before: layer.effects, after: next)

        case .moveLayerEffect(let id, let effectID, let toIndex):
            let layer = try editableLayer(id, in: document)
            guard let from = layer.effects.firstIndex(where: { $0.id == effectID }),
                  layer.effects.indices.contains(toIndex), from != toIndex else {
                throw ProjectError.invalidOperation("Effect reorder is invalid or unchanged.")
            }
            var next = layer.effects
            let effect = next.remove(at: from)
            next.insert(effect, at: toIndex)
            forward = .setLayerEffects(layerID: id, before: layer.effects, after: next)

        case .setLayerEffectEnabled(let id, let effectID, let value):
            let layer = try editableLayer(id, in: document)
            guard let index = layer.effects.firstIndex(where: { $0.id == effectID }), layer.effects[index].enabled != value else {
                throw ProjectError.invalidOperation("Effect enabled state is unchanged or effect is missing.")
            }
            var next = layer.effects; next[index].enabled = value
            forward = .setLayerEffects(layerID: id, before: layer.effects, after: next)

        case .setLayerMotionState(let id, let animationChannels, let masks, let trackMatte):
            let layer = try editableLayer(id, in: document)
            guard layer.animationChannels != animationChannels || layer.masks != masks || layer.trackMatte != trackMatte else {
                throw ProjectError.invalidOperation("Layer motion, mask, and matte state is unchanged.")
            }
            var candidate = layer
            candidate.animationChannels = animationChannels
            candidate.masks = masks
            candidate.trackMatte = trackMatte
            _ = try candidate.validated(in: document)
            forward = .setLayerMotionState(
                layerID: id,
                beforeAnimationChannels: layer.animationChannels,
                afterAnimationChannels: animationChannels,
                beforeMasks: layer.masks,
                afterMasks: masks,
                beforeTrackMatte: layer.trackMatte,
                afterTrackMatte: trackMatte
            )
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

    private func editableLayer(_ id: VertexID, in document: ProjectDocument) throws -> ProjectLayer {
        guard let layer = document.layer(id: id) else { throw ProjectError.invalidOperation("Layer is missing.") }
        guard !layer.locked else { throw ProjectError.invalidOperation("Unlock the layer before editing it.") }
        return layer
    }

    private func apply(_ mutation: ProjectMutation, to document: inout ProjectDocument) throws {
        switch mutation {
        case .renameProject(let before, let after):
            guard document.metadata.name == before else { throw ProjectError.invalidOperation("Project name precondition did not match.") }
            document.metadata.name = after
        case .registerMedia(let reference):
            guard !document.mediaRegistry.contains(where: { $0.id == reference.id }) else { throw ProjectError.duplicateIdentity("media") }
            document.mediaRegistry.append(try reference.validated())
        case .removeMedia(let reference):
            guard let index = document.mediaRegistry.firstIndex(of: reference) else { throw ProjectError.invalidOperation("Media removal precondition did not match.") }
            guard !document.aiAssetRegistry.contains(where: { $0.sourceMediaID == reference.id || $0.outputMediaID == reference.id }) else {
                throw ProjectError.invalidOperation("AI-referenced media cannot be removed before its AI asset.")
            }
            document.mediaRegistry.remove(at: index)
            if document.selectedMediaID == reference.id { document.selectedMediaID = nil }
        case .relinkMedia(let id, let before, let after):
            guard let index = document.mediaRegistry.firstIndex(where: { $0.id == id }), document.mediaRegistry[index].locator == before else { throw ProjectError.invalidOperation("Media locator precondition did not match.") }
            document.mediaRegistry[index].locator = after
            document.mediaRegistry[index].availabilityStatus = after.embeddedPath == nil ? .external : .embedded
        case .setEmbeddedPath(let id, let before, let after):
            guard let index = document.mediaRegistry.firstIndex(where: { $0.id == id }), document.mediaRegistry[index].locator.embeddedPath == before else { throw ProjectError.invalidOperation("Embedded path precondition did not match.") }
            document.mediaRegistry[index].locator.embeddedPath = after
            document.mediaRegistry[index].availabilityStatus = after == nil ? .external : .embedded
        case .selectMedia(let before, let after):
            guard document.selectedMediaID == before else { throw ProjectError.invalidOperation("Selected media precondition did not match.") }
            document.selectedMediaID = after
        case .registerAIAsset(let asset):
            guard !document.aiAssetRegistry.contains(where: { $0.id == asset.id || $0.outputMediaID == asset.outputMediaID }) else {
                throw ProjectError.invalidOperation("AI asset registration precondition did not match.")
            }
            _ = try asset.validated(in: document)
            document.aiAssetRegistry.append(asset)
        case .removeAIAsset(let asset):
            guard let index = document.aiAssetRegistry.firstIndex(of: asset) else {
                throw ProjectError.invalidOperation("AI asset removal precondition did not match.")
            }
            document.aiAssetRegistry.remove(at: index)


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
        case .setRenderParameter(let parameter, let before, let after):
            var settings = document.renderSettings
            guard settings.value(for: parameter) == before else { throw ProjectError.invalidOperation("Render parameter precondition did not match.") }
            settings.set(after, for: parameter)
            document.renderSettings = settings
        case .setRenderBoolean(let parameter, let before, let after):
            var settings = document.renderSettings
            switch parameter { case .inverted: guard settings.inverted == before else { throw ProjectError.invalidOperation("Render boolean precondition did not match.") }; settings.inverted = after }
            document.renderSettings = settings
        case .setOutputDimensions(let bw, let bh, let aw, let ah):
            var settings = document.renderSettings
            guard settings.outputWidth == bw, settings.outputHeight == bh else { throw ProjectError.invalidOperation("Output dimension precondition did not match.") }
            settings.outputWidth = aw; settings.outputHeight = ah; document.renderSettings = settings
        case .setProjectColor(let before, let after):
            guard document.settings.color == before else { throw ProjectError.invalidOperation("Project color precondition did not match.") }
            document.settings.color = after
        case .insertComposition(let composition, let layers, let index):
            guard document.compositionRegistry.indices.contains(index) || index == document.compositionRegistry.endIndex else { throw ProjectError.invalidOperation("Composition insertion index changed.") }
            document.compositionRegistry.insert(composition, at: index)
            document.layerRegistry.append(contentsOf: layers)
        case .removeComposition(let composition, let layers, let index):
            guard document.compositionRegistry.indices.contains(index), document.compositionRegistry[index] == composition, document.layers(in: composition.id) == layers else { throw ProjectError.invalidOperation("Composition removal precondition did not match.") }
            document.layerRegistry.removeAll { $0.compositionID == composition.id }
            document.compositionRegistry.remove(at: index)
            if let selected = document.selectedLayerID, layers.contains(where: { $0.id == selected }) { document.selectedLayerID = nil }
        case .renameComposition(let id, let before, let after):
            let index = try compositionIndex(id, in: document); guard document.compositionRegistry[index].name == before else { throw ProjectError.invalidOperation("Composition name precondition did not match.") }; document.compositionRegistry[index].name = after
        case .setCompositionDimensions(let id, let bw, let bh, let aw, let ah):
            let index = try compositionIndex(id, in: document); guard document.compositionRegistry[index].width == bw, document.compositionRegistry[index].height == bh else { throw ProjectError.invalidOperation("Composition dimensions precondition did not match.") }; document.compositionRegistry[index].width = aw; document.compositionRegistry[index].height = ah
        case .setCompositionDuration(let id, let before, let after):
            let index = try compositionIndex(id, in: document); guard document.compositionRegistry[index].duration == before else { throw ProjectError.invalidOperation("Composition duration precondition did not match.") }; document.compositionRegistry[index].duration = after
        case .setCompositionFrameRate(let id, let before, let after):
            let index = try compositionIndex(id, in: document); guard document.compositionRegistry[index].frameRate == before else { throw ProjectError.invalidOperation("Composition frame-rate precondition did not match.") }; document.compositionRegistry[index].frameRate = after
        case .setCompositionBackground(let id, let before, let after):
            let index = try compositionIndex(id, in: document); guard document.compositionRegistry[index].backgroundColor == before else { throw ProjectError.invalidOperation("Composition background precondition did not match.") }; document.compositionRegistry[index].backgroundColor = after
        case .setCompositionWorkArea(let id, let before, let after):
            let index = try compositionIndex(id, in: document)
            guard document.compositionRegistry[index].workArea == before else { throw ProjectError.invalidOperation("Composition work-area precondition did not match.") }
            document.compositionRegistry[index].workArea = after
        case .setCompositionMarkers(let id, let before, let after):
            let index = try compositionIndex(id, in: document)
            guard document.compositionRegistry[index].markers == before else { throw ProjectError.invalidOperation("Composition-marker precondition did not match.") }
            document.compositionRegistry[index].markers = after
        case .applyTimelineEdit(let compositionID, let change):
            let compIndex = try compositionIndex(compositionID, in: document)
            guard document.compositionRegistry[compIndex].layerIDs == change.beforeLayerOrder,
                  document.layers(in: compositionID) == change.beforeLayers,
                  document.selectedLayerID == change.beforeSelectedLayerID else {
                throw ProjectError.invalidOperation("Timeline mutation apply precondition did not match.")
            }
            document.layerRegistry.removeAll { $0.compositionID == compositionID }
            document.layerRegistry.append(contentsOf: change.afterLayers)
            document.compositionRegistry[compIndex].layerIDs = change.afterLayerOrder
            document.selectedLayerID = change.afterSelectedLayerID
        case .insertLayer(let layer, let compositionID, let index):
            let compIndex = try compositionIndex(compositionID, in: document); guard document.compositionRegistry[compIndex].layerIDs.indices.contains(index) || index == document.compositionRegistry[compIndex].layerIDs.endIndex else { throw ProjectError.invalidOperation("Layer insertion index changed.") }; document.layerRegistry.append(layer); document.compositionRegistry[compIndex].layerIDs.insert(layer.id, at: index)
        case .removeLayer(let layer, let compositionID, let index):
            let compIndex = try compositionIndex(compositionID, in: document); guard document.compositionRegistry[compIndex].layerIDs.indices.contains(index), document.compositionRegistry[compIndex].layerIDs[index] == layer.id, let registryIndex = document.layerRegistry.firstIndex(of: layer) else { throw ProjectError.invalidOperation("Layer removal precondition did not match.") }; document.compositionRegistry[compIndex].layerIDs.remove(at: index); document.layerRegistry.remove(at: registryIndex); if document.selectedLayerID == layer.id { document.selectedLayerID = nil }
        case .reorderLayer(let compositionID, let layerID, let beforeIndex, let afterIndex):
            let compIndex = try compositionIndex(compositionID, in: document); guard document.compositionRegistry[compIndex].layerIDs.indices.contains(beforeIndex), document.compositionRegistry[compIndex].layerIDs[beforeIndex] == layerID, document.compositionRegistry[compIndex].layerIDs.indices.contains(afterIndex) else { throw ProjectError.invalidOperation("Layer reorder precondition did not match.") }; document.compositionRegistry[compIndex].layerIDs.remove(at: beforeIndex); document.compositionRegistry[compIndex].layerIDs.insert(layerID, at: afterIndex)
        case .renameLayer(let id, let before, let after):
            let index = try layerIndex(id, in: document); guard document.layerRegistry[index].name == before else { throw ProjectError.invalidOperation("Layer name precondition did not match.") }; document.layerRegistry[index].name = after
        case .setLayerEnabled(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].enabled == before else { throw ProjectError.invalidOperation("Layer enabled precondition did not match.") }; document.layerRegistry[index].enabled = after
        case .setLayerLocked(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].locked == before else { throw ProjectError.invalidOperation("Layer lock precondition did not match.") }; document.layerRegistry[index].locked = after
        case .setLayerSolo(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].solo == before else { throw ProjectError.invalidOperation("Layer solo precondition did not match.") }; document.layerRegistry[index].solo = after
        case .setLayerTiming(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].timing == before else { throw ProjectError.invalidOperation("Layer timing precondition did not match.") }; document.layerRegistry[index].timing = after
        case .setLayerTransform(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].transform == before else { throw ProjectError.invalidOperation("Layer transform precondition did not match.") }; document.layerRegistry[index].transform = after
        case .setLayerBlendMode(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].blendMode == before else { throw ProjectError.invalidOperation("Layer blend-mode precondition did not match.") }; document.layerRegistry[index].blendMode = after
        case .setLayerSource(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].source == before else { throw ProjectError.invalidOperation("Layer source precondition did not match.") }; document.layerRegistry[index].source = after
        case .setLayerMarkers(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].markers == before else { throw ProjectError.invalidOperation("Layer-marker precondition did not match.") }; document.layerRegistry[index].markers = after
        case .setLayerParent(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].parentLayerID == before else { throw ProjectError.invalidOperation("Layer-parent precondition did not match.") }; document.layerRegistry[index].parentLayerID = after
        case .setLayerOperations(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].operations == before else { throw ProjectError.invalidOperation("Layer operations precondition did not match.") }; document.layerRegistry[index].operations = after
        case .setLayerEffects(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].effects == before else { throw ProjectError.invalidOperation("Layer effects precondition did not match.") }; document.layerRegistry[index].effects = after
        case .setLayerMotionState(
            let id,
            let beforeChannels,
            let afterChannels,
            let beforeMasks,
            let afterMasks,
            let beforeMatte,
            let afterMatte
        ):
            let index = try layerIndex(id, in: document)
            guard document.layerRegistry[index].animationChannels == beforeChannels,
                  document.layerRegistry[index].masks == beforeMasks,
                  document.layerRegistry[index].trackMatte == beforeMatte else {
                throw ProjectError.invalidOperation("Layer motion-state precondition did not match.")
            }
            document.layerRegistry[index].animationChannels = afterChannels
            document.layerRegistry[index].masks = afterMasks
            document.layerRegistry[index].trackMatte = afterMatte
        }
    }

    private func compositionIndex(_ id: VertexID, in document: ProjectDocument) throws -> Int {
        guard let index = document.compositionRegistry.firstIndex(where: { $0.id == id }) else { throw ProjectError.invalidOperation("Composition is missing.") }
        return index
    }

    private func layerIndex(_ id: VertexID, in document: ProjectDocument) throws -> Int {
        guard let index = document.layerRegistry.firstIndex(where: { $0.id == id }) else { throw ProjectError.invalidOperation("Layer is missing.") }
        return index
    }
}

@available(*, deprecated, message: "Legacy .aeproject decoding only; new edits use ProjectCommandRequest.")
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
        self.commandID = commandID; self.projectID = projectID; self.baseRevision = baseRevision; self.timestamp = timestamp; self.mergeKey = mergeKey; self.forwardOperation = forwardOperation; self.inverseOperation = inverseOperation
    }
}
