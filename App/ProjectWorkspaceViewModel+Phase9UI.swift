import Foundation
import VertexCore
import VertexProject

extension ProjectWorkspaceViewModel {
    func phase9SetLayerEnabled(layerID: VertexID, value: Bool) {
        guard project?.layer(id: layerID)?.enabled != value else { return }
        perform(.setLayerEnabled(id: layerID, value: value), mergeKey: nil)
    }

    func phase9SetLayerSolo(layerID: VertexID, value: Bool) {
        guard project?.layer(id: layerID)?.solo != value else { return }
        perform(.setLayerSolo(id: layerID, value: value), mergeKey: nil)
    }

    func phase9SetLayerLocked(layerID: VertexID, value: Bool) {
        guard project?.layer(id: layerID)?.locked != value else { return }
        perform(.setLayerLocked(id: layerID, value: value), mergeKey: nil)
    }

    func phase9SetLayerBlendMode(layerID: VertexID, mode: LayerBlendMode) {
        guard project?.layer(id: layerID)?.blendMode != mode else { return }
        perform(.setLayerBlendMode(id: layerID, mode: mode), mergeKey: nil)
    }

    func addEffect(_ type: ProjectEffectType, to layerID: VertexID) throws {
        guard let layer = project?.layer(id: layerID) else {
            throw ProjectError.invalidOperation("Selected layer no longer exists.")
        }
        guard case .media = layer.source else {
            throw ProjectError.invalidOperation("Phase 9 AI effects require a media layer.")
        }
        let effect = try ProjectEffect.makeDefault(type).validated()
        perform(.insertLayerEffect(id: layerID, effect: effect, index: layer.effects.count), mergeKey: nil)
    }

    func setEffectEnabled(layerID: VertexID, effectID: VertexID, enabled: Bool) throws {
        guard let effect = project?.layer(id: layerID)?.effects.first(where: { $0.id == effectID }) else {
            throw ProjectError.invalidOperation("Effect no longer exists.")
        }
        guard effect.enabled != enabled else { return }
        perform(.setLayerEffectEnabled(id: layerID, effectID: effectID, value: enabled), mergeKey: nil)
    }

    func setEffectParameter(
        layerID: VertexID,
        effectID: VertexID,
        parameterID: String,
        value: ProjectEffectParameterValue
    ) throws {
        guard let layer = project?.layer(id: layerID),
              let index = layer.effects.firstIndex(where: { $0.id == effectID }) else {
            throw ProjectError.invalidOperation("Effect no longer exists.")
        }
        var effects = layer.effects
        try effects[index].setParameter(id: parameterID, value: value)
        _ = try effects.validatedEffects()
        perform(
            .setLayerEffects(id: layerID, effects: effects),
            mergeKey: "effect.\(effectID.rawValue).parameter.\(parameterID)"
        )
    }

    func moveEffect(layerID: VertexID, effectID: VertexID, to index: Int) throws {
        guard let effects = project?.layer(id: layerID)?.effects,
              effects.contains(where: { $0.id == effectID }),
              (0..<effects.count).contains(index) else {
            throw ProjectError.invalidOperation("Effect reorder target is invalid.")
        }
        perform(.moveLayerEffect(id: layerID, effectID: effectID, toIndex: index), mergeKey: nil)
    }

    func removeEffect(layerID: VertexID, effectID: VertexID) throws {
        guard project?.layer(id: layerID)?.effects.contains(where: { $0.id == effectID }) == true else {
            throw ProjectError.invalidOperation("Effect no longer exists.")
        }
        perform(.removeLayerEffect(id: layerID, effectID: effectID), mergeKey: nil)
    }

    func phase9SetTrackMatte(layerID: VertexID, matte: ProjectTrackMatte?) throws {
        guard let layer = project?.layer(id: layerID) else {
            throw ProjectError.invalidOperation("Layer no longer exists.")
        }
        perform(
            .setLayerMotionState(
                id: layerID,
                animationChannels: layer.animationChannels,
                masks: layer.masks,
                trackMatte: matte
            ),
            mergeKey: nil
        )
    }

    func phase9UpdateTemporalHandle(
        layerID: VertexID,
        channelID: VertexID,
        keyframeID: VertexID,
        incoming: ProjectBezierHandle?,
        outgoing: ProjectBezierHandle?
    ) throws {
        guard let layer = project?.layer(id: layerID),
              let channelIndex = layer.animationChannels.firstIndex(where: { $0.id == channelID }),
              let keyframeIndex = layer.animationChannels[channelIndex].keyframes.firstIndex(where: { $0.id == keyframeID }) else {
            throw ProjectError.invalidOperation("Animation keyframe no longer exists.")
        }
        var channels = layer.animationChannels
        channels[channelIndex].keyframes[keyframeIndex].incomingTemporalHandle = incoming
        channels[channelIndex].keyframes[keyframeIndex].outgoingTemporalHandle = outgoing
        _ = try channels.validatedAnimationChannels(for: layer.masks, effects: layer.effects)
        perform(
            .setLayerMotionState(id: layerID, animationChannels: channels, masks: layer.masks, trackMatte: layer.trackMatte),
            mergeKey: "graph.\(channelID.rawValue).\(keyframeID.rawValue)"
        )
    }
}

enum EffectControlAction: Equatable {
    case add(type: ProjectEffectType, layerID: VertexID)
    case setEnabled(layerID: VertexID, effectID: VertexID, enabled: Bool)
    case setParameter(layerID: VertexID, effectID: VertexID, parameterID: String, value: ProjectEffectParameterValue)
    case move(layerID: VertexID, effectID: VertexID, to: Int)
    case remove(layerID: VertexID, effectID: VertexID)
    case bake(layerID: VertexID, effectID: VertexID)
}
