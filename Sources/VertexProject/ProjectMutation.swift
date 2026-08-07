import VertexCore

public enum ProjectMutation: Codable, Equatable, Sendable {
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
    case removeDuplicatedComposition(sourceID: VertexID, composition: ProjectComposition, layers: [ProjectLayer], registryIndex: Int)
    case renameComposition(id: VertexID, before: String, after: String)
    case setCompositionDimensions(id: VertexID, beforeWidth: Int, beforeHeight: Int, afterWidth: Int, afterHeight: Int)
    case setCompositionDuration(id: VertexID, before: RationalTime, after: RationalTime)
    case setCompositionFrameRate(id: VertexID, before: RationalTime, after: RationalTime)
    case setCompositionBackground(id: VertexID, before: ProjectRGBAColor, after: ProjectRGBAColor)

    case insertLayer(ProjectLayer, compositionID: VertexID, index: Int)
    case removeLayer(ProjectLayer, compositionID: VertexID, index: Int)
    case duplicateLayer(sourceLayerID: VertexID, duplicate: ProjectLayer, compositionID: VertexID, index: Int)
    case removeDuplicatedLayer(sourceLayerID: VertexID, duplicate: ProjectLayer, compositionID: VertexID, index: Int)
    case renameLayer(id: VertexID, before: String, after: String)
    case reorderLayer(compositionID: VertexID, layerID: VertexID, beforeIndex: Int, afterIndex: Int)
    case setLayerEnabled(id: VertexID, before: Bool, after: Bool)
    case setLayerLocked(id: VertexID, before: Bool, after: Bool)
    case setLayerSolo(id: VertexID, before: Bool, after: Bool)
    case setLayerTiming(id: VertexID, before: LayerTiming, after: LayerTiming)
    case setLayerTransform(id: VertexID, before: LayerTransform, after: LayerTransform)
    case setLayerBlendMode(id: VertexID, before: LayerBlendMode, after: LayerBlendMode)
    case setLayerSource(id: VertexID, before: LayerSource, after: LayerSource)
    case setLayerOperations(id: VertexID, before: [LayerOperation], after: [LayerOperation])

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
        case .setProjectColor(let before, let after):
            .setProjectColor(before: after, after: before)

        case .createComposition(let composition, let ownedLayers, let registryIndex):
            .removeComposition(composition, ownedLayers: ownedLayers, registryIndex: registryIndex)
        case .removeComposition(let composition, let ownedLayers, let registryIndex):
            .createComposition(composition, ownedLayers: ownedLayers, registryIndex: registryIndex)
        case .duplicateComposition(let sourceID, let composition, let layers, let registryIndex):
            .removeDuplicatedComposition(
                sourceID: sourceID,
                composition: composition,
                layers: layers,
                registryIndex: registryIndex
            )
        case .removeDuplicatedComposition(let sourceID, let composition, let layers, let registryIndex):
            .duplicateComposition(
                sourceID: sourceID,
                composition: composition,
                layers: layers,
                registryIndex: registryIndex
            )
        case .renameComposition(let id, let before, let after):
            .renameComposition(id: id, before: after, after: before)
        case .setCompositionDimensions(let id, let beforeWidth, let beforeHeight, let afterWidth, let afterHeight):
            .setCompositionDimensions(
                id: id,
                beforeWidth: afterWidth,
                beforeHeight: afterHeight,
                afterWidth: beforeWidth,
                afterHeight: beforeHeight
            )
        case .setCompositionDuration(let id, let before, let after):
            .setCompositionDuration(id: id, before: after, after: before)
        case .setCompositionFrameRate(let id, let before, let after):
            .setCompositionFrameRate(id: id, before: after, after: before)
        case .setCompositionBackground(let id, let before, let after):
            .setCompositionBackground(id: id, before: after, after: before)

        case .insertLayer(let layer, let compositionID, let index):
            .removeLayer(layer, compositionID: compositionID, index: index)
        case .removeLayer(let layer, let compositionID, let index):
            .insertLayer(layer, compositionID: compositionID, index: index)
        case .duplicateLayer(let sourceLayerID, let duplicate, let compositionID, let index):
            .removeDuplicatedLayer(
                sourceLayerID: sourceLayerID,
                duplicate: duplicate,
                compositionID: compositionID,
                index: index
            )
        case .removeDuplicatedLayer(let sourceLayerID, let duplicate, let compositionID, let index):
            .duplicateLayer(
                sourceLayerID: sourceLayerID,
                duplicate: duplicate,
                compositionID: compositionID,
                index: index
            )
        case .renameLayer(let id, let before, let after):
            .renameLayer(id: id, before: after, after: before)
        case .reorderLayer(let compositionID, let layerID, let beforeIndex, let afterIndex):
            .reorderLayer(
                compositionID: compositionID,
                layerID: layerID,
                beforeIndex: afterIndex,
                afterIndex: beforeIndex
            )
        case .setLayerEnabled(let id, let before, let after):
            .setLayerEnabled(id: id, before: after, after: before)
        case .setLayerLocked(let id, let before, let after):
            .setLayerLocked(id: id, before: after, after: before)
        case .setLayerSolo(let id, let before, let after):
            .setLayerSolo(id: id, before: after, after: before)
        case .setLayerTiming(let id, let before, let after):
            .setLayerTiming(id: id, before: after, after: before)
        case .setLayerTransform(let id, let before, let after):
            .setLayerTransform(id: id, before: after, after: before)
        case .setLayerBlendMode(let id, let before, let after):
            .setLayerBlendMode(id: id, before: after, after: before)
        case .setLayerSource(let id, let before, let after):
            .setLayerSource(id: id, before: after, after: before)
        case .setLayerOperations(let id, let before, let after):
            .setLayerOperations(id: id, before: after, after: before)
        }
    }
}

@available(*, deprecated, renamed: "ProjectMutation")
public typealias ProjectOperation = ProjectMutation
