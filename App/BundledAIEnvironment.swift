import Foundation
import VertexAI
import VertexAICoreML
import VertexAIAVFoundation

struct BundledAIEnvironment {
    let manifest: AIModelManifest
    let registry: AIModelRegistry
    let processor: AIVideoProcessor

    static func load(bundle: Bundle = .main) throws -> BundledAIEnvironment {
        guard let resourceRoot = bundle.resourceURL,
              let manifestURL = bundle.url(forResource: "AI_MODEL_MANIFEST", withExtension: "json") else {
            throw AIError.modelUnavailable("AI_MODEL_MANIFEST.json")
        }
        let data = try Data(contentsOf: manifestURL)
        let manifest: AIModelManifest
        do {
            manifest = try JSONDecoder().decode(AIModelManifest.self, from: data)
                .validated(requireConvertedDigests: true)
        } catch {
            throw AIError.invalidManifest("Bundled AI manifest is invalid: \(error.localizedDescription)")
        }
        let registry = try AIModelRegistry(resourceRoot: resourceRoot, manifest: manifest)
        return BundledAIEnvironment(
            manifest: manifest,
            registry: registry,
            processor: AIVideoProcessor(registry: registry)
        )
    }

    func modelIdentity(for recipe: AITaskRecipe) throws -> (id: String, digest: String) {
        switch recipe {
        case .depth:
            return try manifestIdentity(id: "depth-anything-v2-small-f16")
        case .upscale(let value):
            guard let modelID = UpscaleModelSelection.modelID(for: value.profile) else {
                throw AIError.unsupportedCapability("Anime/Game upscale is not enabled until a dedicated validated model ships.")
            }
            return try manifestIdentity(id: modelID)
        case .restoration(let value):
            let requestedTier: AIQualityTier = .maxQuality
            let plan = try RestorationModelPlan.resolve(recipe: value, qualityTier: requestedTier)
            let entries = try plan.modelIDs.map { id -> AIModelManifestEntry in
                guard let entry = manifest.models.first(where: { $0.modelID == id }),
                      let digest = entry.convertedSHA256, digest.count == 64 else {
                    throw AIError.modelUnavailable(id)
                }
                return entry
            }
            let identity = entries.map(\.modelID).joined(separator: "+")
            let material = entries.map { "\($0.modelID):\($0.convertedSHA256 ?? "")" }.joined(separator: "|")
            return (identity, AIDigest.sha256(Data(material.utf8)))
        case .cutout(let value):
            let os = ProcessInfo.processInfo.operatingSystemVersionString
            let id = value.mode == .personFast ? "apple-vision-person-segmentation" : "apple-vision-foreground-instance-mask"
            return (id, AIDigest.sha256(Data("\(id)|\(os)".utf8)))
        }
    }

    private func manifestIdentity(id: String) throws -> (id: String, digest: String) {
        guard let entry = manifest.models.first(where: { $0.modelID == id }),
              let digest = entry.convertedSHA256, digest.count == 64 else {
            throw AIError.modelUnavailable(id)
        }
        return (id, digest)
    }
}
