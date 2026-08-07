import VertexCore

public enum ProjectMutation: Codable, Equatable, Sendable {
    case renameProject(before: String, after: String)
    case registerMedia(MediaReference)
    case removeMedia(MediaReference)
    case relinkMedia(mediaID: VertexID, before: MediaLocator, after: MediaLocator)
    case setEmbeddedPath(mediaID: VertexID, before: String?, after: String?)
    case setProjectColor(before: ColorDescriptor, after: ColorDescriptor)

    // Historical draft WAL compatibility. New command requests never create these cases.
    case selectMedia(before: VertexID?, after: VertexID?)
    case setRenderParameter(ProjectRenderParameter, before: Double, after: Double)
    case setRenderBoolean(ProjectRenderBooleanParameter, before: Bool, after: Bool)
    case setOutputDimensions(beforeWidth: Int, beforeHeight: Int, afterWidth: Int, afterHeight: Int)

    case createComposition(ProjectComposition, ownedLayers: [ProjectLayer], registryIndex: Int)
    case removeComposition(ProjectComposition, ownedLayers: [ProjectLayer], registryIndex: Int)
    case duplicateComposition(sourceID: VertexID, composition: ProjectComposition, layers: [ProjectLayer], registryIndex: Int)
    case renameComposition(compositionID: VertexID, before: String, after: String)
    case setCompositionDimensions(compositionID: VertexID, beforeWidth: Int, beforeHeight: Int, afterWidth: Int, afterHeight: Int)
    case setCompositionDuration(compositionID: VertexID, before: RationalTime, after: RationalTime)
    case setCompositionFrameRate(compositionID: VertexID, before: RationalTime, after: RationalTime)
    case setCompositionBackground(compositionID: VertexID, before: ProjectRGBAColor, after: ProjectRGBAColor)

    case insertLayer(ProjectLayer, compositionID: VertexID, index: Int)
    case removeLayer(ProjectLayer, compositionID: VertexID, index: Int)
    case duplicateLayer(sourceLayerID: VertexID, duplicate: ProjectLayer, compositionID: VertexID, index: Int)
    case renameLayer(layerID: VertexID, before: String, after: String)
    case reorderLayer(compositionID: VertexID, layerID: VertexID, beforeIndex: Int, afterIndex: Int)
    case setLayerEnabled(layerID: VertexID, before: Bool, after: Bool)
    case setLayerLocked(layerID: VertexID, before: Bool, after: Bool)
    case setLayerSolo(layerID: VertexID, before: Bool, after: Bool)
    case setLayerTiming(layerID: VertexID, before: LayerTiming, after: LayerTiming)
    case setLayerTransform(layerID: VertexID, before: LayerTransform, after: LayerTransform)
    case setLayerBlendMode(layerID: VertexID, before: LayerBlendMode, after: LayerBlendMode)
    case setLayerSource(layerID: VertexID, before: LayerSource, after: LayerSource)
    case setLayerOperations(layerID: VertexID, before: [LayerOperation], after: [LayerOperation])

    public var inverse: ProjectMutation {
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
        case .setProjectColor(let before, let after):
            .setProjectColor(before: after, after: before)
        case .selectMedia(let before, let after):
            .selectMedia(before: after, after: before)
        case .setRenderParameter(let parameter, let before, let after):
            .setRenderParameter(parameter, before: after, after: before)
        case .setRenderBoolean(let parameter, let before, let after):
            .setRenderBoolean(parameter, before: after, after: before)
        case .setOutputDimensions(let beforeWidth, let beforeHeight, let afterWidth, let afterHeight):
            .setOutputDimensions(
                beforeWidth: afterWidth,
                beforeHeight: afterHeight,
                afterWidth: beforeWidth,
                afterHeight: beforeHeight
            )
        case .createComposition(let composition, let layers, let index):
            .removeComposition(composition, ownedLayers: layers, registryIndex: index)
        case .removeComposition(let composition, let layers, let index):
            .createComposition(composition, ownedLayers: layers, registryIndex: index)
        case .duplicateComposition(_, let composition, let layers, let index):
            .removeComposition(composition, ownedLayers: layers, registryIndex: index)
        case .renameComposition(let id, let before, let after):
            .renameComposition(compositionID: id, before: after, after: before)
        case .setCompositionDimensions(let id, let beforeWidth, let beforeHeight, let afterWidth, let afterHeight):
            .setCompositionDimensions(
                compositionID: id,
                beforeWidth: afterWidth,
                beforeHeight: afterHeight,
                afterWidth: beforeWidth,
                afterHeight: beforeHeight
            )
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
            .reorderLayer(
                compositionID: compositionID,
                layerID: layerID,
                beforeIndex: afterIndex,
                afterIndex: beforeIndex
            )
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

@available(*, deprecated, renamed: "ProjectMutation")
public typealias ProjectOperation = ProjectMutation
