from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]

def write(path, text):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)

write("Sources/VertexTimeline/TimelineSnapEngine.swift", r'''import Foundation
import VertexCore

public enum TimelineSnapKind: String, Codable, CaseIterable, Hashable, Sendable {
    case playhead
    case layerIn
    case layerOut
    case compositionStart
    case compositionEnd
    case workAreaStart
    case workAreaEnd
    case keyframe
    case marker

    fileprivate var stableRank: Int {
        switch self {
        case .playhead: 0
        case .layerIn: 1
        case .layerOut: 2
        case .compositionStart: 3
        case .compositionEnd: 4
        case .workAreaStart: 5
        case .workAreaEnd: 6
        case .keyframe: 7
        case .marker: 8
        }
    }
}

public struct TimelineSnapCandidate: Codable, Equatable, Hashable, Sendable {
    public var time: RationalTime
    public var kind: TimelineSnapKind
    public var ownerID: VertexID?

    public init(time: RationalTime, kind: TimelineSnapKind, ownerID: VertexID? = nil) {
        self.time = time
        self.kind = kind
        self.ownerID = ownerID
    }
}

public struct TimelineSnapResult: Equatable, Sendable {
    public var snappedTime: RationalTime
    public var candidate: TimelineSnapCandidate?

    public init(snappedTime: RationalTime, candidate: TimelineSnapCandidate?) {
        self.snappedTime = snappedTime
        self.candidate = candidate
    }
}

public enum TimelineSnapError: Error, Equatable, Sendable {
    case invalidScale
    case invalidThreshold
}

public struct TimelineSnapEngine: Sendable {
    public init() {}

    public func snap(
        proposedTime: RationalTime,
        candidates: [TimelineSnapCandidate],
        thresholdPoints: Double,
        secondsPerPoint: Double
    ) throws -> TimelineSnapResult {
        guard secondsPerPoint.isFinite, secondsPerPoint > 0 else {
            throw TimelineSnapError.invalidScale
        }
        guard thresholdPoints.isFinite, thresholdPoints >= 0 else {
            throw TimelineSnapError.invalidThreshold
        }
        let thresholdSeconds = thresholdPoints * secondsPerPoint
        guard thresholdSeconds.isFinite else { throw TimelineSnapError.invalidThreshold }

        let eligible = candidates.compactMap { candidate -> (TimelineSnapCandidate, Double)? in
            let distance = abs(candidate.time.seconds - proposedTime.seconds)
            guard distance.isFinite, distance <= thresholdSeconds else { return nil }
            return (candidate, distance)
        }
        let best = eligible.min { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            if lhs.0.kind.stableRank != rhs.0.kind.stableRank {
                return lhs.0.kind.stableRank < rhs.0.kind.stableRank
            }
            let lhsOwner = lhs.0.ownerID?.rawValue ?? ""
            let rhsOwner = rhs.0.ownerID?.rawValue ?? ""
            if lhsOwner != rhsOwner { return lhsOwner < rhsOwner }
            return lhs.0.time < rhs.0.time
        }
        guard let best else {
            return TimelineSnapResult(snappedTime: proposedTime, candidate: nil)
        }
        return TimelineSnapResult(snappedTime: best.0.time, candidate: best.0)
    }
}
''')

write("Sources/VertexTimeline/TimelineSelection.swift", r'''import Foundation
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
        if !layerIDs.remove(id) { layerIDs.insert(id) }
    }

    public mutating func toggleKeyframe(_ id: VertexID) {
        if !keyframeIDs.remove(id) { keyframeIDs.insert(id) }
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
''')
print("Task 3 GREEN implementation applied")
