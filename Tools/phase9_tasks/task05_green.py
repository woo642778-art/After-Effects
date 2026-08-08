from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]

def read(path): return (ROOT / path).read_text()
def write(path, text):
    p = ROOT / path; p.parent.mkdir(parents=True, exist_ok=True); p.write_text(text)
def repl(path, old, new):
    text = read(path)
    if new in text: return
    if old not in text: raise RuntimeError(f"marker missing in {path}: {old[:100]!r}")
    write(path, text.replace(old, new, 1))

write("Sources/VertexProject/ProjectEffect.swift", r'''import Foundation
import VertexCore

public enum ProjectEffectType: String, Codable, CaseIterable, Sendable {
    case depthMap
    case cutout
    case upscale
    case restore
}

public enum ProjectEffectParameterValue: Codable, Equatable, Sendable {
    case scalar(Double)
    case integer(Int)
    case boolean(Bool)
    case text(String)

    public var animatableKind: ProjectAnimatableValueKind? {
        switch self {
        case .scalar: .scalar
        case .boolean: .boolean
        case .integer, .text: nil
        }
    }

    public func validated() throws -> Self {
        if case .scalar(let value) = self, !value.isFinite {
            throw ProjectError.invalidValue("Effect scalar parameters must be finite.")
        }
        return self
    }
}

public struct ProjectEffectParameter: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var value: ProjectEffectParameterValue

    public init(id: String, value: ProjectEffectParameterValue) {
        self.id = id
        self.value = value
    }
}

public enum DepthMapParameterID {
    public static let model = "model"
    public static let quality = "quality"
    public static let invert = "invert"
    public static let near = "near"
    public static let far = "far"
    public static let smoothing = "smoothing"
    public static let edgeRefinement = "edgeRefinement"
    public static let temporalSmoothing = "temporalSmoothing"
    public static let output = "output"
}

public enum CutoutParameterID {
    public static let quality = "quality"
    public static let mode = "mode"
    public static let feather = "feather"
    public static let edgeCleanup = "edgeCleanup"
    public static let temporalSmoothing = "temporalSmoothing"
    public static let promptX = "promptX"
    public static let promptY = "promptY"
}

public enum UpscaleParameterID {
    public static let quality = "quality"
    public static let profile = "profile"
    public static let scale = "scale"
    public static let tileOverlap = "tileOverlap"
}

public enum RestorationParameterID {
    public static let quality = "quality"
    public static let denoise = "denoise"
    public static let deblur = "deblur"
    public static let artifactRemoval = "artifactRemoval"
    public static let detailRecovery = "detailRecovery"
    public static let faceRestoration = "faceRestoration"
}

public struct ProjectEffect: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var type: ProjectEffectType
    public var version: Int
    public var enabled: Bool
    public var parameters: [ProjectEffectParameter]

    public init(
        id: VertexID = VertexID(),
        type: ProjectEffectType,
        version: Int = 1,
        enabled: Bool = true,
        parameters: [ProjectEffectParameter]
    ) {
        self.id = id
        self.type = type
        self.version = version
        self.enabled = enabled
        self.parameters = parameters
    }

    public static func makeDefault(_ type: ProjectEffectType) -> Self {
        switch type {
        case .depthMap:
            return Self(type: type, parameters: [
                .init(id: DepthMapParameterID.model, value: .text("depth-anything-v2-small-f16")),
                .init(id: DepthMapParameterID.quality, value: .text("balanced")),
                .init(id: DepthMapParameterID.invert, value: .boolean(false)),
                .init(id: DepthMapParameterID.near, value: .scalar(0)),
                .init(id: DepthMapParameterID.far, value: .scalar(1)),
                .init(id: DepthMapParameterID.smoothing, value: .scalar(0.08)),
                .init(id: DepthMapParameterID.edgeRefinement, value: .scalar(0.18)),
                .init(id: DepthMapParameterID.temporalSmoothing, value: .scalar(0.12)),
                .init(id: DepthMapParameterID.output, value: .text("depth"))
            ])
        case .cutout:
            return Self(type: type, parameters: [
                .init(id: CutoutParameterID.quality, value: .text("balanced")),
                .init(id: CutoutParameterID.mode, value: .text("foregroundFast")),
                .init(id: CutoutParameterID.feather, value: .scalar(0.04)),
                .init(id: CutoutParameterID.edgeCleanup, value: .scalar(0.2)),
                .init(id: CutoutParameterID.temporalSmoothing, value: .scalar(0.15)),
                .init(id: CutoutParameterID.promptX, value: .scalar(0.5)),
                .init(id: CutoutParameterID.promptY, value: .scalar(0.5))
            ])
        case .upscale:
            return Self(type: type, parameters: [
                .init(id: UpscaleParameterID.quality, value: .text("balanced")),
                .init(id: UpscaleParameterID.profile, value: .text("general")),
                .init(id: UpscaleParameterID.scale, value: .scalar(2)),
                .init(id: UpscaleParameterID.tileOverlap, value: .integer(32))
            ])
        case .restore:
            return Self(type: type, parameters: [
                .init(id: RestorationParameterID.quality, value: .text("balanced")),
                .init(id: RestorationParameterID.denoise, value: .scalar(0.45)),
                .init(id: RestorationParameterID.deblur, value: .scalar(0)),
                .init(id: RestorationParameterID.artifactRemoval, value: .scalar(0.25)),
                .init(id: RestorationParameterID.detailRecovery, value: .scalar(0.25)),
                .init(id: RestorationParameterID.faceRestoration, value: .boolean(false))
            ])
        }
    }

    public func parameter(id: String) -> ProjectEffectParameter? {
        parameters.first { $0.id == id }
    }

    public mutating func setParameter(id: String, value: ProjectEffectParameterValue) throws {
        guard let index = parameters.firstIndex(where: { $0.id == id }) else {
            throw ProjectError.invalidValue("Effect parameter is missing: \(id).")
        }
        parameters[index].value = value
        _ = try validated()
    }

    public func validated() throws -> Self {
        guard version == 1 else { throw ProjectError.invalidValue("Unsupported project effect version: \(version).") }
        guard Set(parameters.map(\.id)).count == parameters.count else {
            throw ProjectError.duplicateIdentity("effect parameter")
        }
        for parameter in parameters {
            guard !parameter.id.isEmpty else { throw ProjectError.invalidValue("Effect parameter IDs must not be empty.") }
            _ = try parameter.value.validated()
        }
        try validateDescriptor()
        return self
    }

    private func validateDescriptor() throws {
        let expected: [String: ParameterRule]
        switch type {
        case .depthMap:
            expected = [
                DepthMapParameterID.model: .text(allowed: ["depth-anything-v2-small-f16"]),
                DepthMapParameterID.quality: .text(allowed: ["preview", "balanced", "quality"]),
                DepthMapParameterID.invert: .boolean,
                DepthMapParameterID.near: .scalar(0...1),
                DepthMapParameterID.far: .scalar(0...1),
                DepthMapParameterID.smoothing: .scalar(0...1),
                DepthMapParameterID.edgeRefinement: .scalar(0...1),
                DepthMapParameterID.temporalSmoothing: .scalar(0...1),
                DepthMapParameterID.output: .text(allowed: ["depth", "alpha"])
            ]
        case .cutout:
            expected = [
                CutoutParameterID.quality: .text(allowed: ["preview", "balanced", "quality"]),
                CutoutParameterID.mode: .text(allowed: ["personFast", "foregroundFast", "promptQuality"]),
                CutoutParameterID.feather: .scalar(0...1),
                CutoutParameterID.edgeCleanup: .scalar(0...1),
                CutoutParameterID.temporalSmoothing: .scalar(0...1),
                CutoutParameterID.promptX: .scalar(0...1),
                CutoutParameterID.promptY: .scalar(0...1)
            ]
        case .upscale:
            expected = [
                UpscaleParameterID.quality: .text(allowed: ["preview", "balanced", "quality"]),
                UpscaleParameterID.profile: .text(allowed: ["general", "animeGame"]),
                UpscaleParameterID.scale: .scalar(1...4),
                UpscaleParameterID.tileOverlap: .integer(0...256)
            ]
        case .restore:
            expected = [
                RestorationParameterID.quality: .text(allowed: ["preview", "balanced", "quality"]),
                RestorationParameterID.denoise: .scalar(0...1),
                RestorationParameterID.deblur: .scalar(0...1),
                RestorationParameterID.artifactRemoval: .scalar(0...1),
                RestorationParameterID.detailRecovery: .scalar(0...1),
                RestorationParameterID.faceRestoration: .boolean
            ]
        }
        guard Set(parameters.map(\.id)) == Set(expected.keys) else {
            let unknown = Set(parameters.map(\.id)).subtracting(expected.keys).sorted()
            let missing = Set(expected.keys).subtracting(parameters.map(\.id)).sorted()
            throw ProjectError.invalidValue("Effect parameters do not match descriptor. Unknown: \(unknown). Missing: \(missing).")
        }
        for parameter in parameters {
            guard let rule = expected[parameter.id] else { throw ProjectError.invalidValue("Unknown effect parameter: \(parameter.id).") }
            try rule.validate(parameter.value, id: parameter.id)
        }
        if type == .depthMap,
           case .scalar(let near)? = parameter(id: DepthMapParameterID.near)?.value,
           case .scalar(let far)? = parameter(id: DepthMapParameterID.far)?.value,
           !(near < far) {
            throw ProjectError.invalidValue("Depth near must be less than far.")
        }
    }
}

private enum ParameterRule {
    case scalar(ClosedRange<Double>)
    case integer(ClosedRange<Int>)
    case boolean
    case text(allowed: Set<String>)

    func validate(_ value: ProjectEffectParameterValue, id: String) throws {
        switch (self, value) {
        case (.scalar(let range), .scalar(let scalar)) where scalar.isFinite && range.contains(scalar): return
        case (.integer(let range), .integer(let integer)) where range.contains(integer): return
        case (.boolean, .boolean): return
        case (.text(let allowed), .text(let text)) where allowed.contains(text): return
        default: throw ProjectError.invalidValue("Effect parameter \(id) has an invalid type or value.")
        }
    }
}

public extension Array where Element == ProjectEffect {
    func validatedEffects() throws -> [ProjectEffect] {
        guard Set(map(\.id)).count == count else { throw ProjectError.duplicateIdentity("effect") }
        for effect in self { _ = try effect.validated() }
        return self
    }
}
''')

