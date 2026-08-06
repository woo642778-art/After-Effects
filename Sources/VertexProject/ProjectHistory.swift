import Foundation
import VertexCore

public struct ProjectHistorySnapshot: Codable, Equatable, Sendable {
    public var undo: [ProjectCommandRecord]
    public var redo: [ProjectCommandRecord]

    public init(undo: [ProjectCommandRecord] = [], redo: [ProjectCommandRecord] = []) {
        self.undo = undo
        self.redo = redo
    }
}

public final class ProjectHistoryController {
    public private(set) var project: ProjectDocument
    public let coalescingInterval: TimeInterval
    public let historyLimit: Int

    private var undoStack: [ProjectCommandRecord]
    private var redoStack: [ProjectCommandRecord]
    private let engine = ProjectCommandEngine()

    public init(
        project: ProjectDocument,
        snapshot: ProjectHistorySnapshot = ProjectHistorySnapshot(),
        coalescingInterval: TimeInterval = 0.5,
        historyLimit: Int = 200
    ) throws {
        guard coalescingInterval >= 0, coalescingInterval.isFinite else {
            throw ProjectError.invalidValue("Coalescing interval must be finite and non-negative.")
        }
        guard historyLimit > 0 else {
            throw ProjectError.invalidValue("History limit must be positive.")
        }
        self.project = try project.validated()
        self.coalescingInterval = coalescingInterval
        self.historyLimit = historyLimit
        self.undoStack = snapshot.undo
        self.redoStack = snapshot.redo
        trimHistories()
    }

    public var undoCount: Int { undoStack.count }
    public var redoCount: Int { redoStack.count }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var snapshot: ProjectHistorySnapshot { ProjectHistorySnapshot(undo: undoStack, redo: redoStack) }

    @discardableResult
    public func perform(
        _ operation: ProjectOperation,
        mergeKey: String? = nil,
        timestamp: Date = Date(),
        commandID: VertexID = VertexID()
    ) throws -> ProjectCommandRecord {
        let record = ProjectCommandRecord(
            project: project,
            commandID: commandID,
            operation: operation,
            mergeKey: mergeKey,
            timestamp: timestamp
        )
        try perform(record)
        return record
    }

    public func perform(_ record: ProjectCommandRecord) throws {
        project = try engine.apply(record, to: project)
        if let last = undoStack.last,
           let merged = coalesced(last, with: record) {
            undoStack[undoStack.count - 1] = merged
        } else {
            undoStack.append(record)
        }
        redoStack.removeAll(keepingCapacity: true)
        trimHistories()
    }

    @discardableResult
    public func undo(timestamp: Date = Date(), commandID: VertexID = VertexID()) throws -> ProjectCommandRecord {
        guard let original = undoStack.popLast() else {
            throw ProjectError.invalidOperation("There is no command to undo.")
        }
        let transition = ProjectCommandRecord(
            commandID: commandID,
            projectID: project.projectID,
            baseRevision: project.revision,
            timestamp: timestamp,
            mergeKey: nil,
            forwardOperation: original.inverseOperation,
            inverseOperation: original.forwardOperation
        )
        do {
            project = try engine.apply(transition, to: project)
            redoStack.append(original)
            trimHistories()
            return transition
        } catch {
            undoStack.append(original)
            throw error
        }
    }

    @discardableResult
    public func redo(timestamp: Date = Date(), commandID: VertexID = VertexID()) throws -> ProjectCommandRecord {
        guard let original = redoStack.popLast() else {
            throw ProjectError.invalidOperation("There is no command to redo.")
        }
        let transition = ProjectCommandRecord(
            commandID: commandID,
            projectID: project.projectID,
            baseRevision: project.revision,
            timestamp: timestamp,
            mergeKey: nil,
            forwardOperation: original.forwardOperation,
            inverseOperation: original.inverseOperation
        )
        do {
            project = try engine.apply(transition, to: project)
            undoStack.append(original)
            trimHistories()
            return transition
        } catch {
            redoStack.append(original)
            throw error
        }
    }

    private func coalesced(_ previous: ProjectCommandRecord, with current: ProjectCommandRecord) -> ProjectCommandRecord? {
        guard let previousKey = previous.mergeKey,
              previousKey == current.mergeKey,
              current.timestamp.timeIntervalSince(previous.timestamp) >= 0,
              current.timestamp.timeIntervalSince(previous.timestamp) <= coalescingInterval else {
            return nil
        }

        let mergedForward: ProjectOperation
        switch (previous.forwardOperation, current.forwardOperation) {
        case let (
            .setRenderParameter(previousParameter, previousBefore, previousAfter),
            .setRenderParameter(currentParameter, currentBefore, currentAfter)
        ) where previousParameter == currentParameter && previousAfter == currentBefore:
            mergedForward = .setRenderParameter(previousParameter, before: previousBefore, after: currentAfter)
        case let (
            .setRenderBoolean(previousParameter, previousBefore, previousAfter),
            .setRenderBoolean(currentParameter, currentBefore, currentAfter)
        ) where previousParameter == currentParameter && previousAfter == currentBefore:
            mergedForward = .setRenderBoolean(previousParameter, before: previousBefore, after: currentAfter)
        default:
            return nil
        }

        return ProjectCommandRecord(
            commandID: current.commandID,
            projectID: previous.projectID,
            baseRevision: previous.baseRevision,
            timestamp: current.timestamp,
            mergeKey: previousKey,
            forwardOperation: mergedForward,
            inverseOperation: mergedForward.inverse
        )
    }

    private func trimHistories() {
        if undoStack.count > historyLimit { undoStack.removeFirst(undoStack.count - historyLimit) }
        if redoStack.count > historyLimit { redoStack.removeFirst(redoStack.count - historyLimit) }
    }
}
