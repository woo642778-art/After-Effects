import Foundation
import VertexAI

#if canImport(CoreML)
import CoreML

public actor AIModelRegistry {
    public let resourceRoot: URL
    private let entriesByID: [String: AIModelManifestEntry]
    private var resident: [String: MLModel] = [:]

    public init(resourceRoot: URL, manifest: AIModelManifest) throws {
        let validated = try manifest.validated()
        self.resourceRoot = resourceRoot
        self.entriesByID = Dictionary(uniqueKeysWithValues: validated.models.map { ($0.modelID, $0) })
    }

    public var residentModelIDs: [String] {
        resident.keys.sorted()
    }

    public func model(for modelID: String, computeUnits: MLComputeUnits = .all) async throws -> MLModel {
        if let cached = resident[modelID] { return cached }
        guard let entry = entriesByID[modelID] else { throw AIError.modelUnavailable(modelID) }
        let url = resourceRoot.appendingPathComponent(entry.bundleRelativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AIError.modelUnavailable(modelID)
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeUnits
        do {
            let loaded = try MLModel(contentsOf: url, configuration: configuration)
            resident[modelID] = loaded
            return loaded
        } catch {
            throw AIError.inferenceFailed("Core ML could not load \(modelID): \(error.localizedDescription)")
        }
    }

    public func unload(modelID: String) {
        resident.removeValue(forKey: modelID)
    }

    public func unloadAll() {
        resident.removeAll(keepingCapacity: false)
    }
}

#else

/// Linux/portable compile stub. Native inference is unavailable by contract.
public actor AIModelRegistry {
    public init(resourceRoot: URL, manifest: AIModelManifest) throws {
        _ = try manifest.validated()
    }

    public var residentModelIDs: [String] { [] }
    public func unload(modelID: String) {}
    public func unloadAll() {}
}

#endif
