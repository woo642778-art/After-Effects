import Foundation
import VertexCore

public struct TimelineSelection: Equatable, Sendable {
    public private(set) var layerIDs: Set<VertexID>
    public private(set) var keyframeIDs: Set<VertexID>

    public init(layerIDs: [VertexID] = [], keyframeIDs: [VertexID] = []) {
        self.layerIDs = Set(layerIDs)
        self.keyframeIDs = Set(keyframeIDs)
    }

    public var orderedLayerIDs: [VertexID] {
        layerIDs.sorted { $0.rawValue < $1.rawValue }
    }

    public var orderedKeyframeIDs: [VertexID] {
        keyframeIDs.sorted { $0.rawValue < $1.rawValue }
    }

    public mutating func selectLayer(_ id: VertexID, additive: Bool) {
        if !additive { layerIDs.removeAll(keepingCapacity: true) }
        layerIDs.insert(id)
    }

    public mutating func selectKeyframe(_ id: VertexID, additive: Bool) {
        if !additive { keyframeIDs.removeAll(keepingCapacity: true) }
        keyframeIDs.insert(id)
    }

    public mutating func toggleLayer(_ id: VertexID) {
        if layerIDs.remove(id) == nil { layerIDs.insert(id) }
    }

    public mutating func toggleKeyframe(_ id: VertexID) {
        if keyframeIDs.remove(id) == nil { keyframeIDs.insert(id) }
    }

    public mutating func replaceLayers(_ ids: [VertexID]) {
        layerIDs = Set(ids)
    }

    public mutating func replaceKeyframes(_ ids: [VertexID]) {
        keyframeIDs = Set(ids)
    }

    public mutating func clearLayers() {
        layerIDs.removeAll(keepingCapacity: true)
    }

    public mutating func clearKeyframes() {
        keyframeIDs.removeAll(keepingCapacity: true)
    }

    public mutating func clearAll() {
        clearLayers()
        clearKeyframes()
    }
}