# Animation address supports effect parameter IDs.
path = "Sources/VertexProject/ProjectAnimation.swift"
text = read(path)
if "case effect(effectID:" not in text:
    text = text.replace(
        "    case mask(maskID: VertexID, property: ProjectMaskAnimatableProperty)\n",
        "    case mask(maskID: VertexID, property: ProjectMaskAnimatableProperty)\n    case effect(effectID: VertexID, parameterID: String, valueKind: ProjectAnimatableValueKind)\n",
        1,
    )
    text = text.replace(
        '''        case .mask(_, let property):
            return property == .path ? .bezierPath : .scalar
''',
        '''        case .mask(_, let property):
            return property == .path ? .bezierPath : .scalar
        case .effect(_, _, let valueKind):
            return valueKind
''', 1)
    text = text.replace(
        '''        case .mask(let maskID, let property):
            return "mask.\(maskID.rawValue).\(property.rawValue)"
''',
        '''        case .mask(let maskID, let property):
            return "mask.\(maskID.rawValue).\(property.rawValue)"
        case .effect(let effectID, let parameterID, let valueKind):
            return "effect.\(effectID.rawValue).\(parameterID).\(valueKind.rawValue)"
''', 1)
old_sig = "    func validatedAnimationChannels(for masks: [ProjectMask] = []) throws -> [ProjectAnimationChannel] {\n"
new_sig = "    func validatedAnimationChannels(for masks: [ProjectMask] = [], effects: [ProjectEffect] = []) throws -> [ProjectAnimationChannel] {\n"
if old_sig in text: text = text.replace(old_sig, new_sig, 1)
validation = '''            if case .mask(let maskID, _) = channel.property, !maskIDs.contains(maskID) {
                throw ProjectError.invalidValue("Mask animation channel references a missing mask.")
            }
'''
expanded = validation + r'''            if case .effect(let effectID, let parameterID, let valueKind) = channel.property {
                guard let effect = effects.first(where: { $0.id == effectID }),
                      let parameter = effect.parameter(id: parameterID),
                      let animatableKind = parameter.value.animatableKind,
                      animatableKind == valueKind else {
                    throw ProjectError.invalidValue("Effect animation channel references a missing or non-animatable parameter.")
                }
            }
'''
if "Effect animation channel references" not in text:
    if validation not in text: raise RuntimeError("animation validation anchor missing")
    text = text.replace(validation, expanded, 1)
