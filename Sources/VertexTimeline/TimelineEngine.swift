import Foundation
import VertexCore
import VertexProject

public struct TimelineEngine: Sendable {
    public init() {}

    public func apply(
        _ edit: TimelineEdit,
        to project: ProjectDocument,
        compositionID: VertexID
    ) throws -> TimelineEditResult {
        let project = try project.validated()
        guard let composition = project.composition(id: compositionID) else {
            throw ProjectError.invalidOperation("Timeline edit references a missing composition.")
        }
        let layerByID = Dictionary(uniqueKeysWithValues: project.layers(in: compositionID).map { ($0.id, $0) })
        var updates: [VertexID: ProjectLayer] = [:]
        var inserted: [ProjectLayer] = []
        var order = composition.layerIDs

        func sourceLayer(_ id: VertexID) throws -> ProjectLayer {
            guard let layer = layerByID[id], layer.compositionID == compositionID else {
                throw ProjectError.invalidOperation("Timeline edit references a missing layer in the active composition.")
            }
            guard !layer.locked else {
                throw ProjectError.invalidOperation("Locked layers cannot be edited on the timeline.")
            }
            return layer
        }

        func current(_ id: VertexID) throws -> ProjectLayer {
            if let updated = updates[id] { return updated }
            return try sourceLayer(id)
        }

        func store(_ layer: ProjectLayer) throws {
            _ = try layer.timing.validated(for: composition)
            updates[layer.id] = layer
        }

        switch edit {
        case .move(let layerIDs, let delta):
            guard !layerIDs.isEmpty, Set(layerIDs).count == layerIDs.count else {
                throw ProjectError.invalidOperation("Move requires a nonempty set of unique layer IDs.")
            }
            for id in layerIDs {
                let layer = try shiftedLayer(try current(id), by: delta, composition: composition)
                try store(layer)
            }

        case .trimIn(let layerID, let time):
            var layer = try current(layerID)
            layer.timing.inPoint = time
            try store(layer)

        case .trimOut(let layerID, let time):
            var layer = try current(layerID)
            layer.timing.outPoint = time
            try store(layer)

        case .split(let layerID, let splitTime):
            var left = try current(layerID)
            guard splitTime > left.timing.inPoint, splitTime < left.timing.outPoint else {
                throw ProjectError.invalidOperation("Split time must lie strictly inside the layer in/out interval.")
            }
            guard isSourceBacked(left.source) else {
                throw ProjectError.invalidOperation("Only media or nested-composition layers can be split.")
            }
            let sourceAdvance = try subtract(splitTime, left.timing.startTime)
            let rightSourceOffset = try add(left.timing.sourceOffset, sourceAdvance)
            guard rightSourceOffset >= .zero else {
                throw ProjectError.invalidOperation("Split would produce a negative source offset.")
            }

            let splitChannels = try partitionAnimationChannels(left.animationChannels, at: splitTime)
            left.timing.outPoint = splitTime
            left.animationChannels = splitChannels.left
            try store(left)

            var right = try sourceLayer(layerID)
            right.id = try DeterministicVertexID.derive(
                domain: "vertex.phase9.timeline.split",
                components: [
                    project.projectID.rawValue,
                    compositionID.rawValue,
                    layerID.rawValue,
                    splitTime.description
                ]
            )
            guard layerByID[right.id] == nil else {
                throw ProjectError.duplicateIdentity("split layer")
            }
            right.timing.startTime = splitTime
            right.timing.inPoint = splitTime
            right.timing.sourceOffset = rightSourceOffset
            right.animationChannels = splitChannels.right
            _ = try right.timing.validated(for: composition)
            inserted = [right]
            guard let index = order.firstIndex(of: layerID) else {
                throw ProjectError.invalidOperation("Composition layer order is inconsistent.")
            }
            order.insert(right.id, at: index + 1)

        case .ripple(let layerID, let edge, let time, let affectedLayerIDs):
            guard Set(affectedLayerIDs).count == affectedLayerIDs.count,
                  !affectedLayerIDs.contains(layerID) else {
                throw ProjectError.invalidOperation("Ripple scope must contain unique IDs and exclude the edited layer.")
            }
            var target = try current(layerID)
            let oldBoundary: RationalTime
            switch edge {
            case .in:
                oldBoundary = target.timing.inPoint
                target.timing.inPoint = time
            case .out:
                oldBoundary = target.timing.outPoint
                target.timing.outPoint = time
            }
            try store(target)
            let delta = try subtract(time, oldBoundary)
            for id in affectedLayerIDs {
                let layer = try shiftedLayer(try current(id), by: delta, composition: composition)
                try store(layer)
            }

        case .roll(let leftLayerID, let rightLayerID, let boundary):
            guard leftLayerID != rightLayerID else {
                throw ProjectError.invalidOperation("Roll requires two different layers.")
            }
            var left = try current(leftLayerID)
            var right = try current(rightLayerID)
            guard isSourceBacked(left.source), isSourceBacked(right.source),
                  left.timing.outPoint == right.timing.inPoint else {
                throw ProjectError.invalidOperation("Roll requires adjacent source-backed layer boundaries.")
            }
            guard boundary > left.timing.inPoint, boundary < right.timing.outPoint else {
                throw ProjectError.invalidOperation("Roll boundary must remain inside the combined outer interval.")
            }
            left.timing.outPoint = boundary
            right.timing.inPoint = boundary
            try store(left)
            try store(right)

        case .slip(let layerID, let sourceDelta):
            var layer = try current(layerID)
            guard isSourceBacked(layer.source) else {
                throw ProjectError.invalidOperation("Only source-backed layers can slip.")
            }
            layer.timing.sourceOffset = try add(layer.timing.sourceOffset, sourceDelta)
            guard layer.timing.sourceOffset >= .zero else {
                throw ProjectError.invalidOperation("Slip would produce a negative source offset.")
            }
            try store(layer)

        case .slide(let layerID, let delta, let previousLayerID, let nextLayerID):
            var selected = try current(layerID)
            guard isSourceBacked(selected.source) else {
                throw ProjectError.invalidOperation("Only source-backed layers can slide.")
            }
            let oldIn = selected.timing.inPoint
            let oldOut = selected.timing.outPoint
            selected = try shiftedLayer(selected, by: delta, composition: composition)

            if let previousLayerID {
                guard previousLayerID != layerID else {
                    throw ProjectError.invalidOperation("Slide previous layer cannot be the selected layer.")
                }
                var previous = try current(previousLayerID)
                guard previous.timing.outPoint == oldIn else {
                    throw ProjectError.invalidOperation("Slide previous layer must meet the selected in point.")
                }
                previous.timing.outPoint = selected.timing.inPoint
                try store(previous)
            }
            if let nextLayerID {
                guard nextLayerID != layerID, nextLayerID != previousLayerID else {
                    throw ProjectError.invalidOperation("Slide next layer must be distinct.")
                }
                var next = try current(nextLayerID)
                guard next.timing.inPoint == oldOut else {
                    throw ProjectError.invalidOperation("Slide next layer must meet the selected out point.")
                }
                next.timing.inPoint = selected.timing.outPoint
                try store(next)
            }
            try store(selected)
        }

        let orderedUpdates = order.compactMap { updates[$0] }
        return TimelineEditResult(
            updatedLayers: orderedUpdates,
            insertedLayers: inserted,
            removedLayerIDs: [],
            resultingLayerOrder: order
        )
    }

