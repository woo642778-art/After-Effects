import Foundation
import VertexAI
import VertexComposition
import VertexMedia
import VertexProject

struct CompositionEffectResolverAdapter: CompositionEffectResolver {
    let service: AIFrameEffectService
    let environment: BundledAIEnvironment

    func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage {
        let (recipe, requestedTier) = try request.effect.aiRecipeAndTier()
        let identity = try environment.modelIdentity(for: recipe, qualityTier: requestedTier)
        let parameterDigest = try AIRecipeCodec.digest(recipe)
        let sourceFingerprint = AIDigest.sha256(request.input.data)
        let key = try AIFrameEffectKey(
            sourceFingerprint: sourceFingerprint,
            exactTime: request.exactSourceTime,
            modelID: identity.id,
            modelDigest: identity.digest,
            effectType: request.effect.type.rawValue,
            algorithmVersion: 1,
            parameterDigest: parameterDigest,
            qualityTier: requestedTier.rawValue,
            width: Int(request.targetSize.width.rounded()),
            height: Int(request.targetSize.height.rounded()),
            orientationDigest: "upright",
            colorDigest: "rec709"
        )
        let frameRequest = AIFrameEffectRequest(key: key, effectID: request.effect.id, effect: request.effect, qualityTier: requestedTier, input: request.input)
        return try await service.resolve(request: frameRequest, priority: .currentFrame)
    }
}
