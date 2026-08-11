import Foundation
import Testing
import VertexCore
@testable import VertexProject

@Test("Effect descriptor registry covers every implemented effect exactly once")
func phase15DescriptorRegistryIsComplete() throws {
    let descriptors = ProjectEffectDescriptorRegistry.all
    #expect(descriptors.count == ProjectEffectType.allCases.count)
    #expect(Set(descriptors.map(\.type)) == Set(ProjectEffectType.allCases))

    for descriptor in descriptors {
        #expect(try descriptor.validated() == descriptor)
        #expect(descriptor.executionMode == (descriptor.type.isNativePixelEffect ? .nativePixel : .aiBake))
        let effect = ProjectEffect.makeDefault(descriptor.type)
        #expect(effect.version == descriptor.effectVersion)
        #expect(effect.parameters == descriptor.defaultParameters)
        #expect(try effect.validated() == effect)
    }
}

@Test("Typed parameter descriptors expose authoritative ranges options labels and animation kinds")
func phase15TypedParameterMetadata() throws {
    let blur = ProjectEffectDescriptorRegistry.descriptor(for: .gaussianBlur)
    let radius = try #require(blur.parameter(id: GaussianBlurParameterID.radius))
    #expect(radius.displayName == "Radius")
    #expect(radius.domain.scalarRange == 0...200)
    #expect(radius.animatableKind == .scalar)

    let upscale = ProjectEffectDescriptorRegistry.descriptor(for: .upscale)
    let overlap = try #require(upscale.parameter(id: UpscaleParameterID.tileOverlap))
    #expect(overlap.domain.integerRange == 0...256)
    #expect(overlap.animatableKind == nil)

    let depth = ProjectEffectDescriptorRegistry.descriptor(for: .depthMap)
    let quality = try #require(depth.parameter(id: DepthMapParameterID.quality))
    #expect(quality.domain.textOptions == ["preview", "balanced", "quality"])
    #expect(quality.animatableKind == nil)
}

@Test("Preset codec round trips deterministically and creates a fresh validated effect")
func phase15PresetRoundTripIsDeterministic() throws {
    var effect = ProjectEffect.makeDefault(.colorControls)
    try effect.setParameter(id: ColorControlsParameterID.contrast, value: .scalar(1.75))
    let preset = try ProjectEffectPreset.capture(name: "Punchy Color", effect: effect)

    let first = try ProjectEffectPresetCodec.encode(preset)
    let second = try ProjectEffectPresetCodec.encode(preset)
    #expect(first == second)

    let decoded = try ProjectEffectPresetCodec.decode(first)
    #expect(decoded == preset)
    #expect(decoded.schemaVersion == ProjectEffectPreset.currentSchemaVersion)

    let newID = VertexID(rawValue: "15000000-0000-0000-0000-000000000001")
    let instantiated = try decoded.instantiate(id: newID)
    #expect(instantiated.id == newID)
    #expect(instantiated.id != effect.id)
    #expect(instantiated.type == effect.type)
    #expect(instantiated.parameters == effect.parameters)
}

@Test("Legacy preset schema 1 migrates to schema 2 without changing parameters")
func phase15LegacyPresetMigration() throws {
    let effect = ProjectEffect.makeDefault(.gaussianBlur)
    let current = try ProjectEffectPreset.capture(name: "Soft Blur", effect: effect)
    let currentData = try ProjectEffectPresetCodec.encode(current)
    var object = try #require(JSONSerialization.jsonObject(with: currentData) as? [String: Any])
    object["schemaVersion"] = 1
    object["type"] = object.removeValue(forKey: "effectType")
    object.removeValue(forKey: "effectVersion")
    let legacyData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

    let migrated = try ProjectEffectPresetCodec.decode(legacyData)
    #expect(migrated.schemaVersion == ProjectEffectPreset.currentSchemaVersion)
    #expect(migrated.effectType == .gaussianBlur)
    #expect(migrated.effectVersion == ProjectEffectDescriptorRegistry.descriptor(for: .gaussianBlur).effectVersion)
    #expect(migrated.parameters == effect.parameters)

    let reencoded = String(decoding: try ProjectEffectPresetCodec.encode(migrated), as: UTF8.self)
    #expect(reencoded.contains("\"schemaVersion\":2"))
    #expect(reencoded.contains("\"effectType\":\"gaussianBlur\""))
    #expect(!reencoded.contains("\"type\":\"gaussianBlur\""))
}

@Test("Preset codec rejects unsupported future schemas")
func phase15PresetFutureSchemaFailsClosed() throws {
    let preset = try ProjectEffectPreset.capture(name: "Invert", effect: .makeDefault(.invert))
    let data = try ProjectEffectPresetCodec.encode(preset)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["schemaVersion"] = 999
    let future = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    #expect(throws: Error.self) { try ProjectEffectPresetCodec.decode(future) }
}
