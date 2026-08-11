import Foundation

/// Small deterministic gate used by continuous effect controls so dragging a slider
/// does not enqueue a full project mutation and preview render for every touch sample.
/// The final value is always committed explicitly when editing ends.
public struct EffectPreviewUpdateGate: Sendable {
    public let minimumInterval: TimeInterval
    private var lastCommitTime: TimeInterval?

    public init(minimumInterval: TimeInterval = 1.0 / 24.0) {
        precondition(minimumInterval >= 0)
        self.minimumInterval = minimumInterval
    }

    public mutating func shouldCommit(at time: TimeInterval) -> Bool {
        guard time.isFinite else { return false }
        guard let lastCommitTime else {
            self.lastCommitTime = time
            return true
        }
        guard time - lastCommitTime >= minimumInterval else { return false }
        self.lastCommitTime = time
        return true
    }

    @discardableResult
    public mutating func shouldCommitFinal(at time: TimeInterval) -> Bool {
        if time.isFinite { lastCommitTime = time }
        return true
    }
}
