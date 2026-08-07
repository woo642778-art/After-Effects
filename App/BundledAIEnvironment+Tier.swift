import Foundation
import VertexAI
import VertexAICoreML

extension BundledAIEnvironment {
    func modelIdentity(for recipe: AITaskRecipe, qualityTier: AIQualityTier) throws -> (id: String, digest: String) {
        guard case .restoration(let restoration) = recipe else {
            return try modelIdentity(for: recipe)
        }
        let plan = try RestorationModelPlan.resolve(recipe: restoration, qualityTier: qualityTier)
        var material: [String] = []
        for modelID in plan.modelIDs {
            guard let entry = manifest.models.first(where: { $0.modelID == modelID }),
                  let digest = entry.convertedSHA256, digest.count == 64 else {
                throw AIError.modelUnavailable(modelID)
            }
            material.append("\(modelID):\(digest)")
        }
        return (
            plan.modelIDs.joined(separator: "+"),
            AIDigest.sha256(Data(material.joined(separator: "|").utf8))
        )
    }
}
