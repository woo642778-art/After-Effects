import Foundation
import Testing
import VertexCore
@testable import VertexProject

private func effectDocument() throws -> (ProjectDocument, ProjectLayer) {
    var document = try ProjectDocument.makeNew(name: "Effects")
    let compositionID = try #require(document.activeCompositionID)
    var composition = try #require(document.composition(id: compositionID))
    let media = MediaReference.fixture(
        id: "95000000-0000-0000-0000-000000000001",
        name: "clip.mov"
    )
    let layer = ProjectLayer(
        id: VertexID(rawValue: "95000000-0000-0000-0000-000000000010"),
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
    return (try document.validated(), layer)
}

@Test("Default AI effects validate and preserve declared order")
func defaultEffectsValidateInStableOrder() throws {
    let depth = ProjectEffect.makeDefault(.depthMap)
    let cutout = ProjectEffect.makeDefault(.cutout)
    let effects = try [depth, cutout].validatedEffects()
    #expect(effects.map(\.type) == [.depthMap, .cutout])
}

@Test("Duplicate effect and parameter identities are rejected")
func duplicateEffectAndParameterIdentitiesAreRejected() throws {
    let depth = ProjectEffect.makeDefault(.depthMap)
    #expect(throws: ProjectError.self) { _ = try [depth, depth].validatedEffects() }

    var bad = depth
    let first = try #require(bad.parameters.first)
    bad.parameters.append(first)
    #expect(throws: ProjectError.self) { _ = try bad.validated() }
}

@Test("Unknown parameters and nonfinite scalars are rejected")
func strictEffectParametersRejectInvalidValues() throws {
    var depth = ProjectEffect.makeDefault(.depthMap)
    depth.parameters.append(ProjectEffectParameter(id: "unknown", value: .scalar(1)))
    #expect(throws: ProjectError.self) { _ = try depth.validated() }

    var restore = ProjectEffect.makeDefault(.restore)
    let index = try #require(restore.parameters.firstIndex(where: { $0.id == RestorationParameterID.denoise }))
    restore.parameters[index].value = .scalar(.nan)
    #expect(throws: ProjectError.self) { _ = try restore.validated() }
}

@Test("Effect stack round trips without changing order")
func effectStackRoundTripsDeterministically() throws {
    var pair = try effectDocument()
    var layer = pair.1
    layer.effects = [ProjectEffect.makeDefault(.upscale), ProjectEffect.makeDefault(.depthMap)]
    pair.0.layerRegistry = [layer]
    let encoded = try DeterministicProjectCodec().encode(pair.0)
    let decoded = try DeterministicProjectCodec().decode(encoded)
    #expect(decoded.layer(id: layer.id)?.effects.map(\.type) == [.upscale, .depthMap])
}

@Test("AI effects are rejected on non-media phase 9 layers")
func effectsRequireMediaLayerInPhase9() throws {
    var document = try ProjectDocument.makeNew(name: "Invalid Effects")
    let compositionID = try #require(document.activeCompositionID)
    var composition = try #require(document.composition(id: compositionID))
    let layer = ProjectLayer(
        compositionID: compositionID,
        name: "Null",
        source: .null,
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 5, timescale: 1)),
        effects: [ProjectEffect.makeDefault(.depthMap)]
    )
    composition.layerIDs = [layer.id]
    document.compositionRegistry = [composition]
    document.layerRegistry = [layer]
    #expect(throws: ProjectError.self) { _ = try document.validated() }
}

@Test("Effect animation channel must reference a real compatible parameter")
func effectAnimationReferencesAreValidated() throws {
    let effect = ProjectEffect.makeDefault(.depthMap)
    let channel = ProjectAnimationChannel(
        property: .effect(effectID: effect.id, parameterID: DepthMapParameterID.smoothing, valueKind: .scalar),
        keyframes: [ProjectKeyframe(time: .zero, value: .scalar(0.2), interpolation: .linear)]
    )
    #expect(try [channel].validatedAnimationChannels(effects: [effect]).count == 1)
    let bad = ProjectAnimationChannel(
        property: .effect(effectID: effect.id, parameterID: "model", valueKind: .scalar),
        keyframes: [ProjectKeyframe(time: .zero, value: .scalar(1), interpolation: .linear)]
    )
    #expect(throws: ProjectError.self) { _ = try [bad].validatedAnimationChannels(effects: [effect]) }
}
