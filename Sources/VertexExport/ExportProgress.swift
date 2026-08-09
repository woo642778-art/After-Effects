import Foundation

public struct ExportProgressSnapshot: Sendable, Equatable {
    public var completedFrames: Int64
    public var totalFrames: Int64

    public init(completedFrames: Int64, totalFrames: Int64) {
        self.completedFrames = max(0, completedFrames)
        self.totalFrames = max(0, totalFrames)
    }

    public var fractionCompleted: Double {
        guard totalFrames > 0 else { return 0 }
        return min(1, max(0, Double(completedFrames) / Double(totalFrames)))
    }
}

public actor ExportCancellationToken {
    private var cancelled = false
    public init() {}
    public func cancel() { cancelled = true }
    public func isCancelled() -> Bool { cancelled }
    public func throwIfCancelled() throws {
        if cancelled { throw CancellationError() }
    }
}
