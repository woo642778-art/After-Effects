import Foundation
import VertexCore

public struct ProjectPrecomposePlan: Codable, Equatable, Sendable {
    public let sourceLayerIDs: [VertexID]
    public let sourceLayers: [ProjectLayer]
    public let parentLayerOrderBefore: [VertexID]
    public let insertionIndex: Int
    public let childRegistryIndex: Int
    public let childComposition: ProjectComposition
    public let childLayers: [ProjectLayer]
    public let nestedLayer: ProjectLayer

    public init(
        sourceLayerIDs: [VertexID],
        sourceLayers: [ProjectLayer],
        parentLayerOrderBefore: [VertexID],
        insertionIndex: Int,
        childRegistryIndex: Int,
        childComposition: ProjectComposition,
        childLayers: [ProjectLayer],
        nestedLayer: ProjectLayer
    ) {
        self.sourceLayerIDs = sourceLayerIDs
        self.sourceLayers = sourceLayers
        self.parentLayerOrderBefore = parentLayerOrderBefore
        self.insertionIndex = insertionIndex
        self.childRegistryIndex = childRegistryIndex
        self.childComposition = childComposition
        self.childLayers = childLayers
        self.nestedLayer = nestedLayer
    }

    public var parentLayerOrderAfter: [VertexID] {
        let selected = Set(sourceLayerIDs)
        var result = parentLayerOrderBefore.filter { !selected.contains($0) }
        result.insert(nestedLayer.id, at: min(insertionIndex, result.count))
        return result
    }
}

public enum ProjectPrecomposePlanner {
    public static func plan(
        document: ProjectDocument,
        compositionID: VertexID,
        layerIDs: [VertexID],
        newCompositionID: VertexID = VertexID(),
        name: String
    ) throws -> ProjectPrecomposePlan {
        guard let parent = document.composition(id: compositionID) else {
            throw ProjectError.invalidValue("Pre-compose references a missing composition.")
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ProjectError.invalidValue("Pre-compose name must not be empty.")
        }
        guard document.composition(id: newCompositionID) == nil else {
            throw ProjectError.duplicateIdentity("pre-compose composition")
        }
        guard !layerIDs.isEmpty, Set(layerIDs).count == layerIDs.count else {
            throw ProjectError.invalidValue("Pre-compose requires one or more unique layers.")
        }

        let selected = Set(layerIDs)
        let orderedIDs = parent.layerIDs.filter(selected.contains)
        guard orderedIDs.count == layerIDs.count else {
            throw ProjectError.invalidValue("Every pre-compose layer must belong to the target composition.")
        }
        let orderedLayers = try orderedIDs.map { id -> ProjectLayer in
            guard let layer = document.layer(id: id), layer.compositionID == compositionID else {
                throw ProjectError.invalidValue("Pre-compose references a missing or foreign layer.")
            }
            guard !layer.locked else {
                throw ProjectError.invalidOperation("Unlock selected layers before pre-composing them.")
            }
            return layer
        }

        try validateBoundaryDependencies(layers: orderedLayers, selectedIDs: selected)

        guard let anchor = orderedLayers.map(\.timing.inPoint).min(),
              let parentOutPoint = orderedLayers.map(\.timing.outPoint).max() else {
            throw ProjectError.invalidOperation("Pre-compose could not resolve the selected time range.")
        }
        let childDuration = try parentOutPoint.subtracting(anchor)
        guard childDuration > .zero else {
            throw ProjectError.invalidValue("Pre-compose selection must span a positive duration.")
        }
        guard let insertionIndex = orderedIDs.compactMap({ parent.layerIDs.firstIndex(of: $0) }).min() else {
            throw ProjectError.invalidOperation("Pre-compose could not resolve the insertion index.")
        }

        var idMap: [VertexID: VertexID] = [:]
        for sourceID in orderedIDs {
            idMap[sourceID] = try DeterministicVertexID.derive(
                domain: "vertex.phase16.precompose.layer",
                components: [newCompositionID.rawValue, sourceID.rawValue]
            )
        }

        let childLayers = try orderedLayers.map { source -> ProjectLayer in
            guard let replacementID = idMap[source.id] else {
                throw ProjectError.invalidOperation("Pre-compose layer mapping is incomplete.")
            }
            var clone = source
            clone.id = replacementID
            clone.compositionID = newCompositionID
            clone.timing.startTime = try source.timing.startTime.subtracting(anchor)
            clone.timing.inPoint = try source.timing.inPoint.subtracting(anchor)
            clone.timing.outPoint = try source.timing.outPoint.subtracting(anchor)
            clone.timing.timeRemap = try shiftedTimeRemap(source.timing.timeRemap, by: anchor)
            clone.animationChannels = try shiftedAnimationChannels(source.animationChannels, by: anchor)
            clone.markers = try shiftedMarkers(source.markers, by: anchor)
            if let parentLayerID = source.parentLayerID {
                clone.parentLayerID = idMap[parentLayerID]
            }
            if var matte = source.trackMatte {
                guard let mappedMatteID = idMap[matte.sourceLayerID] else {
                    throw ProjectError.invalidOperation("Pre-compose track-matte mapping is incomplete.")
                }
                matte.sourceLayerID = mappedMatteID
                clone.trackMatte = matte
            }
            return clone
        }

        let childComposition = ProjectComposition(
            id: newCompositionID,
            name: trimmedName,
            width: parent.width,
            height: parent.height,
            duration: childDuration,
            frameRate: parent.frameRate,
            color: parent.color,
            backgroundColor: .transparent,
            layerIDs: childLayers.map(\.id),
            workArea: nil,
            markers: [],
            displayStartTime: .zero,
            pixelAspectRatio: parent.pixelAspectRatio,
            previewResolution: parent.previewResolution,
            bpm: parent.bpm,
            motionBlurShutterAngle: parent.motionBlurShutterAngle,
            motionBlurShutterPhase: parent.motionBlurShutterPhase,
            rendererMode: parent.rendererMode
        )

        let nestedLayerID = try DeterministicVertexID.derive(
            domain: "vertex.phase16.precompose.nested-layer",
            components: [compositionID.rawValue, newCompositionID.rawValue]
        )
        let nestedLayer = ProjectLayer(
            id: nestedLayerID,
            compositionID: compositionID,
            name: trimmedName,
            source: .composition(compositionID: newCompositionID, sourceStartTime: .zero),
            timing: LayerTiming(startTime: anchor, inPoint: anchor, outPoint: parentOutPoint)
        )

        _ = try childComposition.validated(layerByID: Dictionary(uniqueKeysWithValues: childLayers.map { ($0.id, $0) }))
        for layer in childLayers { _ = try layer.validated(composition: childComposition) }
        _ = try nestedLayer.validated(composition: parent)

        return ProjectPrecomposePlan(
            sourceLayerIDs: orderedIDs,
            sourceLayers: orderedLayers,
            parentLayerOrderBefore: parent.layerIDs,
            insertionIndex: insertionIndex,
            childRegistryIndex: document.compositionRegistry.count,
            childComposition: childComposition,
            childLayers: childLayers,
            nestedLayer: nestedLayer
        )
    }

