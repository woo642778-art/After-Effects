import Foundation
import VertexCore

public enum ProjectOperation: Codable, Equatable, Sendable {
    case renameProject(before: String, after: String)
    case registerMedia(MediaReference)
    case removeMedia(MediaReference)
    case relinkMedia(mediaID: VertexID, before: MediaLocator, after: MediaLocator)
    case setEmbeddedPath(mediaID: VertexID, before: String?, after: String?)
    case selectMedia(before: VertexID?, after: VertexID?)
    case setRenderParameter(ProjectRenderParameter, before: Double, after: Double)
    case setRenderBoolean(ProjectRenderBooleanParameter, before: Bool, after: Bool)
    case setOutputDimensions(beforeWidth: Int, beforeHeight: Int, afterWidth: Int, afterHeight: Int)
    case setProjectColor(before: ColorDescriptor, after: ColorDescriptor)

    public var inverse: ProjectOperation {
        switch self {
        case .renameProject(let before, let after):
            .renameProject(before: after, after: before)
        case .registerMedia(let reference):
            .removeMedia(reference)
        case .removeMedia(let reference):
            .registerMedia(reference)
        case .relinkMedia(let mediaID, let before, let after):
            .relinkMedia(mediaID: mediaID, before: after, after: before)
        case .setEmbeddedPath(let mediaID, let before, let after):
            .setEmbeddedPath(mediaID: mediaID, before: after, after: before)
        case .selectMedia(let before, let after):
            .selectMedia(before: after, after: before)
        case .setRenderParameter(let parameter, let before, let after):
            .setRenderParameter(parameter, before: after, after: before)
        case .setRenderBoolean(let parameter, let before, let after):
            .setRenderBoolean(parameter, before: after, after: before)
        case .setOutputDimensions(let beforeWidth, let beforeHeight, let afterWidth, let afterHeight):
            .setOutputDimensions(beforeWidth: afterWidth, beforeHeight: afterHeight, afterWidth: beforeWidth, afterHeight: beforeHeight)
        case .setProjectColor(let before, let after):
            .setProjectColor(before: after, after: before)
        }
    }
}

public struct ProjectCommandRecord: Codable, Equatable, Sendable, Identifiable {
    public var commandID: VertexID
    public var projectID: VertexID
    public var baseRevision: UInt64
    public var timestamp: Date
    public var mergeKey: String?
    public var forwardOperation: ProjectOperation
    public var inverseOperation: ProjectOperation

    public var id: VertexID { commandID }

    public init(
        commandID: VertexID = VertexID(),
        projectID: VertexID,
        baseRevision: UInt64,
        timestamp: Date = Date(),
        mergeKey: String? = nil,
        forwardOperation: ProjectOperation,
        inverseOperation: ProjectOperation
    ) {
        self.commandID = commandID
        self.projectID = projectID
        self.baseRevision = baseRevision
        self.timestamp = timestamp
        self.mergeKey = mergeKey
        self.forwardOperation = forwardOperation
        self.inverseOperation = inverseOperation
    }

    public init(
        project: ProjectDocument,
        commandID: VertexID = VertexID(),
        operation: ProjectOperation,
        mergeKey: String? = nil,
        timestamp: Date = Date()
    ) {
        self.init(
            commandID: commandID,
            projectID: project.projectID,
            baseRevision: project.revision,
            timestamp: timestamp,
            mergeKey: mergeKey,
            forwardOperation: operation,
            inverseOperation: operation.inverse
        )
    }

    public static func settingExposure(
        project: ProjectDocument,
        commandID: VertexID = VertexID(),
        from: Double,
        to: Double,
        timestamp: Date = Date()
    ) -> ProjectCommandRecord {
        ProjectCommandRecord(
            project: project,
            commandID: commandID,
            operation: .setRenderParameter(.exposure, before: from, after: to),
            mergeKey: "render.exposure",
            timestamp: timestamp
        )
    }
}

public struct ProjectCommandEngine: Sendable {
    public init() {}