    private func shiftedLayer(
        _ layer: ProjectLayer,
        by delta: RationalTime,
        composition: ProjectComposition
    ) throws -> ProjectLayer {
        var result = layer
        result.timing = try shifted(result.timing, by: delta, composition: composition)
        result.animationChannels = try result.animationChannels.map { channel in
            var shiftedChannel = channel
            shiftedChannel.keyframes = try channel.keyframes.map { keyframe in
                var shiftedKeyframe = keyframe
                shiftedKeyframe.time = try add(keyframe.time, delta)
                guard shiftedKeyframe.time >= .zero else {
                    throw ProjectError.invalidOperation("Moving the layer would place an animation keyframe before composition time zero.")
                }
                return shiftedKeyframe
            }
            return try shiftedChannel.validated()
        }
        return result
    }

    private func shifted(
        _ timing: LayerTiming,
        by delta: RationalTime,
        composition: ProjectComposition
    ) throws -> LayerTiming {
        var result = timing
        result.startTime = try add(result.startTime, delta)
        result.inPoint = try add(result.inPoint, delta)
        result.outPoint = try add(result.outPoint, delta)
        _ = try result.validated(for: composition)
        return result
    }

    private func isSourceBacked(_ source: LayerSource) -> Bool {
        switch source {
        case .media, .composition: true
        case .adjustment, .null, .guide, .camera, .light: false
        }
    }

    private func partitionAnimationChannels(
        _ channels: [ProjectAnimationChannel],
        at time: RationalTime
    ) throws -> (left: [ProjectAnimationChannel], right: [ProjectAnimationChannel]) {
        var leftChannels: [ProjectAnimationChannel] = []
        var rightChannels: [ProjectAnimationChannel] = []
        leftChannels.reserveCapacity(channels.count)
        rightChannels.reserveCapacity(channels.count)

        for channel in channels {
            _ = try channel.validated()
            let before = channel.keyframes.filter { $0.time < time }
            let exact = channel.keyframes.filter { $0.time == time }
            let after = channel.keyframes.filter { $0.time > time }

            var leftKeys = before + exact
            if exact.isEmpty, let firstAfter = after.first { leftKeys.append(firstAfter) }
            if leftKeys.isEmpty, let first = channel.keyframes.first { leftKeys = [first] }

            var rightKeys = exact + after
            if exact.isEmpty, let lastBefore = before.last { rightKeys.insert(lastBefore, at: 0) }
            if rightKeys.isEmpty, let last = channel.keyframes.last { rightKeys = [last] }

            var left = channel
            left.keyframes = leftKeys
            _ = try left.validated()
            leftChannels.append(left)

            var right = channel
            right.keyframes = rightKeys
            _ = try right.validated()
            rightChannels.append(right)
        }
        return (leftChannels, rightChannels)
    }

    private func add(_ lhs: RationalTime, _ rhs: RationalTime) throws -> RationalTime {
        do { return try lhs.adding(rhs) }
        catch { throw ProjectError.invalidValue("Timeline time arithmetic overflowed.") }
    }

    private func subtract(_ lhs: RationalTime, _ rhs: RationalTime) throws -> RationalTime {
        do { return try lhs.subtracting(rhs) }
        catch { throw ProjectError.invalidValue("Timeline time arithmetic overflowed.") }
    }
}
