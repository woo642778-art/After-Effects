import VertexCore

public enum ProjectMutation: Codable, Equatable, Sendable {
    case renameProject(before: String, after: String)
    case registerMedia(MediaReference)
    case removeMedia(MediaReference)
    case relinkMedia(mediaID: VertexID, before: MediaLocator, after: MediaLocator)
    case setEmbeddedPath(mediaID: VertexID, before: String?, after: String?)
    case selectMedia(before: VertexID?, after: VertexID?)
    case registerAIAsset(ProjectAIAsset)
    case removeAIAsset(ProjectAIAsset)
    case setRenderParameter(ProjectRenderParameter, before: Double, after: Double)
    case setRenderBoolean(ProjectRenderBooleanParameter, before: Bool, after: Bool)
    case setOutputDimensions(beforeWidth: Int, beforeHeight: Int, afterWidth: Int, afterHeight: Int)
    case setProjectColor(before: ColorDescriptor, after: ColorDescriptor)

    case insertComposition(ProjectComposition, ownedLayers: [ProjectLayer], registryIndex: Int)
    case removeComposition(ProjectComposition, ownedLayers: [ProjectLayer], registryIndex: Int)
    case renameComposition(compositionID: VertexID, before: String, after: String)
    case setCompositionDimensions(compositionID: VertexID, beforeWidth: Int, beforeHeight: Int, afterWidth: Int, afterHeight: Int)
    case setCompositionDuration(compositionID: VertexID, before: RationalTime, after: RationalTime)
    case setCompositionFrameRate(compositionID: VertexID, before: RationalTime, after: RationalTime)
    case setCompositionBackground(compositionID: VertexID, before: ProjectRGBAColor, after: ProjectRGBAColor)
    case setCompositionWorkArea(compositionID: VertexID, before: ProjectWorkArea?, after: ProjectWorkArea?)
    case setCompositionMarkers(compositionID: VertexID, before: [ProjectMarker], after: [ProjectMarker])
    case applyTimelineEdit(compositionID: VertexID, change: TimelineProjectMutation)

    case insertLayer(ProjectLayer, compositionID: VertexID, index: Int)
    case removeLayer(ProjectLayer, compositionID: VertexID, index: Int)
    case reorderLayer(compositionID: VertexID, layerID: VertexID, beforeIndex: Int, afterIndex: Int)
    case renameLayer(layerID: VertexID, before: String, after: String)
    case setLayerEnabled(layerID: VertexID, before: Bool, after: Bool)
    case setLayerLocked(layerID: VertexID, before: Bool, after: Bool)
    case setLayerSolo(layerID: VertexID, before: Bool, after: Bool)
    case setLayerTiming(layerID: VertexID, before: LayerTiming, after: LayerTiming)
    case setLayerTransform(layerID: VertexID, before: LayerTransform, after: LayerTransform)
    case setLayerBlendMode(layerID: VertexID, before: LayerBlendMode, after: LayerBlendMode)
    case setLayerSource(layerID: VertexID, before: LayerSource, after: LayerSource)
    case setLayerMarkers(layerID: VertexID, before: [ProjectMarker], after: [ProjectMarker])
    case setLayerParent(layerID: VertexID, before: VertexID?, after: VertexID?)
    case setLayerOperations(layerID: VertexID, before: [LayerOperation], after: [LayerOperation])
    case setLayerEffects(layerID: VertexID, before: [ProjectEffect], after: [ProjectEffect])
    case setLayerMotionState(
        layerID: VertexID,
        beforeAnimationChannels: [ProjectAnimationChannel],
        afterAnimationChannels: [ProjectAnimationChannel],
        beforeMasks: [ProjectMask],
        afterMasks: [ProjectMask],
        beforeTrackMatte: ProjectTrackMatte?,
        afterTrackMatte: ProjectTrackMatte?
    )

