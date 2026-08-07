import Foundation
import VertexCore

public enum ProjectCommandPayload: Equatable, Sendable {
    case renameProject(to: String)
    case registerMedia(MediaReference)
    case removeMedia(id: VertexID)
    case relinkMedia(id: VertexID, locator: MediaLocator)
    case setEmbeddedPath(id: VertexID, path: String?)
    case setRenderParameter(ProjectRenderParameter, value: Double)
    case setRenderBoolean(ProjectRenderBooleanParameter, value: Bool)
    case setOutputDimensions(width: Int, height: Int)
    case setProjectColor(ColorDescriptor)
}

public struct ProjectCommandRequest: Equatable, Sendable, Identifiable {
    public let commandID: VertexID
    public let projectID: VertexID
    public let baseRevision: UInt64
    public let timestamp: Date
    public let mergeKey: String?
    public let payload: ProjectCommandPayload

    public var id: VertexID { commandID }

    public init(
        commandID: VertexID = VertexID(),
        projectID: VertexID,
        baseRevision: UInt64,
        timestamp: Date = Date(),
        mergeKey: String? = nil,
        payload: ProjectCommandPayload
    ) {
        self.commandID = commandID
        self.projectID = projectID
        self.baseRevision = baseRevision
        self.timestamp = timestamp
        self.mergeKey = mergeKey
        self.payload = payload
    }
}
