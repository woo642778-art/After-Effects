import Foundation
import VertexCore

public enum ProjectOperation: Codable, Equatable, Sendable {
    case renameProject(before: String, after: String)
    case registerMedia(MediaReference)
    case removeMedia(MediaReference)
    case relinkMedia(mediaID: VertexID, before: MediaLocator, after: MediaLocator)
    case setEmbeddedPath(mediaID: VertexID, before: String?, after: String?)
    case selectMedia(before: VertexID?, after: VertexID?)
    case setRenderParameter(ProjectRenderParameter, before: Double, after: Double)
    case setRenderBoolean(ProjectRenderBooleanParameter, before: Bool, after: Bool)
    case setOutputDimensions(beforeWidth: Int, beforeHeight: Int, afterWidth: Int, afterHeight: Int)
    case setProjectColor(before: ColorDescriptor, after: ColorDescriptor)

    case createComposition(ProjectComposition, ownedLayers: [ProjectLayer], registryIndex: Int)
    case removeComposition(ProjectComposition, ownedLayers: [ProjectLayer], registryIndex: Int)
    case duplicateComposition(sourceID: VertexID, composition: ProjectComposition, layers: [ProjectLayer], registryIndex: Int)
    case renameComposition(compositionID: VertexID, before: String, after: String)
    case setActiveComposition(before: VertexID?, after: VertexID?)
    case setCompositionDimensions(compositionID: VertexID, beforeWidth: Int, beforeHeight: Int, afterWidth: Int, afterHeight: Int)
    case setCompositionDuration(compositionID: VertexID, before: RationalTime, after: RationalTime)
    case setCompositionFrameRate(compositionID: VertexID, before: RationalTime, after: RationalTime)
    case setCompositionBackground(compositionID: VertexID, before: ProjectRGBAColor, after: ProjectRGBAColor)

    case insertLayer(ProjectLayer, compositionID: VertexID, index: Int)
    case removeLayer(ProjectLayer, compositionID: VertexID, index: Int)
    case duplicateLayer(sourceLayerID: VertexID, duplicate: ProjectLayer, compositionID: VertexID, index: Int)
    case renameLayer(layerID: VertexID, before: String, after: String)
    case reorderLayer(compositionID: VertexID, layerID: VertexID, beforeIndex: Int, afterIndex: Int)
    case setSelectedLayer(before: VertexID?, after: VertexID?)
    case setLayerEnabled(layerID: VertexID, before: Bool, after: Bool)
    case setLayerLocked(layerID: VertexID, before: Bool, after: Bool)
    case setLayerSolo(layerID: VertexID, before: Bool, after: Bool)
    case setLayerTiming(layerID: VertexID, before: LayerTiming, after: LayerTiming)
    case setLayerTransform(layerID: VertexID, before: LayerTransform, after: LayerTransform)
    case setLayerBlendMode(layerID: VertexID, before: LayerBlendMode, after: LayerBlendMode)
    case setLayerSource(layerID: VertexID, before: LayerSource, after: LayerSource)
    case setLayerOperations(layerID: VertexID, before: [LayerOperation], after: [LayerOperation])

