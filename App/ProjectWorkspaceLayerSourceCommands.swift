import VertexCore
import VertexProject

@MainActor
extension ProjectWorkspaceViewModel {
    func setSelectedLayerSource(_ source: LayerSource) {
        guard let layer = selectedLayer, layer.source != source else { return }
        applyCommand(.setLayerSource(id: layer.id, value: source))
    }

    func setNestedSourceStart(seconds: Double) {
        guard let layer = selectedLayer,
              case .composition(let compositionID, _) = layer.source,
              let composition = activeComposition,
              let time = exactTime(seconds: seconds, frameRate: composition.frameRate) else { return }
        setSelectedLayerSource(.composition(compositionID: compositionID, sourceStartTime: time))
    }

    func setNestedComposition(_ compositionID: VertexID) {
        guard let layer = selectedLayer,
              case .composition(_, let sourceStartTime) = layer.source else { return }
        setSelectedLayerSource(.composition(compositionID: compositionID, sourceStartTime: sourceStartTime))
    }

    func setCameraFocalLength(_ value: Double) {
        guard let layer = selectedLayer, case .camera(var settings) = layer.source else { return }
        settings.focalLengthMillimeters = value
        setSelectedLayerSource(.camera(settings))
    }

    func setLightIntensity(_ value: Double) {
        guard let layer = selectedLayer, case .light(var settings) = layer.source else { return }
        settings.intensity = value
        setSelectedLayerSource(.light(settings))
    }
}
