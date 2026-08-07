import Foundation
import VertexCore

public struct ProjectMarker: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var time: RationalTime
    public var name: String
    public var comment: String

    public init(
        id: VertexID = VertexID(),
        time: RationalTime,
        name: String,
        comment: String = ""
    ) {
        self.id = id
        self.time = time
        self.name = name
        self.comment = comment
    }

    public func validated(compositionDuration: RationalTime) throws -> Self {
        guard time >= .zero, time < compositionDuration else {
            throw ProjectError.invalidValue("Marker time must satisfy 0 <= time < composition duration.")
        }
        return self
    }
}

public struct ProjectWorkArea: Codable, Equatable, Sendable {
    public var start: RationalTime
    public var end: RationalTime

    public init(start: RationalTime, end: RationalTime) {
        self.start = start
        self.end = end
    }

    public func validated(compositionDuration: RationalTime) throws -> Self {
        guard start >= .zero, start < end, end <= compositionDuration else {
            throw ProjectError.invalidValue("Work area must satisfy 0 <= start < end <= composition duration.")
        }
        return self
    }
}


public struct TimelineProjectMutation: Codable, Equatable, Sendable {
    public var beforeLayers: [ProjectLayer]
    public var afterLayers: [ProjectLayer]
    public var beforeLayerOrder: [VertexID]
    public var afterLayerOrder: [VertexID]
    public var beforeSelectedLayerID: VertexID?
    public var afterSelectedLayerID: VertexID?

    public init(
        beforeLayers: [ProjectLayer],
        afterLayers: [ProjectLayer],
        beforeLayerOrder: [VertexID],
        afterLayerOrder: [VertexID],
        beforeSelectedLayerID: VertexID?,
        afterSelectedLayerID: VertexID?
    ) {
        self.beforeLayers = beforeLayers
        self.afterLayers = afterLayers
        self.beforeLayerOrder = beforeLayerOrder
        self.afterLayerOrder = afterLayerOrder
        self.beforeSelectedLayerID = beforeSelectedLayerID
        self.afterSelectedLayerID = afterSelectedLayerID
    }

    public var inverse: Self {
        Self(
            beforeLayers: afterLayers,
            afterLayers: beforeLayers,
            beforeLayerOrder: afterLayerOrder,
            afterLayerOrder: beforeLayerOrder,
            beforeSelectedLayerID: afterSelectedLayerID,
            afterSelectedLayerID: beforeSelectedLayerID
        )
    }

    public func validated(compositionID: VertexID) throws -> Self {
        try validateSide(layers: beforeLayers, order: beforeLayerOrder, selected: beforeSelectedLayerID, compositionID: compositionID)
        try validateSide(layers: afterLayers, order: afterLayerOrder, selected: afterSelectedLayerID, compositionID: compositionID)
        return self
    }

    private func validateSide(
        layers: [ProjectLayer],
        order: [VertexID],
        selected: VertexID?,
        compositionID: VertexID
    ) throws {
        guard Set(layers.map(\.id)).count == layers.count, Set(order).count == order.count else {
            throw ProjectError.duplicateIdentity("timeline mutation layer")
        }
        guard layers.allSatisfy({ $0.compositionID == compositionID }) else {
            throw ProjectError.invalidValue("Timeline mutation layers must belong to one composition.")
        }
        let layerIDs = Set(layers.map(\.id))
        guard layerIDs == Set(order), layers.count == order.count else {
            throw ProjectError.invalidValue("Timeline mutation layer order must contain exactly its layer snapshot identities.")
        }
        if let selected, !layerIDs.contains(selected) {
            throw ProjectError.invalidValue("Timeline mutation selected layer must belong to its snapshot.")
        }
    }
}
