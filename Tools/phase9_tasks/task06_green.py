from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def read(p): return (ROOT/p).read_text()
def write(p,t): q=ROOT/p; q.parent.mkdir(parents=True,exist_ok=True); q.write_text(t)

write("Sources/VertexComposition/CompositionEffectResolver.swift", r'''import Foundation
import VertexCore
import VertexMedia
import VertexProject

public enum CompositionRenderPurpose: String, Codable, Sendable {
    case interactivePreview
    case export
}

public struct CompositionEffectRequest: Sendable {
    public var projectID: VertexID
    public var projectRevision: UInt64
    public var compositionID: VertexID
    public var layerID: VertexID
    public var effect: ProjectEffect
    public var exactCompositionTime: RationalTime
    public var exactSourceTime: RationalTime
    public var input: PortableImage
    public var targetSize: VertexSize
    public var purpose: CompositionRenderPurpose

    public init(
        projectID: VertexID,
        projectRevision: UInt64,
        compositionID: VertexID,
        layerID: VertexID,
        effect: ProjectEffect,
        exactCompositionTime: RationalTime,
        exactSourceTime: RationalTime,
        input: PortableImage,
        targetSize: VertexSize,
        purpose: CompositionRenderPurpose
    ) {
        self.projectID = projectID
        self.projectRevision = projectRevision
        self.compositionID = compositionID
        self.layerID = layerID
        self.effect = effect
        self.exactCompositionTime = exactCompositionTime
        self.exactSourceTime = exactSourceTime
        self.input = input
        self.targetSize = targetSize
        self.purpose = purpose
    }
}

public protocol CompositionEffectResolver: Sendable {
    func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage
}

public struct RejectingCompositionEffectResolver: CompositionEffectResolver {
    public init() {}
    public func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage {
        throw CompositionError.graphCompilationFailed(
            "Layer \(request.layerID.rawValue) requires effect \(request.effect.type.rawValue), but no effect resolver was provided."
        )
    }
}
''')

write("Sources/VertexComposition/EffectAnimationEvaluator.swift", r'''import Foundation
import VertexCore
import VertexProject

public enum EffectAnimationEvaluator {
    public static func evaluate(
        effect: ProjectEffect,
        channels: [ProjectAnimationChannel],
        at time: RationalTime
    ) throws -> ProjectEffect {
        _ = try effect.validated()
        var result = effect
        for channel in channels {
            guard case .effect(let effectID, let parameterID, let valueKind) = channel.property,
                  effectID == effect.id else { continue }
            guard let index = result.parameters.firstIndex(where: { $0.id == parameterID }),
                  let parameterKind = result.parameters[index].value.animatableKind,
                  parameterKind == valueKind else {
                throw ProjectError.invalidValue("Effect animation references a missing or incompatible parameter.")
            }
            let value = try channel.evaluatedValue(at: time)
            switch (valueKind, value) {
            case (.scalar, .scalar(let scalar)):
                result.parameters[index].value = .scalar(scalar)
            case (.boolean, .boolean(let boolean)):
                result.parameters[index].value = .boolean(boolean)
            default:
                throw ProjectError.invalidValue("Effect animation value type does not match its parameter.")
            }
        }
        return try result.validated()
    }
}
''')

# Request purpose.
p="Sources/VertexComposition/CompositionTypes.swift"; t=read(p)
if "public var purpose: CompositionRenderPurpose" not in t:
    t=t.replace("    public var limits: CompositionRenderLimits\n", "    public var limits: CompositionRenderLimits\n    public var purpose: CompositionRenderPurpose\n",1)
    t=t.replace("        output: RenderOutputSpecification,\n        limits: CompositionRenderLimits = CompositionRenderLimits()\n", "        output: RenderOutputSpecification,\n        limits: CompositionRenderLimits = CompositionRenderLimits(),\n        purpose: CompositionRenderPurpose = .interactivePreview\n",1)
    t=t.replace("        self.limits = limits\n", "        self.limits = limits\n        self.purpose = purpose\n",1)
write(p,t)

p="Sources/VertexComposition/CompositionGraphCompiler.swift"; t=read(p)
t=t.replace("public static let compilerVersion = 2", "public static let compilerVersion = 3")
# Signature + state init.
old='''        _ request: CompositionRenderRequest,
        resolver: any CompositionFrameResolver,
        cancellationToken: RenderCancellationToken
    ) async throws -> RenderRequest {'''
new='''        _ request: CompositionRenderRequest,
        resolver: any CompositionFrameResolver,
        effectResolver: any CompositionEffectResolver = RejectingCompositionEffectResolver(),
        cancellationToken: RenderCancellationToken
    ) async throws -> RenderRequest {'''
