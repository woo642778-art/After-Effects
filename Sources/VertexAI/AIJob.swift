import Foundation

public enum AIChunkState: String, Codable, Sendable {
    case pending
    case processing
    case completed
    case failed
}

public struct AIJobChunk: Codable, Equatable, Sendable, Identifiable {
    public var id: Int { index }
    public let index: Int
    public let startFrame: Int64
    public let endFrameExclusive: Int64
    public var state: AIChunkState
    public var artifactDigest: String?
    public var errorMessage: String?

    public init(
        index: Int,
        startFrame: Int64,
        endFrameExclusive: Int64,
        state: AIChunkState = .pending,
        artifactDigest: String? = nil,
        errorMessage: String? = nil
    ) throws {
        guard index >= 0, startFrame >= 0, endFrameExclusive > startFrame else {
            throw AIError.invalidJobState("AI chunk indices and frame ranges are invalid.")
        }
        self.index = index
        self.startFrame = startFrame
        self.endFrameExclusive = endFrameExclusive
        self.state = state
        self.artifactDigest = artifactDigest
        self.errorMessage = errorMessage
    }

    public func validated() throws -> Self {
        guard index >= 0, startFrame >= 0, endFrameExclusive > startFrame else {
            throw AIError.invalidJobState("AI chunk frame range is invalid.")
        }
        if state == .completed {
            guard let artifactDigest, artifactDigest.count == 64 else {
                throw AIError.invalidJobState("Completed chunks require a SHA-256 artifact digest.")
            }
        }
        return self
    }
}

public enum AIJobTerminalState: String, Codable, Sendable {
    case completed
    case cancelled
    case failed
}

public struct AIJob: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let identity: AIJobIdentity
    public let recipe: AITaskRecipe
    public let requestedTier: AIQualityTier
    public let effectiveTier: AIQualityTier
    public var fallbackReason: String?
    public var chunks: [AIJobChunk]
    public var terminalState: AIJobTerminalState?
    public var terminalMessage: String?

    public init(
        identity: AIJobIdentity,
        recipe: AITaskRecipe,
        requestedTier: AIQualityTier,
        effectiveTier: AIQualityTier,
        fallbackReason: String? = nil,
        chunks: [AIJobChunk]
    ) throws {
        _ = try recipe.validated()
        guard !chunks.isEmpty else { throw AIError.invalidJobState("AI jobs require at least one chunk.") }
        let sorted = chunks.sorted { $0.index < $1.index }
        guard sorted.map(\.index) == Array(0..<sorted.count) else {
            throw AIError.invalidJobState("AI chunks must use contiguous zero-based indices.")
        }
        for chunk in sorted { _ = try chunk.validated() }
        self.id = identity.digest
        self.identity = identity
        self.recipe = recipe
        self.requestedTier = requestedTier
        self.effectiveTier = effectiveTier
        self.fallbackReason = fallbackReason
        self.chunks = sorted
        self.terminalState = nil
        self.terminalMessage = nil
    }

    public var completedChunkCount: Int {
        chunks.count(where: { $0.state == .completed })
    }

    public var progress: Double {
        guard !chunks.isEmpty else { return 0 }
        return Double(completedChunkCount) / Double(chunks.count)
    }

    public var nextPendingChunk: AIJobChunk? {
        guard terminalState == nil else { return nil }
        return chunks.first(where: { $0.state == .pending || $0.state == .failed })
    }

    public mutating func beginChunk(index: Int) throws {
        guard terminalState == nil else { throw AIError.invalidJobState("Terminal AI jobs cannot begin more chunks.") }
        guard chunks.indices.contains(index), chunks[index].state == .pending || chunks[index].state == .failed else {
            throw AIError.invalidJobState("Only pending or failed chunks can begin processing.")
        }
        chunks[index].state = .processing
        chunks[index].errorMessage = nil
    }

    public mutating func completeChunk(index: Int, artifactDigest: String) throws {
        guard terminalState == nil, chunks.indices.contains(index), chunks[index].state == .processing else {
            throw AIError.invalidJobState("Only a processing chunk can complete.")
        }
        guard artifactDigest.count == 64 else {
            throw AIError.invalidJobState("Completed chunk digest must be SHA-256.")
        }
        chunks[index].artifactDigest = artifactDigest
        chunks[index].state = .completed
        chunks[index].errorMessage = nil
        if chunks.allSatisfy({ $0.state == .completed }) {
            terminalState = .completed
        }
    }

    public mutating func failChunk(index: Int, message: String) throws {
        guard terminalState == nil, chunks.indices.contains(index), chunks[index].state == .processing else {
            throw AIError.invalidJobState("Only a processing chunk can fail.")
        }
        chunks[index].state = .failed
        chunks[index].artifactDigest = nil
        chunks[index].errorMessage = message
    }

    public mutating func invalidateChunk(index: Int) throws {
        guard chunks.indices.contains(index), chunks[index].state == .completed else {
            throw AIError.invalidJobState("Only a completed chunk can be invalidated.")
        }
        chunks[index].state = .pending
        chunks[index].artifactDigest = nil
        chunks[index].errorMessage = nil
        if terminalState == .completed {
            terminalState = nil
            terminalMessage = nil
        }
    }

    public mutating func cancel() {
        guard terminalState == nil else { return }
        for index in chunks.indices where chunks[index].state == .processing {
            chunks[index].state = .pending
            chunks[index].artifactDigest = nil
            chunks[index].errorMessage = nil
        }
        terminalState = .cancelled
        terminalMessage = "Cancelled by user. Verified completed chunks were preserved."
    }

    public func resumeCandidate(for identity: AIJobIdentity) throws -> AIJob {
        guard identity == self.identity else {
            throw AIError.invalidJobState("Stored AI job identity does not match the requested source/model/recipe/output identity.")
        }
        var copy = self
        if copy.terminalState == .cancelled || copy.terminalState == .failed {
            copy.terminalState = nil
            copy.terminalMessage = nil
        }
        for index in copy.chunks.indices where copy.chunks[index].state == .processing {
            copy.chunks[index].state = .pending
            copy.chunks[index].artifactDigest = nil
        }
        return copy
    }
}
