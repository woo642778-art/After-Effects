import Foundation

public struct AIModelManifestEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String { modelID }

    public let modelID: String
    public let task: String
    public let upstream: String
    public let upstreamVersion: String
    public let license: String
    public let sourceSHA256: String
    public let convertedSHA256: String?
    public let precision: String
    public let compiledSizeBytes: UInt64?
    public let minimumTier: AIQualityTier
    public let bundleRelativePath: String

    public init(
        modelID: String,
        task: String,
        upstream: String,
        upstreamVersion: String,
        license: String,
        sourceSHA256: String,
        convertedSHA256: String?,
        precision: String,
        compiledSizeBytes: UInt64?,
        minimumTier: AIQualityTier,
        bundleRelativePath: String
    ) {
        self.modelID = modelID
        self.task = task
        self.upstream = upstream
        self.upstreamVersion = upstreamVersion
        self.license = license
        self.sourceSHA256 = sourceSHA256
        self.convertedSHA256 = convertedSHA256
        self.precision = precision
        self.compiledSizeBytes = compiledSizeBytes
        self.minimumTier = minimumTier
        self.bundleRelativePath = bundleRelativePath
    }

    public func validated() throws -> Self {
        guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.invalidManifest("modelID must not be empty")
        }
        guard !task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.invalidManifest("task must not be empty for \(modelID)")
        }
        guard let url = URL(string: upstream), url.scheme?.lowercased() == "https" else {
            throw AIError.invalidManifest("upstream must be HTTPS for \(modelID)")
        }
        guard !upstreamVersion.isEmpty, !license.isEmpty, !precision.isEmpty else {
            throw AIError.invalidManifest("version, license, and precision are required for \(modelID)")
        }
        guard Self.isSHA256(sourceSHA256) else {
            throw AIError.invalidManifest("source SHA-256 is invalid for \(modelID)")
        }
        if let convertedSHA256, !Self.isSHA256(convertedSHA256) {
            throw AIError.invalidManifest("converted SHA-256 is invalid for \(modelID)")
        }
        guard !bundleRelativePath.hasPrefix("/"),
              !bundleRelativePath.split(separator: "/").contains(".."),
              !bundleRelativePath.isEmpty else {
            throw AIError.invalidManifest("bundle path must remain relative for \(modelID)")
        }
        return self
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { character in
            character.isNumber || ("a"..."f").contains(String(character).lowercased())
        }
    }
}

public struct AIModelManifest: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let models: [AIModelManifestEntry]

    public init(formatVersion: Int = 1, models: [AIModelManifestEntry]) {
        self.formatVersion = formatVersion
        self.models = models
    }

    public func validated(requireConvertedDigests: Bool = false) throws -> Self {
        guard formatVersion == 1 else {
            throw AIError.invalidManifest("unsupported manifest format \(formatVersion)")
        }
        var modelIDs = Set<String>()
        var bundlePaths = Set<String>()
        for model in models {
            _ = try model.validated()
            guard modelIDs.insert(model.modelID).inserted else {
                throw AIError.invalidManifest("duplicate modelID: \(model.modelID)")
            }
            guard bundlePaths.insert(model.bundleRelativePath).inserted else {
                throw AIError.invalidManifest("duplicate bundle path: \(model.bundleRelativePath)")
            }
            if requireConvertedDigests, model.convertedSHA256 == nil {
                throw AIError.invalidManifest("missing converted digest for \(model.modelID)")
            }
        }
        return self
    }
}