write(path, text)

# ProjectLayer effects persisted and validated.
path = "Sources/VertexProject/ProjectLayer.swift"
text = read(path)
if "public var effects: [ProjectEffect]" not in text:
    text = text.replace("    public var operations: [LayerOperation]\n", "    public var operations: [LayerOperation]\n    public var effects: [ProjectEffect]\n", 1)
    text = text.replace("        case operations\n", "        case operations\n        case effects\n", 1)
    text = text.replace("        operations: [LayerOperation] = [],\n", "        operations: [LayerOperation] = [],\n        effects: [ProjectEffect] = [],\n", 1)
    text = text.replace("        self.operations = operations\n", "        self.operations = operations\n        self.effects = effects\n", 1)
    text = text.replace("        operations = try container.decode([LayerOperation].self, forKey: .operations)\n", "        operations = try container.decode([LayerOperation].self, forKey: .operations)\n        effects = try container.decodeIfPresent([ProjectEffect].self, forKey: .effects) ?? []\n", 1)
    text = text.replace("        try container.encode(operations, forKey: .operations)\n", "        try container.encode(operations, forKey: .operations)\n        try container.encode(effects, forKey: .effects)\n", 1)
text = text.replace("        for operation in operations { _ = try operation.validated() }\n", "        for operation in operations { _ = try operation.validated() }\n        _ = try effects.validatedEffects()\n", 1)
text = text.replace("        _ = try animationChannels.validatedAnimationChannels(for: masks)\n", "        _ = try animationChannels.validatedAnimationChannels(for: masks, effects: effects)\n", 1)
# Strict Phase9 support: only media layers can own these AI effects.
switch_anchor = '''        switch source {
        case .media(let mediaID, let sourceStartTime):
'''
if "Phase 9 AI effects currently require a media layer" not in text:
    text = text.replace(switch_anchor, '''        if !effects.isEmpty {
            guard case .media = source else {
                throw ProjectError.invalidValue("Phase 9 AI effects currently require a media layer.")
            }
        }

''' + switch_anchor, 1)
# Model-only guard should mention effects, though earlier guard catches it.
text = text.replace("guard blendMode == .normal, operations.isEmpty, masks.isEmpty, trackMatte == nil else", "guard blendMode == .normal, operations.isEmpty, effects.isEmpty, masks.isEmpty, trackMatte == nil else")
write(path, text)

