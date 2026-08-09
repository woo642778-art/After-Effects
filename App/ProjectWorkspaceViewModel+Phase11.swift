import VertexCore
import VertexProject

extension ProjectWorkspaceViewModel {
    func insertNewComposition(_ composition: ProjectComposition) throws {
        guard let project else {
            throw ProjectError.invalidOperation("Create or open a project before creating a composition.")
        }
        let validated = try composition.validated(layerByID: [:])
        perform(
            .insertComposition(
                validated,
                ownedLayers: [],
                index: project.compositionRegistry.count
            ),
            mergeKey: nil
        )
    }

    func setAnimationChannels(
        layerID: VertexID,
        channels: [ProjectAnimationChannel],
        mergeKey: String? = nil
    ) throws {
        guard let layer = project?.layer(id: layerID) else {
            throw ProjectError.invalidOperation("Animation edit references a missing layer.")
        }
        _ = try channels.validatedAnimationChannels(for: layer.masks, effects: layer.effects)
        guard channels != layer.animationChannels else { return }
        perform(
            .setLayerMotionState(
                id: layerID,
                animationChannels: channels,
                masks: layer.masks,
                trackMatte: layer.trackMatte
            ),
            mergeKey: mergeKey
        )
    }
}
