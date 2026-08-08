import Testing
import VertexCore
@testable import VertexTimeline

@Test("Layer and keyframe selections stay independent")
func selectionDomainsAreIndependent() {
    let layerA = VertexID(rawValue: "93100000-0000-0000-0000-000000000001")
    let layerB = VertexID(rawValue: "93100000-0000-0000-0000-000000000002")
    let keyA = VertexID(rawValue: "93200000-0000-0000-0000-000000000001")
    var selection = TimelineSelection()
    selection.selectLayer(layerA, additive: false)
    selection.selectKeyframe(keyA, additive: true)
    selection.toggleLayer(layerB)
    #expect(selection.layerIDs == Set([layerA, layerB]))
    #expect(selection.keyframeIDs == Set([keyA]))
    selection.clearLayers()
    #expect(selection.layerIDs.isEmpty)
    #expect(selection.keyframeIDs == Set([keyA]))
}

@Test("Replacing selection clears only the addressed domain")
func replacingSelectionIsDeterministic() {
    let a = VertexID(rawValue: "93300000-0000-0000-0000-000000000001")
    let b = VertexID(rawValue: "93300000-0000-0000-0000-000000000002")
    let key = VertexID(rawValue: "93400000-0000-0000-0000-000000000001")
    var selection = TimelineSelection(layerIDs: [a], keyframeIDs: [key])
    selection.replaceLayers([b])
    #expect(selection.orderedLayerIDs == [b])
    #expect(selection.keyframeIDs == Set([key]))
}
