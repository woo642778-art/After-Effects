import Foundation
import Testing
import VertexCore
@testable import VertexProject

private func effectCommandFixture() throws -> ProjectDocument {
    var document = try ProjectDocument.makeNew(name: "Effect Commands")
    let compositionID = try #require(document.activeCompositionID)
    var composition = try #require(document.composition(id: compositionID))
    let media = MediaReference.fixture(id: "95100000-0000-0000-0000-000000000001", name: "clip.mov")
    let layer = ProjectLayer(
        id: VertexID(rawValue: "95100000-0000-0000-0000-000000000010"),
        compositionID: compositionID,
        name: "Clip",
        source: .media(mediaID: media.id, sourceStartTime: .zero),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 5, timescale: 1))
    )
    composition.layerIDs = [layer.id]
    document.mediaRegistry = [media]
    document.compositionRegistry = [composition]
    document.layerRegistry = [layer]
    document.selectedLayerID = layer.id
    return try document.validated()
}

@Test("Insert move toggle and remove effects preserve exact stack semantics")
func effectCommandsAreReversibleAndOrdered() throws {
    let engine = ProjectCommandEngine()
    var document = try effectCommandFixture()
    let layerID = try #require(document.selectedLayerID)
    let depth = ProjectEffect.makeDefault(.depthMap)
    let upscale = ProjectEffect.makeDefault(.upscale)

    func apply(_ payload: ProjectCommandPayload) throws {
        let transition = try engine.prepare(ProjectCommandRequest(projectID: document.projectID, baseRevision: document.revision, payload: payload), for: document)
        document = try engine.apply(transition, to: document)
    }

    try apply(.insertLayerEffect(id: layerID, effect: depth, index: 0))
    try apply(.insertLayerEffect(id: layerID, effect: upscale, index: 1))
    #expect(document.layer(id: layerID)?.effects.map(\.type) == [.depthMap, .upscale])
    try apply(.moveLayerEffect(id: layerID, effectID: upscale.id, toIndex: 0))
    #expect(document.layer(id: layerID)?.effects.map(\.type) == [.upscale, .depthMap])
    try apply(.setLayerEffectEnabled(id: layerID, effectID: depth.id, value: false))
    #expect(document.layer(id: layerID)?.effects.first(where: { $0.id == depth.id })?.enabled == false)
    try apply(.removeLayerEffect(id: layerID, effectID: upscale.id))
    #expect(document.layer(id: layerID)?.effects.map(\.type) == [.depthMap])
}

@Test("Set effect stack mutation has an exact inverse")
func effectStackMutationInverseRestoresOriginal() throws {
    let engine = ProjectCommandEngine()
    let before = try effectCommandFixture()
    let layerID = try #require(before.selectedLayerID)
    let effects = [ProjectEffect.makeDefault(.depthMap), ProjectEffect.makeDefault(.restore)]
    let transition = try engine.prepare(
        ProjectCommandRequest(projectID: before.projectID, baseRevision: before.revision, payload: .setLayerEffects(id: layerID, effects: effects)),
        for: before
    )
    let after = try engine.apply(transition, to: before)
    let undo = ProjectTransition(
        commandID: VertexID(), projectID: after.projectID, baseRevision: after.revision,
        timestamp: Date(), mergeKey: nil, forward: transition.inverse, inverse: transition.forward
    )
    let restored = try engine.apply(undo, to: after)
    #expect(restored.layer(id: layerID)?.effects.isEmpty == true)
}
