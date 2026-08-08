import Foundation

public enum AIFramePriority: Int, Codable, CaseIterable, Sendable, Comparable {
    case background = 0
    case workArea = 1
    case playbackNeighbor = 2
    case currentFrame = 3

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum AIFrameEffectStatus: Equatable, Sendable {
    case ready
    case computing
    case cached
    case stale
    case failed(String)
}
