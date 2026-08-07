import Foundation

public enum RenderMaskMode: UInt32, Codable, CaseIterable, Sendable {
    case add = 0
    case subtract = 1
    case intersect = 2
    case none = 3
}

public struct RenderMaskPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func validated() throws -> Self {
        guard x.isFinite, y.isFinite else {
            throw RenderError.invalidRequest("Mask points must be finite.")
        }
        return self
    }
}

public struct RenderMaskSegment: Codable, Equatable, Sendable {
    public var start: RenderMaskPoint
    public var end: RenderMaskPoint

    public init(start: RenderMaskPoint, end: RenderMaskPoint) {
        self.start = start
        self.end = end
    }

    public func validated() throws -> Self {
        _ = try start.validated()
        _ = try end.validated()
        return self
    }
}

public struct RenderMaskDefinition: Codable, Equatable, Sendable {
    public var segments: [RenderMaskSegment]
    public var mode: RenderMaskMode
    public var opacity: Double
    public var featherPixels: Double
    public var expansionPixels: Double
    public var inverted: Bool
    public var enabled: Bool

    public init(
        segments: [RenderMaskSegment],
        mode: RenderMaskMode,
        opacity: Double,
        featherPixels: Double,
        expansionPixels: Double,
        inverted: Bool,
        enabled: Bool
    ) {
        self.segments = segments
        self.mode = mode
        self.opacity = opacity
        self.featherPixels = featherPixels
        self.expansionPixels = expansionPixels
        self.inverted = inverted
        self.enabled = enabled
    }

    public func validated() throws -> Self {
        guard segments.count >= 3, segments.count <= 512 else {
            throw RenderError.invalidRequest("A render mask must contain 3...512 flattened segments.")
        }
        for segment in segments { _ = try segment.validated() }
        guard opacity.isFinite, (0...1).contains(opacity) else {
            throw RenderError.invalidRequest("Mask opacity must be finite and within 0...1.")
        }
        guard featherPixels.isFinite, featherPixels >= 0 else {
            throw RenderError.invalidRequest("Mask feather must be finite and nonnegative.")
        }
        guard expansionPixels.isFinite else {
            throw RenderError.invalidRequest("Mask expansion must be finite.")
        }
        return self
    }
}

public struct RenderMaskStack: Codable, Equatable, Sendable {
    public var masks: [RenderMaskDefinition]

    public init(masks: [RenderMaskDefinition]) {
        self.masks = masks
    }

    public func validated() throws -> Self {
        guard !masks.isEmpty, masks.count <= 16 else {
            throw RenderError.invalidRequest("A render mask stack must contain 1...16 masks.")
        }
        for mask in masks { _ = try mask.validated() }
        return self
    }
}

public enum RenderTrackMatteMode: UInt32, Codable, CaseIterable, Sendable {
    case alpha = 0
    case alphaInverted = 1
    case luma = 2
    case lumaInverted = 3
}
