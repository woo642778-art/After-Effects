import Foundation

public struct AIJobIdentity: Codable, Equatable, Hashable, Sendable {
    public let sourceFingerprint: String
    public let sourceRangeDigest: String
    public let modelDigest: String
    public let recipeDigest: String
    public let outputDigest: String

    public init(
        sourceFingerprint: String,
        sourceRangeDigest: String,
        modelDigest: String,
        recipeDigest: String,
        outputDigest: String
    ) throws {
        let values = [sourceFingerprint, sourceRangeDigest, modelDigest, recipeDigest, outputDigest]
        guard values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw AIError.invalidJobState("AI job identity values must not be empty.")
        }
        self.sourceFingerprint = sourceFingerprint
        self.sourceRangeDigest = sourceRangeDigest
        self.modelDigest = modelDigest
        self.recipeDigest = recipeDigest
        self.outputDigest = outputDigest
    }

    public var digest: String {
        let joined = [sourceFingerprint, sourceRangeDigest, modelDigest, recipeDigest, outputDigest]
            .joined(separator: "\u{1f}")
        return StableAISHA256.hexDigest(Data(joined.utf8))
    }
}

public struct AICacheKey: Codable, Equatable, Hashable, Sendable {
    public let jobDigest: String
    public let chunkIndex: Int

    public init(identity: AIJobIdentity, chunkIndex: Int) throws {
        guard chunkIndex >= 0 else { throw AIError.invalidJobState("Chunk index must be nonnegative.") }
        self.jobDigest = identity.digest
        self.chunkIndex = chunkIndex
    }

    public var stableFilename: String {
        "\(jobDigest)-chunk-\(String(format: "%08d", chunkIndex))"
    }
}
