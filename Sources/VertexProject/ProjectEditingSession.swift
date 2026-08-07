import Foundation
import VertexCore

public struct ProjectEditingSession: Sendable {
    public private(set) var loadedSnapshot: ProjectDocument
    public private(set) var document: ProjectDocument
    public private(set) var savedRevision: UInt64
    public private(set) var hasUnsavedChanges: Bool

    public let coalescingInterval: TimeInterval
    public let historyLimit: Int
    public let recentCommandLimit: Int

    private var undoStack: [ProjectTransition]
    private var redoStack: [ProjectTransition]
    private var recentCommandIDs: [VertexID]
    private var recentCommandIDSet: Set<VertexID>
    private let engine = ProjectCommandEngine()

    public init(
        document: ProjectDocument,
        coalescingInterval: TimeInterval = 0.5,
        historyLimit: Int = 200,
        recentCommandLimit: Int = 512
    ) throws {
        guard coalescingInterval >= 0, coalescingInterval.isFinite else {
            throw ProjectError.invalidValue("Coalescing interval must be finite and non-negative.")
        }
        guard historyLimit > 0 else {
            throw ProjectError.invalidValue("History limit must be positive.")
        }
        guard recentCommandLimit > 0 else {
            throw ProjectError.invalidValue("Recent command limit must be positive.")
        }
        let validated = try document.validated()
        self.loadedSnapshot = validated
        self.document = validated
        self.savedRevision = validated.revision
        self.hasUnsavedChanges = false
        self.coalescingInterval = coalescingInterval
        self.historyLimit = historyLimit
        self.recentCommandLimit = recentCommandLimit
        self.undoStack = []
        self.redoStack = []
        self.recentCommandIDs = []
        self.recentCommandIDSet = []
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var undoCount: Int { undoStack.count }
    public var redoCount: Int { redoStack.count }
    public var recentCommandCount: Int { recentCommandIDs.count }

    @discardableResult
    public mutating func apply(_ request: ProjectCommandRequest) throws -> ProjectTransition {
        try rejectDuplicate(request.commandID)
        let transition = try engine.prepare(request, for: document)
        let changed = try engine.apply(transition, to: document)

        if let previous = undoStack.last,
           let merged = coalesced(previous, with: transition) {
            undoStack[undoStack.count - 1] = merged
        } else {
            undoStack.append(transition)
        }
        trimHistory(&undoStack)
        redoStack.removeAll(keepingCapacity: true)
        document = changed
        hasUnsavedChanges = true
        registerRecent(request.commandID)
        return transition
    }

    @discardableResult
    public mutating func undo(
        commandID: VertexID = VertexID(),
        timestamp: Date = Date()
    ) throws -> ProjectTransition {
        try rejectDuplicate(commandID)
        guard let original = undoStack.last else {
            throw ProjectError.invalidOperation("There is no command to undo.")
        }
        let transition = ProjectTransition(
            commandID: commandID,
            projectID: document.projectID,
            baseRevision: document.revision,
            timestamp: timestamp,
            mergeKey: nil,
            forward: original.inverse,
            inverse: original.forward
        )
        let changed = try engine.apply(transition, to: document)
        _ = undoStack.popLast()
        redoStack.append(original)
        trimHistory(&redoStack)
        document = changed
        hasUnsavedChanges = true
        registerRecent(commandID)
        return transition
    }

    @discardableResult
    public mutating func redo(
        commandID: VertexID = VertexID(),
        timestamp: Date = Date()
    ) throws -> ProjectTransition {
        try rejectDuplicate(commandID)
        guard let original = redoStack.last else {
            throw ProjectError.invalidOperation("There is no command to redo.")
        }
        let transition = ProjectTransition(
            commandID: commandID,
            projectID: document.projectID,
            baseRevision: document.revision,
            timestamp: timestamp,
            mergeKey: nil,
            forward: original.forward,
            inverse: original.inverse
        )
        let changed = try engine.apply(transition, to: document)
        _ = redoStack.popLast()
        undoStack.append(original)
        trimHistory(&undoStack)
        document = changed
        hasUnsavedChanges = true
        registerRecent(commandID)
        return transition
    }

    public mutating func setSelectedMedia(
        _ mediaID: VertexID?,
        timestamp: Date = Date()
    ) throws {
        if let mediaID,
           !document.mediaRegistry.contains(where: { $0.id == mediaID }) {
            throw ProjectError.missingMedia(mediaID.rawValue)
        }
        guard document.selectedMediaID != mediaID else { return }
        guard document.revision < UInt64.max else {
            throw ProjectError.invalidRevision
        }
        var changed = document
        changed.selectedMediaID = mediaID
        changed.revision += 1
        changed.metadata.modifiedAt = timestamp
        changed.metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion
        document = try changed.validated()
        hasUnsavedChanges = true
    }

    public mutating func markSaved(revision: UInt64) throws {
        guard revision == document.revision else {
            throw ProjectError.staleBaseRevision(expected: revision, actual: document.revision)
        }
        savedRevision = revision
        hasUnsavedChanges = false
    }

    private func rejectDuplicate(_ commandID: VertexID) throws {
        guard !recentCommandIDSet.contains(commandID) else {
            throw ProjectError.duplicateCommand(commandID.rawValue)
        }
    }

    private mutating func registerRecent(_ commandID: VertexID) {
        recentCommandIDs.append(commandID)
        recentCommandIDSet.insert(commandID)
        if recentCommandIDs.count > recentCommandLimit {
            let overflow = recentCommandIDs.count - recentCommandLimit
            let removed = recentCommandIDs.prefix(overflow)
            recentCommandIDs.removeFirst(overflow)
            for id in removed {
                recentCommandIDSet.remove(id)
            }
        }
    }

    private func trimHistory(_ stack: inout [ProjectTransition]) {
        if stack.count > historyLimit {
            stack.removeFirst(stack.count - historyLimit)
        }
    }

    private func coalesced(
        _ previous: ProjectTransition,
        with current: ProjectTransition
    ) -> ProjectTransition? {
        guard let previousKey = previous.mergeKey,
              previousKey == current.mergeKey,
              previous.projectID == current.projectID,
              current.timestamp.timeIntervalSince(previous.timestamp) >= 0,
              current.timestamp.timeIntervalSince(previous.timestamp) <= coalescingInterval,
              let forward = merged(previous.forward, current.forward) else {
            return nil
        }
        return ProjectTransition(
            commandID: current.commandID,
            projectID: previous.projectID,
            baseRevision: previous.baseRevision,
            timestamp: current.timestamp,
            mergeKey: previousKey,
            forward: forward,
            inverse: forward.inverse
        )
    }

    private func merged(
        _ previous: ProjectMutation,
        _ current: ProjectMutation
    ) -> ProjectMutation? {
        switch (previous, current) {
        case let (
            .setRenderParameter(previousParameter, previousBefore, previousAfter),
            .setRenderParameter(currentParameter, currentBefore, currentAfter)
        ) where previousParameter == currentParameter && previousAfter == currentBefore:
            return .setRenderParameter(
                previousParameter,
                before: previousBefore,
                after: currentAfter
            )

        case let (
            .setRenderBoolean(previousParameter, previousBefore, previousAfter),
            .setRenderBoolean(currentParameter, currentBefore, currentAfter)
        ) where previousParameter == currentParameter && previousAfter == currentBefore:
            return .setRenderBoolean(
                previousParameter,
                before: previousBefore,
                after: currentAfter
            )

        case let (
            .setOutputDimensions(previousBeforeWidth, previousBeforeHeight, previousAfterWidth, previousAfterHeight),
            .setOutputDimensions(currentBeforeWidth, currentBeforeHeight, currentAfterWidth, currentAfterHeight)
        ) where previousAfterWidth == currentBeforeWidth && previousAfterHeight == currentBeforeHeight:
            return .setOutputDimensions(
                beforeWidth: previousBeforeWidth,
                beforeHeight: previousBeforeHeight,
                afterWidth: currentAfterWidth,
                afterHeight: currentAfterHeight
            )

        case let (
            .setProjectColor(previousBefore, previousAfter),
            .setProjectColor(currentBefore, currentAfter)
        ) where previousAfter == currentBefore:
            return .setProjectColor(before: previousBefore, after: currentAfter)

        default:
            return nil
        }
    }
}