    public var inverse: ProjectOperation {
        switch self {
        case .renameProject(let before, let after):
            .renameProject(before: after, after: before)
        case .registerMedia(let reference):
            .removeMedia(reference)
        case .removeMedia(let reference):
            .registerMedia(reference)
        case .relinkMedia(let mediaID, let before, let after):
            .relinkMedia(mediaID: mediaID, before: after, after: before)
        case .setEmbeddedPath(let mediaID, let before, let after):
            .setEmbeddedPath(mediaID: mediaID, before: after, after: before)
        case .selectMedia(let before, let after):
            .selectMedia(before: after, after: before)
        case .setRenderParameter(let parameter, let before, let after):
            .setRenderParameter(parameter, before: after, after: before)
        case .setRenderBoolean(let parameter, let before, let after):
            .setRenderBoolean(parameter, before: after, after: before)
        case .setOutputDimensions(let beforeWidth, let beforeHeight, let afterWidth, let afterHeight):
            .setOutputDimensions(beforeWidth: afterWidth, beforeHeight: afterHeight, afterWidth: beforeWidth, afterHeight: beforeHeight)
        case .setProjectColor(let before, let after):
            .setProjectColor(before: after, after: before)

        case .createComposition(let composition, let layers, let index):
            .removeComposition(composition, ownedLayers: layers, registryIndex: index)
        case .removeComposition(let composition, let layers, let index):
            .createComposition(composition, ownedLayers: layers, registryIndex: index)
        case .duplicateComposition(_, let composition, let layers, let index):
            .removeComposition(composition, ownedLayers: layers, registryIndex: index)
        case .renameComposition(let id, let before, let after):
            .renameComposition(compositionID: id, before: after, after: before)
        case .setActiveComposition(let before, let after):
            .setActiveComposition(before: after, after: before)
        case .setCompositionDimensions(let id, let beforeWidth, let beforeHeight, let afterWidth, let afterHeight):
            .setCompositionDimensions(compositionID: id, beforeWidth: afterWidth, beforeHeight: afterHeight, afterWidth: beforeWidth, afterHeight: beforeHeight)
        case .setCompositionDuration(let id, let before, let after):
            .setCompositionDuration(compositionID: id, before: after, after: before)
        case .setCompositionFrameRate(let id, let before, let after):
            .setCompositionFrameRate(compositionID: id, before: after, after: before)
        case .setCompositionBackground(let id, let before, let after):
            .setCompositionBackground(compositionID: id, before: after, after: before)

        case .insertLayer(let layer, let compositionID, let index):
            .removeLayer(layer, compositionID: compositionID, index: index)
        case .removeLayer(let layer, let compositionID, let index):
            .insertLayer(layer, compositionID: compositionID, index: index)
        case .duplicateLayer(_, let duplicate, let compositionID, let index):
            .removeLayer(duplicate, compositionID: compositionID, index: index)
        case .renameLayer(let id, let before, let after):
            .renameLayer(layerID: id, before: after, after: before)
        case .reorderLayer(let compositionID, let layerID, let beforeIndex, let afterIndex):
            .reorderLayer(compositionID: compositionID, layerID: layerID, beforeIndex: afterIndex, afterIndex: beforeIndex)
        case .setSelectedLayer(let before, let after):
            .setSelectedLayer(before: after, after: before)
        case .setLayerEnabled(let id, let before, let after):
            .setLayerEnabled(layerID: id, before: after, after: before)
        case .setLayerLocked(let id, let before, let after):
            .setLayerLocked(layerID: id, before: after, after: before)
        case .setLayerSolo(let id, let before, let after):
            .setLayerSolo(layerID: id, before: after, after: before)
        case .setLayerTiming(let id, let before, let after):
            .setLayerTiming(layerID: id, before: after, after: before)
        case .setLayerTransform(let id, let before, let after):
            .setLayerTransform(layerID: id, before: after, after: before)
        case .setLayerBlendMode(let id, let before, let after):
            .setLayerBlendMode(layerID: id, before: after, after: before)
        case .setLayerSource(let id, let before, let after):
            .setLayerSource(layerID: id, before: after, after: before)
        case .setLayerOperations(let id, let before, let after):
            .setLayerOperations(layerID: id, before: after, after: before)
        }
    }
}

public struct ProjectCommandRecord: Codable, Equatable, Sendable, Identifiable {
    public var commandID: VertexID
    public var projectID: VertexID
    public var baseRevision: UInt64
    public var timestamp: Date
    public var mergeKey: String?
    public var forwardOperation: ProjectOperation
    public var inverseOperation: ProjectOperation

    public var id: VertexID { commandID }

