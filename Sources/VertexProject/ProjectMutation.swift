import VertexCore

public enum ProjectMutation: Codable, Equatable, Sendable {
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

    public var inverse: ProjectMutation {
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
            .setOutputDimensions(
                beforeWidth: afterWidth,
                beforeHeight: afterHeight,
                afterWidth: beforeWidth,
                afterHeight: beforeHeight
            )
        case .setProjectColor(let before, let after):
            .setProjectColor(before: after, after: before)
        }
    }
}

@available(*, deprecated, renamed: "ProjectMutation")
public typealias ProjectOperation = ProjectMutation
