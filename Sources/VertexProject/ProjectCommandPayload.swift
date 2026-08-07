import Foundation
import VertexCore

public enum ProjectCommandPayload: Equatable, Sendable {
    case renameProject(to: String)
    case registerMedia(MediaReference)
    case removeMedia(id: VertexID)
    case relinkMedia(id: VertexID, locator: MediaLocator)
    case setEmbeddedPath(id: VertexID, path: String?)

    // Transitional non-persistent Render Lab compatibility while the Phase 6
    // workspace is being reconnected. These mutate actual composition/layer
    // state through ProjectDocument.renderSettings and are removed from UI use
    // by the end of Phase 6 reintegration.
    case setRenderParameter(ProjectRenderParameter, value: Double)
    case setRenderBoolean(ProjectRenderBooleanParameter, value: Bool)
    case setOutputDimensions(width: Int, height: Int)
    case setProjectColor(ColorDescriptor)

    case insertComposition(ProjectComposition, ownedLayers: [ProjectLayer], index: Int)
    case removeComposition(id: VertexID)
    case renameComposition(id: VertexID, to: String)
    case setCompositionDimensions(id: VertexID, width: Int, height: Int)
    case setCompositionDuration(id: VertexID, duration: RationalTime)
    case setCompositionFrameRate(id: VertexID, frameRate: RationalTime)
    case setCompositionBackground(id: VertexID, color: ProjectRGBAColor)

    case insertLayer(ProjectLayer, index: Int)
    case removeLayer(id: VertexID)
    case reorderLayer(id: VertexID, toIndex: Int)
    case renameLayer(id: VertexID, to: String)
    case setLayerEnabled(id: VertexID, value: Bool)
    case setLayerLocked(id: VertexID, value: Bool)
    case setLayerSolo(id: VertexID, value: Bool)
    case setLayerTiming(id: VertexID, timing: LayerTiming)
    case setLayerTransform(id: VertexID, transform: LayerTransform)
    case setLayerBlendMode(id: VertexID, mode: LayerBlendMode)
    case setLayerSource(id: VertexID, source: LayerSource)
    case setLayerOperations(id: VertexID, operations: [LayerOperation])
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
