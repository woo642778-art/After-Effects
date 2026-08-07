import Foundation
import VertexCore

public struct ProjectCommandEngine: Sendable {
    public init() {}

    public func prepare(
        _ request: ProjectCommandRequest,
        for document: ProjectDocument
    ) throws -> ProjectTransition {
        guard request.projectID == document.projectID else {
            throw ProjectError.invalidProjectIdentity
        }
        guard request.baseRevision == document.revision else {
            throw ProjectError.staleBaseRevision(
                expected: request.baseRevision,
                actual: document.revision
            )
        }

        let forward: ProjectMutation
        switch request.payload {
        case .renameProject(let nextName):
            let normalized = nextName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                throw ProjectError.invalidValue("Project name must not be empty.")
            }
            guard normalized != document.metadata.name else {
                throw ProjectError.invalidOperation("Project name is already set to the requested value.")
            }
            forward = .renameProject(before: document.metadata.name, after: normalized)

        case .registerMedia(let reference):
            _ = try reference.validated()
            guard !document.mediaRegistry.contains(where: { $0.id == reference.id }) else {
                throw ProjectError.duplicateIdentity("media")
            }
            forward = .registerMedia(reference)

        case .removeMedia(let mediaID):
            guard let reference = document.mediaRegistry.first(where: { $0.id == mediaID }) else {
                throw ProjectError.missingMedia(mediaID.rawValue)
            }
            forward = .removeMedia(reference)

        case .relinkMedia(let mediaID, let nextLocator):
            guard let reference = document.mediaRegistry.first(where: { $0.id == mediaID }) else {
                throw ProjectError.missingMedia(mediaID.rawValue)
            }
            guard reference.locator != nextLocator else {
                throw ProjectError.invalidOperation("Media locator is already set to the requested value.")
            }
            forward = .relinkMedia(mediaID: mediaID, before: reference.locator, after: nextLocator)

        case .setEmbeddedPath(let mediaID, let nextPath):
            guard let reference = document.mediaRegistry.first(where: { $0.id == mediaID }) else {
                throw ProjectError.missingMedia(mediaID.rawValue)
            }
            guard reference.locator.embeddedPath != nextPath else {
                throw ProjectError.invalidOperation("Embedded path is already set to the requested value.")
            }
            forward = .setEmbeddedPath(
                mediaID: mediaID,
                before: reference.locator.embeddedPath,
                after: nextPath
            )

        case .setRenderParameter(let parameter, let nextValue):
            guard nextValue.isFinite else {
                throw ProjectError.invalidValue("Render parameters must be finite.")
            }
            let previous = document.renderSettings.value(for: parameter)
            guard previous != nextValue else {
                throw ProjectError.invalidOperation("Render parameter is already set to the requested value.")
            }
            var settings = document.renderSettings
            settings.set(nextValue, for: parameter)
            _ = try settings.validated()
            forward = .setRenderParameter(parameter, before: previous, after: nextValue)

        case .setRenderBoolean(let parameter, let nextValue):
            switch parameter {
            case .inverted:
                let previous = document.renderSettings.inverted
                guard previous != nextValue else {
                    throw ProjectError.invalidOperation("Render boolean is already set to the requested value.")
                }
                forward = .setRenderBoolean(parameter, before: previous, after: nextValue)
            }

        case .setOutputDimensions(let width, let height):
            var settings = document.renderSettings
            let previousWidth = settings.outputWidth
            let previousHeight = settings.outputHeight
            guard previousWidth != width || previousHeight != height else {
                throw ProjectError.invalidOperation("Output dimensions are already set to the requested values.")
            }
            settings.outputWidth = width
            settings.outputHeight = height
            _ = try settings.validated()
            forward = .setOutputDimensions(
                beforeWidth: previousWidth,
                beforeHeight: previousHeight,
                afterWidth: width,
                afterHeight: height
            )

        case .setProjectColor(let nextColor):
            let previous = document.settings.color
            guard previous != nextColor else {
                throw ProjectError.invalidOperation("Project color is already set to the requested value.")
            }
            forward = .setProjectColor(before: previous, after: nextColor)
        }

        return ProjectTransition(
            commandID: request.commandID,
            projectID: request.projectID,
            baseRevision: request.baseRevision,
            timestamp: request.timestamp,
            mergeKey: request.mergeKey,
            forward: forward,
            inverse: forward.inverse
        )
    }

    public func apply(
        _ transition: ProjectTransition,
        to document: ProjectDocument
    ) throws -> ProjectDocument {
        guard transition.projectID == document.projectID else {
            throw ProjectError.invalidProjectIdentity
        }
        guard transition.baseRevision == document.revision else {
            throw ProjectError.staleBaseRevision(
                expected: transition.baseRevision,
                actual: document.revision
            )
        }
        guard transition.inverse == transition.forward.inverse else {
            throw ProjectError.invalidInverseOperation("The transition inverse does not reverse the forward mutation.")
        }
        guard document.revision < UInt64.max else {
            throw ProjectError.invalidRevision
        }

        var changed = document
        try apply(transition.forward, to: &changed)
        changed.revision += 1
        changed.metadata.modifiedAt = transition.timestamp
        changed.metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion
        return try changed.validated()
    }

    public func apply(
        _ record: ProjectCommandRecord,
        to document: ProjectDocument
    ) throws -> ProjectDocument {
        let transition = ProjectTransition(
            commandID: record.commandID,
            projectID: record.projectID,
            baseRevision: record.baseRevision,
            timestamp: record.timestamp,
            mergeKey: record.mergeKey,
            forward: record.forwardOperation,
            inverse: record.inverseOperation
        )
        return try apply(transition, to: document)
    }

    private func apply(_ mutation: ProjectMutation, to document: inout ProjectDocument) throws {
        switch mutation {
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
            if document.selectedMediaID == reference.id {
                document.selectedMediaID = nil
            }

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
            if let after,
               !document.mediaRegistry.contains(where: { $0.id == after }) {
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

@available(*, deprecated, message: "Legacy WAL compatibility only; use ProjectCommandRequest and ProjectTransition.")
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