if old in t: t=t.replace(old,new,1)
old='''            limits: limits,
            resolver: resolver,
            cancellationToken: cancellationToken
        )'''
new='''            limits: limits,
            resolver: resolver,
            effectResolver: effectResolver,
            purpose: request.purpose,
            cancellationToken: cancellationToken
        )'''
if old in t: t=t.replace(old,new,1)
# State props/init.
if "let effectResolver: any CompositionEffectResolver" not in t:
    t=t.replace("    let resolver: any CompositionFrameResolver\n", "    let resolver: any CompositionFrameResolver\n    let effectResolver: any CompositionEffectResolver\n    let purpose: CompositionRenderPurpose\n",1)
    t=t.replace("        resolver: any CompositionFrameResolver,\n        cancellationToken: RenderCancellationToken\n", "        resolver: any CompositionFrameResolver,\n        effectResolver: any CompositionEffectResolver,\n        purpose: CompositionRenderPurpose,\n        cancellationToken: RenderCancellationToken\n",1)
    t=t.replace("        self.resolver = resolver\n        self.cancellationToken = cancellationToken\n", "        self.resolver = resolver\n        self.effectResolver = effectResolver\n        self.purpose = purpose\n        self.cancellationToken = cancellationToken\n",1)
# Media source calculation and effect resolution.
old=r'''        case .media(let mediaID, let sourceStartTime):
            let sourceTime = try compositionTime
                .subtracting(layer.timing.startTime)
                .adding(sourceStartTime)
            guard sourceTime >= .zero else { return nil }
            let resolution = try await resolveFrame(mediaID: mediaID, time: sourceTime)
            guard case .frame(let image) = resolution else { return nil }
            sourceID = try nodeID(path: path, role: "source")
            try append(RenderNode(
                id: sourceID,
                dependencies: [],
                kind: .source(image)
            ))
'''
new=r'''        case .media(let mediaID, let sourceStartTime):
            let sourceTime = try compositionTime
                .subtracting(layer.timing.startTime)
                .adding(sourceStartTime)
                .adding(layer.timing.sourceOffset)
            guard sourceTime >= .zero else { return nil }
            let resolution = try await resolveFrame(mediaID: mediaID, time: sourceTime)
            guard case .frame(let decodedImage) = resolution else { return nil }
            var image = decodedImage
            for effect in layer.effects where effect.enabled {
                try await cancellationToken.throwIfCancelled()
                let evaluatedEffect = try EffectAnimationEvaluator.evaluate(
                    effect: effect,
                    channels: layer.animationChannels,
                    at: compositionTime
                )
                do {
                    image = try await effectResolver.resolve(CompositionEffectRequest(
                        projectID: project.projectID,
                        projectRevision: project.revision,
                        compositionID: layer.compositionID,
                        layerID: layer.id,
                        effect: evaluatedEffect,
                        exactCompositionTime: compositionTime,
                        exactSourceTime: sourceTime,
                        input: image,
                        targetSize: VertexSize(width: Double(output.width), height: Double(output.height)),
                        purpose: purpose
                    ))
                } catch let error as CompositionError {
                    throw error
                } catch {
                    throw CompositionError.graphCompilationFailed(
                        "Effect \(effect.type.rawValue) on layer \(layer.id.rawValue) failed at \(compositionTime.description): \(error.localizedDescription)"
                    )
                }
            }
            sourceID = try nodeID(path: path, role: "source")
            try append(RenderNode(
                id: sourceID,
                dependencies: [],
                kind: .source(image)
            ))
'''
if old in t: t=t.replace(old,new,1)
elif new not in t: raise RuntimeError("media compile block missing")
# Nested defensive effect guard + sourceOffset.
old=r'''        case .composition(let childID, let sourceStartTime):
            let childTime = try compositionTime
                .subtracting(layer.timing.startTime)
                .adding(sourceStartTime)
            guard childTime >= .zero else { return nil }
'''
new=r'''        case .composition(let childID, let sourceStartTime):
            guard !layer.effects.contains(where: \.enabled) else {
                throw CompositionError.graphCompilationFailed("Phase 9 AI effects cannot be applied to nested-composition layers until nested output materialization is implemented.")
            }
            let childTime = try compositionTime
                .subtracting(layer.timing.startTime)
                .adding(sourceStartTime)
                .adding(layer.timing.sourceOffset)
            guard childTime >= .zero else { return nil }
'''
if old in t: t=t.replace(old,new,1)
write(p,t)
print("Task 6 GREEN implementation applied")