    private static func validateBoundaryDependencies(layers: [ProjectLayer], selectedIDs: Set<VertexID>) throws {
        for layer in layers {
            if let parentLayerID = layer.parentLayerID, !selectedIDs.contains(parentLayerID) {
                throw ProjectError.invalidOperation("Pre-compose cannot move a layer whose parent remains outside the new composition.")
            }
            if let matteID = layer.trackMatte?.sourceLayerID, !selectedIDs.contains(matteID) {
                throw ProjectError.invalidOperation("Pre-compose cannot move a layer whose track matte remains outside the new composition.")
            }
        }
    }

    private static func shiftedAnimationChannels(_ channels: [ProjectAnimationChannel], by anchor: RationalTime) throws -> [ProjectAnimationChannel] {
        try channels.map { channel in
            var copy = channel
            copy.keyframes = try channel.keyframes.map { keyframe in
                var shifted = keyframe
                shifted.time = try keyframe.time.subtracting(anchor)
                guard shifted.time >= .zero else {
                    throw ProjectError.invalidOperation("Pre-compose cannot move animation keyframes before the selected in-point.")
                }
                return shifted
            }
            return copy
        }
    }

    private static func shiftedMarkers(_ markers: [ProjectMarker], by anchor: RationalTime) throws -> [ProjectMarker] {
        try markers.compactMap { marker in
            guard marker.time >= anchor else { return nil }
            var copy = marker
            copy.time = try marker.time.subtracting(anchor)
            return copy
        }
    }

    private static func shiftedTimeRemap(_ remap: ProjectTimeRemap?, by anchor: RationalTime) throws -> ProjectTimeRemap? {
        guard var remap else { return nil }
        remap.keyframes = try remap.keyframes.map { keyframe in
            var shifted = keyframe
            shifted.compositionTime = try keyframe.compositionTime.subtracting(anchor)
            guard shifted.compositionTime >= .zero else {
                throw ProjectError.invalidOperation("Pre-compose cannot move time-remap keyframes before the selected in-point.")
            }
            return shifted
        }
        return remap
    }
}
