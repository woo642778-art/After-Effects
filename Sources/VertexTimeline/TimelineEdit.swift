import Foundation
import VertexCore
import VertexProject

public enum TimelineEdge: String, Codable, CaseIterable, Sendable {
    case `in`
    case out
}

public enum TimelineEdit: Equatable, Sendable {
    case move(layerIDs: [VertexID], delta: RationalTime)
    case trimIn(layerID: VertexID, to: RationalTime)
    case trimOut(layerID: VertexID, to: RationalTime)
    case split(layerID: VertexID, at: RationalTime)
    case ripple(layerID: VertexID, edge: TimelineEdge, to: RationalTime, affectedLayerIDs: [VertexID])
    case rippleDelete(layerID: VertexID, affectedLayerIDs: [VertexID])
    case roll(leftLayerID: VertexID, rightLayerID: VertexID, boundary: RationalTime)
    case slip(layerID: VertexID, sourceDelta: RationalTime)
    case slide(layerID: VertexID, delta: RationalTime, previousLayerID: VertexID?, nextLayerID: VertexID?)
}

public struct TimelineEditResult: Equatable, Sendable {
    public var updatedLayers: [ProjectLayer]
    public var insertedLayers: [ProjectLayer]
    public var removedLayerIDs: [VertexID]
    public var resultingLayerOrder: [VertexID]

    public init(
        updatedLayers: [ProjectLayer],
        insertedLayers: [ProjectLayer] = [],
        removedLayerIDs: [VertexID] = [],
        resultingLayerOrder: [VertexID]
    ) {
        self.updatedLayers = updatedLayers
        self.insertedLayers = insertedLayers
        self.removedLayerIDs = removedLayerIDs
        self.resultingLayerOrder = resultingLayerOrder
    }
}
