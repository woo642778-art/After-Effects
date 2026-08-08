import Testing
import VertexCore
import VertexProject
@testable import Vertex

@Test("Effect controls preserve layer and effect identity in commands")
func effectControlActionsCarryStableIdentity() {
    let layerID = VertexID(rawValue: "70000000-0000-0000-0000-000000000021")
    let effectID = VertexID(rawValue: "70000000-0000-0000-0000-000000000022")
    #expect(EffectControlAction.add(type: .depthMap, layerID: layerID) == .add(type: .depthMap, layerID: layerID))
    #expect(EffectControlAction.setEnabled(layerID: layerID, effectID: effectID, enabled: false) == .setEnabled(layerID: layerID, effectID: effectID, enabled: false))
    #expect(EffectControlAction.remove(layerID: layerID, effectID: effectID) == .remove(layerID: layerID, effectID: effectID))
    #expect(EffectControlAction.bake(layerID: layerID, effectID: effectID) == .bake(layerID: layerID, effectID: effectID))
}

@Test("Depth parameter edits remain typed")
func effectParameterActionIsTyped() {
    let layerID = VertexID(rawValue: "70000000-0000-0000-0000-000000000023")
    let effectID = VertexID(rawValue: "70000000-0000-0000-0000-000000000024")
    let action = EffectControlAction.setParameter(
        layerID: layerID,
        effectID: effectID,
        parameterID: DepthMapParameterID.invert,
        value: .boolean(true)
    )
    #expect(action == .setParameter(layerID: layerID, effectID: effectID, parameterID: DepthMapParameterID.invert, value: .boolean(true)))
}
