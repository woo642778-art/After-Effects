import Foundation
import VertexCore

public struct ProjectTransition: Equatable, Sendable, Identifiable {
    public let commandID: VertexID
    public let projectID: VertexID
    public let baseRevision: UInt64
    public let timestamp: Date
    public let mergeKey: String?
    public let forward: ProjectMutation
    public let inverse: ProjectMutation

    public var id: VertexID { commandID }

    public init(
        commandID: VertexID,
        projectID: VertexID,
        baseRevision: UInt64,
        timestamp: Date,
        mergeKey: String?,
        forward: ProjectMutation,
        inverse: ProjectMutation
    ) {
        self.commandID = commandID
        self.projectID = projectID
        self.baseRevision = baseRevision
        self.timestamp = timestamp
        self.mergeKey = mergeKey
        self.forward = forward
        self.inverse = inverse
    }
}