# Payload effect operations.
path = "Sources/VertexProject/ProjectCommandPayload.swift"
text = read(path)
anchor = "    case setLayerOperations(id: VertexID, operations: [LayerOperation])\n"
insert = anchor + '''    case setLayerEffects(id: VertexID, effects: [ProjectEffect])
    case insertLayerEffect(id: VertexID, effect: ProjectEffect, index: Int)
    case removeLayerEffect(id: VertexID, effectID: VertexID)
    case moveLayerEffect(id: VertexID, effectID: VertexID, toIndex: Int)
    case setLayerEffectEnabled(id: VertexID, effectID: VertexID, value: Bool)
'''
if "case setLayerEffects" not in text:
    if anchor not in text: raise RuntimeError("effect payload anchor missing")
    text = text.replace(anchor, insert, 1)
write(path, text)

# One reversible mutation covers exact stack state.
path = "Sources/VertexProject/ProjectMutation.swift"
text = read(path)
anchor = "    case setLayerOperations(layerID: VertexID, before: [LayerOperation], after: [LayerOperation])\n"
insert = anchor + "    case setLayerEffects(layerID: VertexID, before: [ProjectEffect], after: [ProjectEffect])\n"
if "case setLayerEffects(layerID" not in text:
    text = text.replace(anchor, insert, 1)