    public init(
        commandID: VertexID = VertexID(),
        projectID: VertexID,
        baseRevision: UInt64,
        timestamp: Date = Date(),
        mergeKey: String? = nil,
        forwardOperation: ProjectOperation,
        inverseOperation: ProjectOperation
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
        operation: ProjectOperation,
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

public struct ProjectCommandEngine: Sendable {
    public init() {}

    public func apply(_ record: ProjectCommandRecord, to document: ProjectDocument) throws -> ProjectDocument {
        guard record.projectID == document.projectID else { throw ProjectError.invalidProjectIdentity }
        guard record.baseRevision == document.revision else {
            throw ProjectError.staleBaseRevision(expected: record.baseRevision, actual: document.revision)
        }
        guard !document.appliedCommandIDs.contains(record.commandID) else {
            throw ProjectError.duplicateCommand(record.commandID.rawValue)
        }
        guard record.inverseOperation == record.forwardOperation.inverse else {
            throw ProjectError.invalidInverseOperation("The command inverse does not reverse the forward operation.")
        }
        guard document.revision < UInt64.max else { throw ProjectError.invalidRevision }

        var changed = document
        try apply(record.forwardOperation, to: &changed)
        changed.revision += 1
        changed.metadata.modifiedAt = record.timestamp
        changed.metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion
        changed.appliedCommandIDs.append(record.commandID)
        if changed.appliedCommandIDs.count > 1_000 {
            changed.appliedCommandIDs.removeFirst(changed.appliedCommandIDs.count - 1_000)
        }
        return try changed.validated()
    }

    private func apply(_ operation: ProjectOperation, to document: inout ProjectDocument) throws {
        switch operation {
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
            guard document.renderSettings.outputWidth == beforeWidth, document.renderSettings.outputHeight == beforeHeight else {
                throw ProjectError.invalidOperation("Output-dimension precondition did not match.")
            }
            document.renderSettings.outputWidth = afterWidth
            document.renderSettings.outputHeight = afterHeight
            _ = try document.renderSettings.validated()

        case .setProjectColor(let before, let after):
            guard document.settings.color == before else { throw ProjectError.invalidOperation("Project-color precondition did not match.") }
            document.settings.color = after

        case .createComposition(let composition, let ownedLayers, let registryIndex):
            try insertComposition(composition, ownedLayers: ownedLayers, registryIndex: registryIndex, into: &document)

        case .duplicateComposition(let sourceID, let composition, let layers, let registryIndex):
            guard document.composition(id: sourceID) != nil else { throw ProjectError.invalidOperation("Source composition to duplicate is missing.") }
            try insertComposition(composition, ownedLayers: layers, registryIndex: registryIndex, into: &document)

        case .removeComposition(let composition, let ownedLayers, let registryIndex):
            guard document.compositionRegistry.count > 1 else { throw ProjectError.invalidOperation("The final composition cannot be removed.") }
            guard document.activeCompositionID != composition.id else { throw ProjectError.invalidOperation("Select another active composition before removing this composition.") }
            guard document.compositionRegistry.indices.contains(registryIndex), document.compositionRegistry[registryIndex] == composition else {
                throw ProjectError.invalidOperation("Composition removal precondition did not match.")
            }
            let referenced = document.layerRegistry.contains { layer in
                if case .composition(let target, _) = layer.source { return target == composition.id && layer.compositionID != composition.id }
                return false
            }
            guard !referenced else { throw ProjectError.invalidOperation("A nested layer references this composition.") }
            let currentOwned = document.layers(in: composition.id)
            guard currentOwned == ownedLayers else { throw ProjectError.invalidOperation("Owned layer payload did not match composition state.") }
            document.layerRegistry.removeAll { $0.compositionID == composition.id }
            document.compositionRegistry.remove(at: registryIndex)
            if let selected = document.selectedLayerID, ownedLayers.contains(where: { $0.id == selected }) { document.selectedLayerID = nil }

        case .renameComposition(let compositionID, let before, let after):
            let index = try compositionIndex(compositionID, in: document)
            guard document.compositionRegistry[index].name == before else { throw ProjectError.invalidOperation("Composition name precondition did not match.") }
            guard !after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ProjectError.invalidValue("Composition name must not be empty.") }
            document.compositionRegistry[index].name = after

        case .setActiveComposition(let before, let after):
            guard document.activeCompositionID == before else { throw ProjectError.invalidOperation("Active composition precondition did not match.") }
            guard let after, document.composition(id: after) != nil else { throw ProjectError.invalidOperation("The new active composition must exist.") }
            document.activeCompositionID = after
            if let selected = document.selectedLayerID, document.layer(id: selected)?.compositionID != after { document.selectedLayerID = nil }

        case .setCompositionDimensions(let id, let beforeWidth, let beforeHeight, let afterWidth, let afterHeight):
            let index = try compositionIndex(id, in: document)
            guard document.compositionRegistry[index].width == beforeWidth, document.compositionRegistry[index].height == beforeHeight else {
                throw ProjectError.invalidOperation("Composition dimension precondition did not match.")
            }
            document.compositionRegistry[index].width = afterWidth
            document.compositionRegistry[index].height = afterHeight

        case .setCompositionDuration(let id, let before, let after):
            let index = try compositionIndex(id, in: document)
            guard document.compositionRegistry[index].duration == before else { throw ProjectError.invalidOperation("Composition duration precondition did not match.") }
            document.compositionRegistry[index].duration = after

        case .setCompositionFrameRate(let id, let before, let after):
            let index = try compositionIndex(id, in: document)
            guard document.compositionRegistry[index].frameRate == before else { throw ProjectError.invalidOperation("Composition frame-rate precondition did not match.") }
            document.compositionRegistry[index].frameRate = after

        case .setCompositionBackground(let id, let before, let after):
            let index = try compositionIndex(id, in: document)
            guard document.compositionRegistry[index].backgroundColor == before else { throw ProjectError.invalidOperation("Composition background precondition did not match.") }
            document.compositionRegistry[index].backgroundColor = after

        case .insertLayer(let layer, let compositionID, let index):
            try insertLayer(layer, compositionID: compositionID, index: index, into: &document)

        case .duplicateLayer(let sourceLayerID, let duplicate, let compositionID, let index):
            guard document.layer(id: sourceLayerID) != nil else { throw ProjectError.invalidOperation("Source layer to duplicate is missing.") }
            try insertLayer(duplicate, compositionID: compositionID, index: index, into: &document)

        case .removeLayer(let layer, let compositionID, let index):
            let compositionIndex = try compositionIndex(compositionID, in: document)
            guard document.compositionRegistry[compositionIndex].layerIDs.indices.contains(index),
                  document.compositionRegistry[compositionIndex].layerIDs[index] == layer.id,
                  document.layer(id: layer.id) == layer else {
                throw ProjectError.invalidOperation("Layer removal precondition did not match.")
            }
            document.compositionRegistry[compositionIndex].layerIDs.remove(at: index)
            document.layerRegistry.removeAll { $0.id == layer.id }
            if document.selectedLayerID == layer.id { document.selectedLayerID = nil }

        case .renameLayer(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].name == before else { throw ProjectError.invalidOperation("Layer name precondition did not match.") }
            guard !after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ProjectError.invalidValue("Layer name must not be empty.") }
            document.layerRegistry[index].name = after

        case .reorderLayer(let compositionID, let layerID, let beforeIndex, let afterIndex):
            _ = try editableLayerIndex(layerID, in: document)
            let index = try compositionIndex(compositionID, in: document)
            var ids = document.compositionRegistry[index].layerIDs
            guard ids.indices.contains(beforeIndex), ids[beforeIndex] == layerID, afterIndex >= 0, afterIndex < ids.count else {
                throw ProjectError.invalidOperation("Layer reorder precondition did not match.")
            }
            ids.remove(at: beforeIndex)
            ids.insert(layerID, at: afterIndex)
            document.compositionRegistry[index].layerIDs = ids

        case .setSelectedLayer(let before, let after):
            guard document.selectedLayerID == before else { throw ProjectError.invalidOperation("Selected-layer precondition did not match.") }
            if let after {
                guard let layer = document.layer(id: after), layer.compositionID == document.activeCompositionID else {
                    throw ProjectError.invalidOperation("Selected layer must belong to the active composition.")
                }
            }
            document.selectedLayerID = after

        case .setLayerLocked(let layerID, let before, let after):
            let index = try layerIndex(layerID, in: document)
            guard document.layerRegistry[index].locked == before else { throw ProjectError.invalidOperation("Layer lock precondition did not match.") }
            document.layerRegistry[index].locked = after

        case .setLayerEnabled(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].enabled == before else { throw ProjectError.invalidOperation("Layer enabled precondition did not match.") }
            document.layerRegistry[index].enabled = after

        case .setLayerSolo(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].solo == before else { throw ProjectError.invalidOperation("Layer Solo precondition did not match.") }
            document.layerRegistry[index].solo = after

        case .setLayerTiming(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].timing == before else { throw ProjectError.invalidOperation("Layer timing precondition did not match.") }
            document.layerRegistry[index].timing = after

        case .setLayerTransform(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].transform == before else { throw ProjectError.invalidOperation("Layer transform precondition did not match.") }
            document.layerRegistry[index].transform = after

        case .setLayerBlendMode(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].blendMode == before else { throw ProjectError.invalidOperation("Layer blend precondition did not match.") }
            document.layerRegistry[index].blendMode = after

        case .setLayerSource(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].source == before else { throw ProjectError.invalidOperation("Layer source precondition did not match.") }
            document.layerRegistry[index].source = after

        case .setLayerOperations(let layerID, let before, let after):
            let index = try editableLayerIndex(layerID, in: document)
            guard document.layerRegistry[index].operations == before else { throw ProjectError.invalidOperation("Layer operation precondition did not match.") }
            document.layerRegistry[index].operations = after
        }
    }

