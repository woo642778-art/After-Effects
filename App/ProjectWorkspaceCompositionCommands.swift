import Foundation
import VertexCore
import VertexProject

@MainActor
extension ProjectWorkspaceViewModel {
    func createComposition(name: String = "Composition") {
        guard let project else { return }
        let composition = ProjectComposition(
            name: name,
            width: activeComposition?.width ?? 1080,
            height: activeComposition?.height ?? 1080,
            duration: activeComposition?.duration ?? RationalTime(value: 10, timescale: 1),
            frameRate: activeComposition?.frameRate ?? project.settings.frameRate,
            color: activeComposition?.color ?? project.settings.color,
            backgroundColor: .transparent,
            layerIDs: []
        )
        applyProjectOperation(.createComposition(
            composition,
            ownedLayers: [],
            registryIndex: project.compositionRegistry.count
        ))
        applyProjectOperation(.setActiveComposition(before: project.activeCompositionID, after: composition.id))
    }

    func duplicateActiveComposition() {
        guard let project, let source = activeComposition else { return }
        let duplicateID = VertexID()
        var duplicate = source
        duplicate.id = duplicateID
        duplicate.name = source.name + " Copy"
        var duplicatedLayers: [ProjectLayer] = []
        var order: [VertexID] = []
        for layer in project.layers(in: source.id) {
            var copy = layer
            copy.id = VertexID()
            copy.compositionID = duplicateID
            copy.name = layer.name + " Copy"
            duplicatedLayers.append(copy)
            order.append(copy.id)
        }
        duplicate.layerIDs = order
        applyProjectOperation(.duplicateComposition(
            sourceID: source.id,
            composition: duplicate,
            layers: duplicatedLayers,
            registryIndex: project.compositionRegistry.count
        ))
        applyProjectOperation(.setActiveComposition(before: project.activeCompositionID, after: duplicate.id))
    }

    func selectComposition(_ id: VertexID) {
        guard let project, project.activeCompositionID != id else { return }
        applyProjectOperation(.setActiveComposition(before: project.activeCompositionID, after: id))
    }

    func removeActiveComposition() {
        guard let project, let composition = activeComposition,
              project.compositionRegistry.count > 1,
              let index = project.compositionRegistry.firstIndex(where: { $0.id == composition.id }) else { return }
        let replacement = project.compositionRegistry.first { $0.id != composition.id }
        if let replacement {
            applyProjectOperation(.setActiveComposition(before: composition.id, after: replacement.id))
        }
        applyProjectOperation(.removeComposition(
            composition,
            ownedLayers: project.layers(in: composition.id),
            registryIndex: index
        ))
    }

    func renameActiveComposition(_ name: String) {
        guard let composition = activeComposition else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != composition.name else { return }
        applyProjectOperation(.renameComposition(
            compositionID: composition.id,
            before: composition.name,
            after: trimmed
        ))
    }

    func setActiveCompositionDimensions(width: Int, height: Int) {
        guard let composition = activeComposition,
              width != composition.width || height != composition.height else { return }
        applyProjectOperation(.setCompositionDimensions(
            compositionID: composition.id,
            beforeWidth: composition.width,
            beforeHeight: composition.height,
            afterWidth: width,
            afterHeight: height
        ))
    }

    func setActiveCompositionDuration(seconds: Double) {
        guard let composition = activeComposition,
              let value = exactTime(seconds: seconds, frameRate: composition.frameRate),
              value > .zero,
              value != composition.duration else { return }
        guard orderedLayers.allSatisfy({ $0.timing.outPoint <= value }) else { return }
        applyProjectOperation(.setCompositionDuration(
            compositionID: composition.id,
            before: composition.duration,
            after: value
        ))
    }

    func addSelectedMediaLayer() {
        guard let composition = activeComposition, let media = selectedMedia else { return }
        insertLayer(ProjectLayer(
            compositionID: composition.id,
            name: media.displayName,
            source: .media(mediaID: media.id, sourceStartTime: .zero),
            timing: fullTiming(composition)
        ))
    }

    func addAdjustmentLayer() {
        guard let composition = activeComposition else { return }
        insertLayer(ProjectLayer(
            compositionID: composition.id,
            name: "Adjustment Layer",
            source: .adjustment(scope: .belowAll),
            timing: fullTiming(composition)
        ))
    }

    func addNullLayer() { addModelLayer(name: "Null", source: .null) }
    func addGuideLayer() { addModelLayer(name: "Guide", source: .guide) }
    func addCameraLayer() { addModelLayer(name: "Camera", source: .camera(.default)) }
    func addLightLayer() { addModelLayer(name: "Light", source: .light(.default)) }

    func addNestedCompositionLayer(sourceCompositionID: VertexID) {
        guard let composition = activeComposition,
              sourceCompositionID != composition.id,
              project?.composition(id: sourceCompositionID) != nil else { return }
        insertLayer(ProjectLayer(
            compositionID: composition.id,
            name: project?.composition(id: sourceCompositionID)?.name ?? "Nested Composition",
            source: .composition(compositionID: sourceCompositionID, sourceStartTime: .zero),
            timing: fullTiming(composition)
        ))
    }

    func selectLayer(_ id: VertexID?) {
        guard let project, project.selectedLayerID != id else { return }
        applyProjectOperation(.setSelectedLayer(before: project.selectedLayerID, after: id))
        if let id, let layer = project.layer(id: id), case .media(let mediaID, _) = layer.source,
           project.selectedMediaID != mediaID {
            applyProjectOperation(.selectMedia(before: project.selectedMediaID, after: mediaID))
        }
    }