    public var inverse: ProjectMutation {
        switch self {
        case .renameProject(let before, let after): .renameProject(before: after, after: before)
        case .registerMedia(let reference): .removeMedia(reference)
        case .removeMedia(let reference): .registerMedia(reference)
        case .relinkMedia(let mediaID, let before, let after): .relinkMedia(mediaID: mediaID, before: after, after: before)
        case .setEmbeddedPath(let mediaID, let before, let after): .setEmbeddedPath(mediaID: mediaID, before: after, after: before)
        case .selectMedia(let before, let after): .selectMedia(before: after, after: before)
        case .registerAIAsset(let asset): .removeAIAsset(asset)
        case .removeAIAsset(let asset): .registerAIAsset(asset)
        case .setRenderParameter(let parameter, let before, let after): .setRenderParameter(parameter, before: after, after: before)
        case .setRenderBoolean(let parameter, let before, let after): .setRenderBoolean(parameter, before: after, after: before)
        case .setOutputDimensions(let bw, let bh, let aw, let ah): .setOutputDimensions(beforeWidth: aw, beforeHeight: ah, afterWidth: bw, afterHeight: bh)
        case .setProjectColor(let before, let after): .setProjectColor(before: after, after: before)
        case .insertComposition(let composition, let layers, let index): .removeComposition(composition, ownedLayers: layers, registryIndex: index)
        case .removeComposition(let composition, let layers, let index): .insertComposition(composition, ownedLayers: layers, registryIndex: index)
        case .renameComposition(let id, let before, let after): .renameComposition(compositionID: id, before: after, after: before)
        case .setCompositionDimensions(let id, let bw, let bh, let aw, let ah): .setCompositionDimensions(compositionID: id, beforeWidth: aw, beforeHeight: ah, afterWidth: bw, afterHeight: bh)
        case .setCompositionDuration(let id, let before, let after): .setCompositionDuration(compositionID: id, before: after, after: before)
        case .setCompositionFrameRate(let id, let before, let after): .setCompositionFrameRate(compositionID: id, before: after, after: before)
        case .setCompositionBackground(let id, let before, let after): .setCompositionBackground(compositionID: id, before: after, after: before)
        case .setCompositionWorkArea(let id, let before, let after): .setCompositionWorkArea(compositionID: id, before: after, after: before)
        case .setCompositionMarkers(let id, let before, let after): .setCompositionMarkers(compositionID: id, before: after, after: before)
        case .applyTimelineEdit(let id, let change): .applyTimelineEdit(compositionID: id, change: change.inverse)
        case .insertLayer(let layer, let compositionID, let index): .removeLayer(layer, compositionID: compositionID, index: index)
        case .removeLayer(let layer, let compositionID, let index): .insertLayer(layer, compositionID: compositionID, index: index)
        case .reorderLayer(let compositionID, let layerID, let beforeIndex, let afterIndex): .reorderLayer(compositionID: compositionID, layerID: layerID, beforeIndex: afterIndex, afterIndex: beforeIndex)
        case .renameLayer(let id, let before, let after): .renameLayer(layerID: id, before: after, after: before)
        case .setLayerEnabled(let id, let before, let after): .setLayerEnabled(layerID: id, before: after, after: before)
        case .setLayerLocked(let id, let before, let after): .setLayerLocked(layerID: id, before: after, after: before)
        case .setLayerSolo(let id, let before, let after): .setLayerSolo(layerID: id, before: after, after: before)
        case .setLayerTiming(let id, let before, let after): .setLayerTiming(layerID: id, before: after, after: before)
        case .setLayerTransform(let id, let before, let after): .setLayerTransform(layerID: id, before: after, after: before)
        case .setLayerBlendMode(let id, let before, let after): .setLayerBlendMode(layerID: id, before: after, after: before)
        case .setLayerSource(let id, let before, let after): .setLayerSource(layerID: id, before: after, after: before)
        case .setLayerMarkers(let id, let before, let after): .setLayerMarkers(layerID: id, before: after, after: before)
        case .setLayerParent(let id, let before, let after): .setLayerParent(layerID: id, before: after, after: before)
        case .setLayerOperations(let id, let before, let after): .setLayerOperations(layerID: id, before: after, after: before)
        case .setLayerEffects(let id, let before, let after): .setLayerEffects(layerID: id, before: after, after: before)
        case .setLayerMotionState(
            let id,
            let beforeChannels,
            let afterChannels,
            let beforeMasks,
            let afterMasks,
            let beforeMatte,
            let afterMatte
        ):
            .setLayerMotionState(
                layerID: id,
                beforeAnimationChannels: afterChannels,
                afterAnimationChannels: beforeChannels,
                beforeMasks: afterMasks,
                afterMasks: beforeMasks,
                beforeTrackMatte: afterMatte,
                afterTrackMatte: beforeMatte
            )
        }
    }
}

@available(*, deprecated, renamed: "ProjectMutation")
public typealias ProjectOperation = ProjectMutation
