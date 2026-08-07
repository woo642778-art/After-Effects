import Foundation

public enum AIResultKind: String, Codable, CaseIterable, Sendable {
    case depth
    case matte
    case derivedVideo
}

public struct AIResultDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: AIResultKind
    public let sourceFingerprint: String
    public let jobDigest: String
    public let outputRelativePath: String
    public let outputSHA256: String
    public let width: Int
    public let height: Int
    public let frameCount: Int64
    public let highPrecision: Bool

    public init(
        kind: AIResultKind,
        sourceFingerprint: String,
        jobDigest: String,
        outputRelativePath: String,
        outputSHA256: String,
        width: Int,
        height: Int,
        frameCount: Int64,
        highPrecision: Bool
    ) throws {
        guard !sourceFingerprint.isEmpty, jobDigest.count == 64, outputSHA256.count == 64 else {
            throw AIError.outputVerificationFailed("Result source/job/output digests are incomplete.")
        }
        let path = outputRelativePath.split(separator: "/")
        guard !outputRelativePath.hasPrefix("/"), !path.contains(".."), !path.isEmpty else {
            throw AIError.outputVerificationFailed("Result path must remain relative to the derived-media root.")
        }
        guard width > 0, height > 0, frameCount > 0 else {
            throw AIError.outputVerificationFailed("Result dimensions and frame count must be positive.")
        }
        self.kind = kind
        self.sourceFingerprint = sourceFingerprint
        self.jobDigest = jobDigest
        self.outputRelativePath = outputRelativePath
        self.outputSHA256 = outputSHA256
        self.width = width
        self.height = height
        self.frameCount = frameCount
        self.highPrecision = highPrecision
        self.id = StableAISHA256.hexDigest(Data("\(jobDigest)|\(outputRelativePath)|\(outputSHA256)".utf8))
    }
}