    func removeSelectedLayer() {
        guard let project, let layer = selectedLayer,
              let composition = project.composition(id: layer.compositionID),
              let index = composition.layerIDs.firstIndex(of: layer.id) else { return }
        applyProjectOperation(.removeLayer(layer, compositionID: composition.id, index: index))
    }

    func duplicateSelectedLayer() {
        guard let project, let layer = selectedLayer,
              let composition = project.composition(id: layer.compositionID),
              let index = composition.layerIDs.firstIndex(of: layer.id) else { return }
        var duplicate = layer
        duplicate.id = VertexID()
        duplicate.name += " Copy"
        applyProjectOperation(.duplicateLayer(
            sourceLayerID: layer.id,
            duplicate: duplicate,
            compositionID: composition.id,
            index: index
        ))
        selectLayer(duplicate.id)
    }

    func moveLayer(_ id: VertexID, to newIndex: Int) {
        guard let composition = activeComposition,
              let oldIndex = composition.layerIDs.firstIndex(of: id),
              newIndex >= 0, newIndex < composition.layerIDs.count,
              oldIndex != newIndex else { return }
        applyProjectOperation(.reorderLayer(
            compositionID: composition.id,
            layerID: id,
            beforeIndex: oldIndex,
            afterIndex: newIndex
        ))
    }

    func setLayerLocked(_ value: Bool) {
        guard let layer = selectedLayer, layer.locked != value else { return }
        applyProjectOperation(.setLayerLocked(layerID: layer.id, before: layer.locked, after: value))
    }

    func setLayerEnabled(_ value: Bool) {
        guard let layer = selectedLayer, layer.enabled != value else { return }
        applyProjectOperation(.setLayerEnabled(layerID: layer.id, before: layer.enabled, after: value))
    }

    func setLayerSolo(_ value: Bool) {
        guard let layer = selectedLayer, layer.solo != value else { return }
        applyProjectOperation(.setLayerSolo(layerID: layer.id, before: layer.solo, after: value))
    }

    func renameSelectedLayer(_ name: String) {
        guard let layer = selectedLayer else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != layer.name else { return }
        applyProjectOperation(.renameLayer(layerID: layer.id, before: layer.name, after: trimmed))
    }

    func setLayerTransform(_ transform: LayerTransform, mergeKey: String) {
        guard let layer = selectedLayer, layer.transform != transform else { return }
        applyProjectOperation(
            .setLayerTransform(layerID: layer.id, before: layer.transform, after: transform),
            mergeKey: "layer.\(layer.id.rawValue).\(mergeKey)"
        )
    }

    func setLayerTiming(_ timing: LayerTiming) {
        guard let layer = selectedLayer, layer.timing != timing else { return }
        applyProjectOperation(
            .setLayerTiming(layerID: layer.id, before: layer.timing, after: timing),
            mergeKey: "layer.\(layer.id.rawValue).timing"
        )
    }

    func setLayerBlendMode(_ mode: LayerBlendMode) {
        guard let layer = selectedLayer, layer.blendMode != mode else { return }
        applyProjectOperation(.setLayerBlendMode(layerID: layer.id, before: layer.blendMode, after: mode))
    }

    func setLayerExposure(_ value: Double) { setLayerOperation(exposure: value, saturation: nil, inverted: nil) }
    func setLayerSaturation(_ value: Double) { setLayerOperation(exposure: nil, saturation: value, inverted: nil) }
    func setLayerInverted(_ value: Bool) { setLayerOperation(exposure: nil, saturation: nil, inverted: value) }

    private func insertLayer(_ layer: ProjectLayer) {
        applyProjectOperation(.insertLayer(layer, compositionID: layer.compositionID, index: 0))
        selectLayer(layer.id)
    }

    private func addModelLayer(name: String, source: LayerSource) {
        guard let composition = activeComposition else { return }
        insertLayer(ProjectLayer(
            compositionID: composition.id,
            name: name,
            source: source,
            timing: fullTiming(composition)
        ))
    }

    private func fullTiming(_ composition: ProjectComposition) -> LayerTiming {
        LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration)
    }

    private func setLayerOperation(exposure: Double?, saturation: Double?, inverted: Bool?) {
        guard let layer = selectedLayer else { return }
        var currentExposure = 0.0
        var currentSaturation = 1.0
        var currentInvert = false
        for operation in layer.operations {
            switch operation {
            case .exposure(let value): currentExposure = value
            case .saturation(let value): currentSaturation = value
            case .invert(let value): currentInvert = value
            }
        }
        let operations: [LayerOperation] = [
            .exposure(stops: exposure ?? currentExposure),
            .saturation(value: saturation ?? currentSaturation),
            .invert(enabled: inverted ?? currentInvert)
        ]
        guard operations != layer.operations else { return }
        applyProjectOperation(
            .setLayerOperations(layerID: layer.id, before: layer.operations, after: operations),
            mergeKey: "layer.\(layer.id.rawValue).operations"
        )
    }

    func exactTime(seconds: Double, frameRate: RationalTime) -> RationalTime? {
        guard seconds.isFinite, seconds >= 0, frameRate.value > 0, frameRate.value <= Int64(Int32.max) else { return nil }
        let frame = (seconds * frameRate.seconds).rounded()
        guard frame <= Double(Int64.max) else { return nil }
        let numerator = Int64(frame).multipliedReportingOverflow(by: Int64(frameRate.timescale))
        guard !numerator.overflow else { return nil }
        return RationalTime(value: numerator.partialValue, timescale: Int32(frameRate.value))
    }
}