    private func insertComposition(
        _ composition: ProjectComposition,
        ownedLayers: [ProjectLayer],
        registryIndex: Int,
        into document: inout ProjectDocument
    ) throws {
        guard !document.compositionRegistry.contains(where: { $0.id == composition.id }),
              document.compositionRegistry.indices.contains(registryIndex) || registryIndex == document.compositionRegistry.endIndex else {
            throw ProjectError.invalidOperation("Composition insertion precondition did not match.")
        }
        guard Set(composition.layerIDs) == Set(ownedLayers.map(\.id)),
              ownedLayers.allSatisfy({ $0.compositionID == composition.id }),
              ownedLayers.allSatisfy({ document.layer(id: $0.id) == nil }) else {
            throw ProjectError.invalidOperation("Composition owned-layer payload is invalid.")
        }
        document.compositionRegistry.insert(composition, at: registryIndex)
        document.layerRegistry.append(contentsOf: ownedLayers)
    }

    private func insertLayer(
        _ layer: ProjectLayer,
        compositionID: VertexID,
        index: Int,
        into document: inout ProjectDocument
    ) throws {
        guard layer.compositionID == compositionID, document.layer(id: layer.id) == nil else {
            throw ProjectError.invalidOperation("Layer insertion identity or ownership is invalid.")
        }
        let compositionIndex = try compositionIndex(compositionID, in: document)
        let ids = document.compositionRegistry[compositionIndex].layerIDs
        guard index >= 0, index <= ids.count else { throw ProjectError.invalidOperation("Layer insertion index is invalid.") }
        document.layerRegistry.append(layer)
        document.compositionRegistry[compositionIndex].layerIDs.insert(layer.id, at: index)
    }

    private func compositionIndex(_ id: VertexID, in document: ProjectDocument) throws -> Int {
        guard let index = document.compositionRegistry.firstIndex(where: { $0.id == id }) else {
            throw ProjectError.invalidOperation("Composition is missing.")
        }
        return index
    }

    private func layerIndex(_ id: VertexID, in document: ProjectDocument) throws -> Int {
        guard let index = document.layerRegistry.firstIndex(where: { $0.id == id }) else {
            throw ProjectError.invalidOperation("Layer is missing.")
        }
        return index
    }

    private func editableLayerIndex(_ id: VertexID, in document: ProjectDocument) throws -> Int {
        let index = try layerIndex(id, in: document)
        guard !document.layerRegistry[index].locked else {
            throw ProjectError.invalidOperation("Unlock the layer before editing it.")
        }
        return index
    }
}
