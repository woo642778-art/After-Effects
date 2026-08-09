import Foundation

public enum ExportQueueState: Sendable, Equatable {
    case queued
    case running(progress: Double)
    case completed(URL)
    case failed(String)
    case cancelled
}

public struct ExportQueueItem: Sendable, Equatable, Identifiable {
    public var job: ExportJob
    public var state: ExportQueueState
    public var id: UUID { job.id }
    public init(job: ExportJob, state: ExportQueueState = .queued) { self.job = job; self.state = state }
}

public actor ExportJobQueue {
    private var order: [UUID] = []
    private var items: [UUID: ExportQueueItem] = [:]

    public init() {}

    public func enqueue(_ job: ExportJob) throws {
        _ = try job.validated()
        guard items[job.id] == nil else { throw ExportValidationError.duplicateJobID }
        order.append(job.id)
        items[job.id] = ExportQueueItem(job: job)
    }

    public func nextQueued() -> ExportQueueItem? {
        order.compactMap { items[$0] }.first { $0.state == .queued }
    }

    public func markRunning(_ id: UUID, progress: Double) {
        guard var item = items[id] else { return }
        item.state = .running(progress: min(max(progress, 0), 1))
        items[id] = item
    }

    public func markCompleted(_ id: UUID, outputURL: URL) {
        guard var item = items[id] else { return }
        item.state = .completed(outputURL)
        items[id] = item
    }

    public func markFailed(_ id: UUID, message: String) {
        guard var item = items[id] else { return }
        item.state = .failed(message)
        items[id] = item
    }

    public func cancel(_ id: UUID) {
        guard var item = items[id] else { return }
        item.state = .cancelled
        items[id] = item
    }

    public func snapshot() -> [ExportQueueItem] { order.compactMap { items[$0] } }
}
