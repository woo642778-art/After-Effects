import Foundation
import VertexCore

@available(*, deprecated, message: "Legacy .aeproject fixtures only; new edits use ProjectCommandRequest.")
public extension ProjectCommandRecord {
    init(
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

    static func settingExposure(
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