    public func apply(_ record: ProjectCommandRecord, to document: ProjectDocument) throws -> ProjectDocument {
        guard record.projectID == document.projectID else {
            throw ProjectError.invalidProjectIdentity
        }
        guard record.baseRevision == document.revision else {
            throw ProjectError.staleBaseRevision(expected: record.baseRevision, actual: document.revision)
        }
        guard !document.appliedCommandIDs.contains(record.commandID) else {
            throw ProjectError.duplicateCommand(record.commandID.rawValue)
        }
        guard record.inverseOperation == record.forwardOperation.inverse else {
            throw ProjectError.invalidInverseOperation("The command inverse does not reverse the forward operation.")
        }
        guard document.revision < UInt64.max else {
            throw ProjectError.invalidRevision
        }

        var changed = document
        try apply(record.forwardOperation, to: &changed)
        changed.revision += 1
        changed.metadata.modifiedAt = record.timestamp
        changed.metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion
        changed.appliedCommandIDs.append(record.commandID)
        if changed.appliedCommandIDs.count > 1_000 {
            changed.appliedCommandIDs.removeFirst(changed.appliedCommandIDs.count - 1_000)
        }
        return try changed.validated()
    }

    private func apply(_ operation: ProjectOperation, to document: inout ProjectDocument) throws {
        switch operation {
        case .renameProject(let before, let after):
            guard document.metadata.name == before else {
                throw ProjectError.invalidOperation("Project name precondition did not match.")
            }
            guard !after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ProjectError.invalidValue("Project name must not be empty.")
            }
            document.metadata.name = after

        case .registerMedia(let reference):
            _ = try reference.validated()
            guard !document.mediaRegistry.contains(where: { $0.id == reference.id }) else {
                throw ProjectError.duplicateIdentity("media")
            }
            document.mediaRegistry.append(reference)

        case .removeMedia(let reference):
            guard let index = document.mediaRegistry.firstIndex(of: reference) else {
                throw ProjectError.invalidOperation("The media reference to remove does not match project state.")
            }
            document.mediaRegistry.remove(at: index)
            if document.selectedMediaID == reference.id { document.selectedMediaID = nil }

        case .relinkMedia(let mediaID, let before, let after):
            guard let index = document.mediaRegistry.firstIndex(where: { $0.id == mediaID }) else {
                throw ProjectError.missingMedia(mediaID.rawValue)
            }
            guard document.mediaRegistry[index].locator == before else {
                throw ProjectError.invalidOperation("Media locator precondition did not match.")
            }
            document.mediaRegistry[index].locator = after
            document.mediaRegistry[index].availabilityStatus = after.embeddedPath == nil ? .external : .embedded

        case .setEmbeddedPath(let mediaID, let before, let after):
            guard let index = document.mediaRegistry.firstIndex(where: { $0.id == mediaID }) else {
                throw ProjectError.missingMedia(mediaID.rawValue)
            }
            guard document.mediaRegistry[index].locator.embeddedPath == before else {
                throw ProjectError.invalidOperation("Embedded-path precondition did not match.")
            }
            document.mediaRegistry[index].locator.embeddedPath = after
            document.mediaRegistry[index].availabilityStatus = after == nil ? .external : .embedded

        case .selectMedia(let before, let after):
            guard document.selectedMediaID == before else {
                throw ProjectError.invalidOperation("Selected-media precondition did not match.")
            }
            if let after, !document.mediaRegistry.contains(where: { $0.id == after }) {
                throw ProjectError.missingMedia(after.rawValue)
            }
            document.selectedMediaID = after

        case .setRenderParameter(let parameter, let before, let after):
            guard before.isFinite, after.isFinite else {
                throw ProjectError.invalidValue("Render parameters must be finite.")
            }
            guard document.renderSettings.value(for: parameter) == before else {
                throw ProjectError.invalidOperation("Render-parameter precondition did not match.")
            }
            document.renderSettings.set(after, for: parameter)
            _ = try document.renderSettings.validated()

        case .setRenderBoolean(let parameter, let before, let after):
            switch parameter {
            case .inverted:
                guard document.renderSettings.inverted == before else {
                    throw ProjectError.invalidOperation("Render-boolean precondition did not match.")
                }
                document.renderSettings.inverted = after
            }

        case .setOutputDimensions(let beforeWidth, let beforeHeight, let afterWidth, let afterHeight):
            guard document.renderSettings.outputWidth == beforeWidth,
                  document.renderSettings.outputHeight == beforeHeight else {
                throw ProjectError.invalidOperation("Output-dimension precondition did not match.")
            }
            document.renderSettings.outputWidth = afterWidth
            document.renderSettings.outputHeight = afterHeight
            _ = try document.renderSettings.validated()

        case .setProjectColor(let before, let after):
            guard document.settings.color == before else {
                throw ProjectError.invalidOperation("Project-color precondition did not match.")
            }
            document.settings.color = after
        }
    }
}
