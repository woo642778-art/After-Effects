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
        applyCommand(
            .createComposition(
                composition,
                ownedLayers: [],
                index: project.compositionRegistry.count
            ),
            then: .activeComposition(composition.id)
        )
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
        applyCommand(
            .duplicateComposition(
                sourceID: source.id,
                newCompositionID: duplicate.id,
                newLayerIDs: duplicatedLayers.map(\.id)
            ),
            then: .activeComposition(duplicate.id)
        )
    }

    func selectComposition(_ id: VertexID) {
        guard let project, project.activeCompositionID != id else { return }
        navigate(.activeComposition(id))
    }

    func removeActiveComposition() {
        guard let project, let composition = activeComposition,
              project.compositionRegistry.count > 1,
              project.compositionRegistry.contains(where: { $0.id == composition.id }) else { return }

        let isReferenced = project.layerRegistry.contains { layer in
            guard layer.compositionID != composition.id,
                  case .composition(let targetID, _) = layer.source else { return false }
            return targetID == composition.id
        }
        guard !isReferenced else { return }

        guard let replacement = project.compositionRegistry.first(where: { $0.id != composition.id }) else { return }
        applyCommand(
            .removeComposition(id: composition.id),
            then: .activeComposition(replacement.id)
        )
    }

    func renameActiveComposition(_ name: String) {
        guard let composition = activeComposition else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != composition.name else { return }
        applyCommand(.renameComposition(id: composition.id, to: trimmed))
    }

    func setActiveCompositionDimensions(width: Int, height: Int) {
        guard let composition = activeComposition,
              width != composition.width || height != composition.height else { return }
        applyCommand(
            .setCompositionDimensions(id: composition.id, width: width, height: height),
            mergeKey: "composition.\(composition.id.rawValue).dimensions"
        )
    }

    func setActiveCompositionDuration(seconds: Double) {
        guard let composition = activeComposition,
              let value = exactTime(seconds: seconds, frameRate: composition.frameRate),
              value > .zero,
              value != composition.duration else { return }
        guard orderedLayers.allSatisfy({ $0.timing.outPoint <= value }) else { return }
        applyCommand(
            .setCompositionDuration(id: composition.id, duration: value),
            mergeKey: "composition.\(composition.id.rawValue).duration"
        )
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
        let mediaID: VertexID?
        if let id, let layer = project.layer(id: id), case .media(let selectedMediaID, _) = layer.source {
            mediaID = selectedMediaID
        } else {
            mediaID = project.selectedMediaID
        }
        navigate(.selectedLayer(id, selectedMediaID: mediaID))
    }

    func removeSelectedLayer() {
        guard let project, let layer = selectedLayer,
              project.composition(id: layer.compositionID)?.layerIDs.contains(layer.id) == true else { return }
        applyCommand(.removeLayer(id: layer.id), then: .selectedLayer(nil, selectedMediaID: project.selectedMediaID))
    }

    func duplicateSelectedLayer() {
        guard let project, let layer = selectedLayer,
              let composition = project.composition(id: layer.compositionID),
              let index = composition.layerIDs.firstIndex(of: layer.id) else { return }
        let duplicateID = VertexID()
        applyCommand(
            .duplicateLayer(sourceID: layer.id, duplicateID: duplicateID, index: index),
            then: .selectedLayer(duplicateID, selectedMediaID: project.selectedMediaID)
        )
    }

    func moveLayer(_ id: VertexID, to newIndex: Int) {
        guard let composition = activeComposition,
              let oldIndex = composition.layerIDs.firstIndex(of: id),
              newIndex >= 0, newIndex < composition.layerIDs.count,
              oldIndex != newIndex else { return }
        applyCommand(.reorderLayer(compositionID: composition.id, layerID: id, toIndex: newIndex))
    }

    func setLayerLocked(_ value: Bool) {
        guard let layer = selectedLayer, layer.locked != value else { return }
        applyCommand(.setLayerLocked(id: layer.id, value: value))
    }

    func setLayerEnabled(_ value: Bool) {
        guard let layer = selectedLayer, layer.enabled != value else { return }
        applyCommand(.setLayerEnabled(id: layer.id, value: value))
    }

    func setLayerSolo(_ value: Bool) {
        guard let layer = selectedLayer, layer.solo != value else { return }
        applyCommand(.setLayerSolo(id: layer.id, value: value))
    }

    func renameSelectedLayer(_ name: String) {
        guard let layer = selectedLayer else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != layer.name else { return }
        applyCommand(.renameLayer(id: layer.id, to: trimmed))
    }

    func setLayerTransform(_ transform: LayerTransform, mergeKey: String) {
        guard let layer = selectedLayer, layer.transform != transform else { return }
        applyCommand(
            .setLayerTransform(id: layer.id, value: transform),
            mergeKey: "layer.\(layer.id.rawValue).\(mergeKey)"
        )
    }

    func setLayerTiming(_ timing: LayerTiming) {
        guard let layer = selectedLayer, layer.timing != timing else { return }
        applyCommand(
            .setLayerTiming(id: layer.id, value: timing),
            mergeKey: "layer.\(layer.id.rawValue).timing"
        )
    }

    func setLayerBlendMode(_ mode: LayerBlendMode) {
        guard let layer = selectedLayer, layer.blendMode != mode else { return }
        applyCommand(.setLayerBlendMode(id: layer.id, value: mode))
    }

    func setLayerExposure(_ value: Double) { setLayerOperation(exposure: value, saturation: nil, inverted: nil) }
    func setLayerSaturation(_ value: Double) { setLayerOperation(exposure: nil, saturation: value, inverted: nil) }
    func setLayerInverted(_ value: Bool) { setLayerOperation(exposure: nil, saturation: nil, inverted: value) }

    private func insertLayer(_ layer: ProjectLayer) {
        let selectedMediaID: VertexID?
        if case .media(let mediaID, _) = layer.source {
            selectedMediaID = mediaID
        } else {
            selectedMediaID = project?.selectedMediaID
        }
        applyCommand(
            .insertLayer(layer, compositionID: layer.compositionID, index: 0),
            then: .selectedLayer(layer.id, selectedMediaID: selectedMediaID)
        )
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
        applyCommand(
            .setLayerOperations(id: layer.id, value: operations),
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
