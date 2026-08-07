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

    case createComposition(ProjectComposition, ownedLayers: [ProjectLayer], index: Int)
    case removeComposition(id: VertexID)
    case duplicateComposition(sourceID: VertexID, newCompositionID: VertexID, newLayerIDs: [VertexID])
    case renameComposition(id: VertexID, to: String)
    case setCompositionDimensions(id: VertexID, width: Int, height: Int)
    case setCompositionDuration(id: VertexID, duration: RationalTime)
    case setCompositionFrameRate(id: VertexID, frameRate: RationalTime)
    case setCompositionBackground(id: VertexID, color: ProjectRGBAColor)

    case insertLayer(ProjectLayer, compositionID: VertexID, index: Int)
    case removeLayer(id: VertexID)
    case duplicateLayer(sourceID: VertexID, duplicateID: VertexID, index: Int)
    case renameLayer(id: VertexID, to: String)
    case reorderLayer(compositionID: VertexID, layerID: VertexID, toIndex: Int)
    case setLayerEnabled(id: VertexID, value: Bool)
    case setLayerLocked(id: VertexID, value: Bool)
    case setLayerSolo(id: VertexID, value: Bool)
    case setLayerTiming(id: VertexID, value: LayerTiming)
    case setLayerTransform(id: VertexID, value: LayerTransform)
    case setLayerBlendMode(id: VertexID, value: LayerBlendMode)
    case setLayerSource(id: VertexID, value: LayerSource)
    case setLayerOperations(id: VertexID, value: [LayerOperation])
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
