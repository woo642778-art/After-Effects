import Foundation

public struct Matrix4x4D: Codable, Sendable, Equatable {
    public var elements: [Double]
    public init(_ elements: [Double]) {
        precondition(elements.count == 16)
        self.elements = elements
    }
    public static let identity = Matrix4x4D([
        1, 0, 0, 0, 0, 1, 0, 0,
        0, 0, 1, 0, 0, 0, 0, 1
    ])
    public subscript(row: Int, column: Int) -> Double { elements[row * 4 + column] }
}

public enum ProjectionMath3D {
    public static func perspective(fieldOfViewDegrees: Double, aspectRatio: Double, near: Double, far: Double) -> Matrix4x4D {
        let aspect = max(aspectRatio, 0.000_001)
        let near = max(near, 0.000_001)
        let far = max(far, near + 0.000_001)
        let f = 1 / tan(fieldOfViewDegrees * .pi / 360)
        return Matrix4x4D([
            f / aspect, 0, 0, 0,
            0, f, 0, 0,
            0, 0, far / (near - far), -1,
            0, 0, (near * far) / (near - far), 0
        ])
    }

    public static func orthographic(scale: Double, aspectRatio: Double, near: Double, far: Double) -> Matrix4x4D {
        let height = max(scale, 0.000_001)
        let width = height * max(aspectRatio, 0.000_001)
        let near = max(near, 0)
        let far = max(far, near + 0.000_001)
        return Matrix4x4D([
            2 / width, 0, 0, 0,
            0, 2 / height, 0, 0,
            0, 0, 1 / (near - far), 0,
            0, 0, near / (near - far), 1
        ])
    }
}