inv = "        case .setLayerOperations(let id, let before, let after): .setLayerOperations(layerID: id, before: after, after: before)\n"
inv2 = inv + "        case .setLayerEffects(let id, let before, let after): .setLayerEffects(layerID: id, before: after, after: before)\n"
if "case .setLayerEffects(let id" not in text: text = text.replace(inv, inv2, 1)
write(path, text)

# Project command prepare/apply.
path = "Sources/VertexProject/ProjectCommands.swift"
text = read(path)
anchor = '''        case .setLayerOperations(let id, let operations):
            let layer = try editableLayer(id, in: document)
            guard operations != layer.operations else { throw ProjectError.invalidOperation("Layer operations are unchanged.") }
            for operation in operations { _ = try operation.validated() }
            forward = .setLayerOperations(layerID: id, before: layer.operations, after: operations)
'''
insert = anchor + r'''

        case .setLayerEffects(let id, let effects):
            let layer = try editableLayer(id, in: document)
            guard effects != layer.effects else { throw ProjectError.invalidOperation("Layer effect stack is unchanged.") }
            var candidate = layer
            candidate.effects = effects
            _ = try candidate.validated(in: document)
            forward = .setLayerEffects(layerID: id, before: layer.effects, after: effects)

        case .insertLayerEffect(let id, let effect, let index):
            let layer = try editableLayer(id, in: document)
            guard !layer.effects.contains(where: { $0.id == effect.id }),
                  layer.effects.indices.contains(index) || index == layer.effects.endIndex else {
                throw ProjectError.invalidOperation("Effect insertion index or identity is invalid.")
            }
            _ = try effect.validated()
            var next = layer.effects
            next.insert(effect, at: index)
            var candidate = layer; candidate.effects = next
            _ = try candidate.validated(in: document)
            forward = .setLayerEffects(layerID: id, before: layer.effects, after: next)

        case .removeLayerEffect(let id, let effectID):
            let layer = try editableLayer(id, in: document)
            guard let index = layer.effects.firstIndex(where: { $0.id == effectID }) else {
                throw ProjectError.invalidOperation("Effect is missing.")
            }
            guard !layer.animationChannels.contains(where: {
                if case .effect(let referenced, _, _) = $0.property { return referenced == effectID }
                return false
            }) else {
                throw ProjectError.invalidOperation("Remove effect animation channels before deleting the effect.")
            }
            var next = layer.effects; next.remove(at: index)
            forward = .setLayerEffects(layerID: id, before: layer.effects, after: next)

        case .moveLayerEffect(let id, let effectID, let toIndex):
            let layer = try editableLayer(id, in: document)
            guard let from = layer.effects.firstIndex(where: { $0.id == effectID }),
                  layer.effects.indices.contains(toIndex), from != toIndex else {
                throw ProjectError.invalidOperation("Effect reorder is invalid or unchanged.")
            }
            var next = layer.effects
            let effect = next.remove(at: from)
            next.insert(effect, at: toIndex)
            forward = .setLayerEffects(layerID: id, before: layer.effects, after: next)

        case .setLayerEffectEnabled(let id, let effectID, let value):
            let layer = try editableLayer(id, in: document)
            guard let index = layer.effects.firstIndex(where: { $0.id == effectID }), layer.effects[index].enabled != value else {
                throw ProjectError.invalidOperation("Effect enabled state is unchanged or effect is missing.")
            }
            var next = layer.effects; next[index].enabled = value
            forward = .setLayerEffects(layerID: id, before: layer.effects, after: next)
'''
if "case .setLayerEffects(let id, let effects):" not in text:
    if anchor not in text: raise RuntimeError("effect prepare anchor missing")
    text = text.replace(anchor, insert, 1)
apply_anchor = '        case .setLayerOperations(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].operations == before else { throw ProjectError.invalidOperation("Layer operations precondition did not match.") }; document.layerRegistry[index].operations = after\n'
apply_insert = apply_anchor + '        case .setLayerEffects(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].effects == before else { throw ProjectError.invalidOperation("Layer effects precondition did not match.") }; document.layerRegistry[index].effects = after\n'
if "case .setLayerEffects(let id, let before, let after):" not in text:
    if apply_anchor not in text: raise RuntimeError("effect apply anchor missing")
    text = text.replace(apply_anchor, apply_insert, 1)
write(path, text)
print("Task 5 GREEN implementation applied")
