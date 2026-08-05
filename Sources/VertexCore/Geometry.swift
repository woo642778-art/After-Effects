import Foundation

public struct VertexPoint: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct VertexSize: Codable, Equatable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum VertexCoordinateSpace: String, Codable, CaseIterable, Sendable {
    case pixelsTopLeft
    case pixelsCenter
    case normalizedTopLeft
    case normalizedCenter
}

public enum GeometryError: Error, Equatable, Sendable {
    case invalidCanvasSize(VertexSize)
    case nonFinitePoint(VertexPoint)
}

public enum CoordinateConverter {
    public static func convert(
        _ point: VertexPoint,
        from source: VertexCoordinateSpace,
        to destination: VertexCoordinateSpace,
        canvas: VertexSize
    ) throws -> VertexPoint {
        guard canvas.width.isFinite, canvas.height.isFinite, canvas.width > 0, canvas.height > 0 else {
            throw GeometryError.invalidCanvasSize(canvas)
        }
        guard point.x.isFinite, point.y.isFinite else {
            throw GeometryError.nonFinitePoint(point)
        }

        let normalizedTopLeft: VertexPoint
        switch source {
        case .pixelsTopLeft:
            normalizedTopLeft = VertexPoint(x: point.x / canvas.width, y: point.y / canvas.height)
        case .pixelsCenter:
            normalizedTopLeft = VertexPoint(x: point.x / canvas.width + 0.5, y: point.y / canvas.height + 0.5)
        case .normalizedTopLeft:
            normalizedTopLeft = point
        case .normalizedCenter:
            normalizedTopLeft = VertexPoint(x: point.x + 0.5, y: point.y + 0.5)
        }

        switch destination {
        case .pixelsTopLeft:
            return VertexPoint(x: normalizedTopLeft.x * canvas.width, y: normalizedTopLeft.y * canvas.height)
        case .pixelsCenter:
            return VertexPoint(x: (normalizedTopLeft.x - 0.5) * canvas.width, y: (normalizedTopLeft.y - 0.5) * canvas.height)
        case .normalizedTopLeft:
            return normalizedTopLeft
        case .normalizedCenter:
            return VertexPoint(x: normalizedTopLeft.x - 0.5, y: normalizedTopLeft.y - 0.5)
        }
    }
}
