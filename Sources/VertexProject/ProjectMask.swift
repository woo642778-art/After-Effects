import Foundation
import VertexCore

public enum ProjectMaskMode: String, Codable, CaseIterable, Sendable {
    case add
    case subtract
    case intersect
    case none
}

public struct ProjectMaskSegment: Codable, Equatable, Sendable {
    public var start: ProjectVector2
    public var end: ProjectVector2

    public init(start: ProjectVector2, end: ProjectVector2) {
        self.start = start
        self.end = end
    }
}

public struct ProjectMask: Codable, Equatable, Sendable, Identifiable {
    public static let maximumMasksPerLayer = 16
    public static let maximumVertices = 64
    public static let flattenSegmentsPerCurve = 8
    public static let maximumFlattenedSegments = 512

    public var id: VertexID
    public var name: String
    public var path: ProjectBezierPath
    public var mode: ProjectMaskMode
    public var opacity: Double
    public var featherPixels: Double
    public var expansionPixels: Double
    public var inverted: Bool
    public var enabled: Bool

    public init(
        id: VertexID = VertexID(),
        name: String,
        path: ProjectBezierPath,
        mode: ProjectMaskMode = .add,
        opacity: Double = 1,
        featherPixels: Double = 0,
        expansionPixels: Double = 0,
        inverted: Bool = false,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.mode = mode
        self.opacity = opacity
        self.featherPixels = featherPixels
        self.expansionPixels = expansionPixels
        self.inverted = inverted
        self.enabled = enabled
    }

    public func validated() throws -> Self {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.invalidValue("Mask name must not be empty.")
        }
        _ = try path.validated(maximumVertices: Self.maximumVertices)
        guard path.closed else {
            throw ProjectError.invalidValue("Phase 8 layer masks must be closed Bezier paths.")
        }
        guard opacity.isFinite, (0...1).contains(opacity) else {
            throw ProjectError.invalidValue("Mask opacity must be finite and within 0...1.")
        }
        guard featherPixels.isFinite, featherPixels >= 0 else {
            throw ProjectError.invalidValue("Mask feather must be finite and nonnegative.")
        }
        guard expansionPixels.isFinite else {
            throw ProjectError.invalidValue("Mask expansion must be finite.")
        }
        let segments = try flattenedSegments()
        guard segments.count <= Self.maximumFlattenedSegments else {
            throw ProjectError.invalidValue("Mask flattened segment count exceeds the mobile render limit.")
        }
        return self
    }

    public func flattenedSegments(
        segmentsPerCurve: Int = ProjectMask.flattenSegmentsPerCurve
    ) throws -> [ProjectMaskSegment] {
        _ = try path.validated(maximumVertices: Self.maximumVertices)
        guard segmentsPerCurve > 0 else {
            throw ProjectError.invalidValue("Bezier flattening segment count must be positive.")
        }
        let edgeCount = path.closed ? path.vertices.count : max(0, path.vertices.count - 1)
        let total = edgeCount.multipliedReportingOverflow(by: segmentsPerCurve)
        guard !total.overflow, total.partialValue <= Self.maximumFlattenedSegments else {
            throw ProjectError.invalidValue("Bezier flattening exceeds the mask segment limit.")
        }

        var result: [ProjectMaskSegment] = []
        result.reserveCapacity(total.partialValue)
        for edge in 0..<edgeCount {
            let current = path.vertices[edge]
            let next = path.vertices[(edge + 1) % path.vertices.count]
            let p0 = current.anchor
            let p1 = ProjectVector2(
                x: current.anchor.x + current.outgoingTangent.x,
                y: current.anchor.y + current.outgoingTangent.y
            )
            let p2 = ProjectVector2(
                x: next.anchor.x + next.incomingTangent.x,
                y: next.anchor.y + next.incomingTangent.y
            )
            let p3 = next.anchor

            for step in 0..<segmentsPerCurve {
                let t0 = Double(step) / Double(segmentsPerCurve)
                let t1 = Double(step + 1) / Double(segmentsPerCurve)
                result.append(ProjectMaskSegment(
                    start: cubicPoint(p0: p0, p1: p1, p2: p2, p3: p3, t: t0),
                    end: cubicPoint(p0: p0, p1: p1, p2: p2, p3: p3, t: t1)
                ))
            }
        }
        return result
    }

    private func cubicPoint(
        p0: ProjectVector2,
        p1: ProjectVector2,
        p2: ProjectVector2,
        p3: ProjectVector2,
        t: Double
    ) -> ProjectVector2 {
        let oneMinus = 1 - t
        let a = oneMinus * oneMinus * oneMinus
        let b = 3 * oneMinus * oneMinus * t
        let c = 3 * oneMinus * t * t
        let d = t * t * t
        return ProjectVector2(
            x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
            y: a * p0.y + b * p1.y + c * p2.y + d * p3.y
        )
    }
}

public extension Array where Element == ProjectMask {
    func validatedMasks() throws -> [ProjectMask] {
        guard count <= ProjectMask.maximumMasksPerLayer else {
            throw ProjectError.invalidValue("A layer may contain at most \(ProjectMask.maximumMasksPerLayer) masks.")
        }
        guard Set(map(\.id)).count == count else {
            throw ProjectError.duplicateIdentity("mask")
        }
        for mask in self {
            _ = try mask.validated()
        }
        return self
    }
}

public enum ProjectTrackMatteMode: String, Codable, CaseIterable, Sendable {
    case alpha
    case alphaInverted
    case luma
    case lumaInverted
}

public struct ProjectTrackMatte: Codable, Equatable, Sendable {
    public var sourceLayerID: VertexID
    public var mode: ProjectTrackMatteMode

    public init(sourceLayerID: VertexID, mode: ProjectTrackMatteMode) {
        self.sourceLayerID = sourceLayerID
        self.mode = mode
    }
}
