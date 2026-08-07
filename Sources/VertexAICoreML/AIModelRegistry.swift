import Foundation
import VertexAI

#if canImport(CoreML)
@preconcurrency import CoreML

/// Core ML model objects are intentionally kept behind a synchronous locked
/// boundary. `MLModel` is not Sendable in Swift 6, so it must never cross an
/// actor isolation boundary. The closure executes while the registry owns the
/// model reference and returns only the caller's result.
public final class AIModelRegistry: @unchecked Sendable {
    public let resourceRoot: URL
    private let entriesByID: [String: AIModelManifestEntry]
    private let lock = NSLock()
    private var resident: [String: MLModel] = [:]

    public init(resourceRoot: URL, manifest: AIModelManifest) throws {
        let validated = try manifest.validated()
        self.resourceRoot = resourceRoot
        self.entriesByID = Dictionary(uniqueKeysWithValues: validated.models.map { ($0.modelID, $0) })
    }

    public var residentModelIDs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return resident.keys.sorted()
    }

    public func withModel<T>(
        for modelID: String,
        computeUnits: MLComputeUnits = .all,
        _ body: (MLModel) throws -> T
    ) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        let model = try loadLocked(modelID: modelID, computeUnits: computeUnits)
        return try body(model)
    }

    public func unload(modelID: String) {
        lock.lock()
        defer { lock.unlock() }
        resident.removeValue(forKey: modelID)
    }

    public func unloadAll() {
        lock.lock()
        defer { lock.unlock() }
        resident.removeAll(keepingCapacity: false)
    }

    private func loadLocked(modelID: String, computeUnits: MLComputeUnits) throws -> MLModel {
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
}

#else

/// Portable compile stub. Native inference is unavailable by contract.
public final class AIModelRegistry: @unchecked Sendable {
    public init(resourceRoot: URL, manifest: AIModelManifest) throws {
        _ = try manifest.validated()
    }

    public var residentModelIDs: [String] { [] }
    public func unload(modelID: String) {}
    public func unloadAll() {}
}

#endif
