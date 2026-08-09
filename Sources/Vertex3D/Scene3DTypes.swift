import Foundation

public struct Vector2D: Codable, Sendable, Equatable, Hashable {
    public var x: Double
    public var y: Double
    public init(x: Double = 0, y: Double = 0) { self.x = x; self.y = y }
}

public struct Vector3D: Codable, Sendable, Equatable, Hashable {
    public var x: Double
    public var y: Double
    public var z: Double
    public init(x: Double = 0, y: Double = 0, z: Double = 0) { self.x = x; self.y = y; self.z = z }

    public static let zero = Vector3D()
    public static let one = Vector3D(x: 1, y: 1, z: 1)

    public static func +(lhs: Self, rhs: Self) -> Self { .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z) }
    public static func -(lhs: Self, rhs: Self) -> Self { .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z) }
    public static func *(lhs: Self, rhs: Double) -> Self { .init(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs) }
    public static func /(lhs: Self, rhs: Double) -> Self { .init(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs) }

    public var length: Double { sqrt(x * x + y * y + z * z) }
    public var normalized: Self {
        let magnitude = length
        return magnitude > 0 ? self / magnitude : .zero
    }
    public func dot(_ other: Self) -> Double { x * other.x + y * other.y + z * other.z }
    public func cross(_ other: Self) -> Self {
        .init(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }
}

public struct ColorRGBA3D: Codable, Sendable, Equatable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    public init(red: Double = 1, green: Double = 1, blue: Double = 1, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }
    public static let white = ColorRGBA3D()
    public static let black = ColorRGBA3D(red: 0, green: 0, blue: 0)
}

public struct Bounds3D: Codable, Sendable, Equatable {
    public var min: Vector3D
    public var max: Vector3D
    public init(min: Vector3D, max: Vector3D) { self.min = min; self.max = max }
    public var center: Vector3D { (min + max) / 2 }
    public var size: Vector3D { max - min }
}

public struct Transform3D: Codable, Sendable, Equatable {
    public var position: Vector3D
    public var rotationDegrees: Vector3D
    public var scale: Vector3D
    public init(position: Vector3D = .zero, rotationDegrees: Vector3D = .zero, scale: Vector3D = .one) {
        self.position = position; self.rotationDegrees = rotationDegrees; self.scale = scale
    }
    public static let identity = Transform3D()
}

public struct MeshVertex: Codable, Sendable, Equatable {
    public var position: Vector3D
    public var normal: Vector3D
    public var uv: Vector2D
    public init(position: Vector3D, normal: Vector3D = .zero, uv: Vector2D = .init()) {
        self.position = position; self.normal = normal; self.uv = uv
    }
}

public struct MeshTriangle: Codable, Sendable, Equatable, Hashable {
    public var a: Int
    public var b: Int
    public var c: Int
    public init(_ a: Int, _ b: Int, _ c: Int) { self.a = a; self.b = b; self.c = c }
    public var indices: [Int] { [a, b, c] }
}

public struct Mesh3D: Codable, Sendable, Equatable {
    public var vertices: [MeshVertex]
    public var triangles: [MeshTriangle]
    public init(vertices: [MeshVertex] = [], triangles: [MeshTriangle] = []) {
        self.vertices = vertices; self.triangles = triangles
    }

    public var bounds: Bounds3D? {
        guard let first = vertices.first?.position else { return nil }
        var minimum = first
        var maximum = first
        for vertex in vertices.dropFirst() {
            let p = vertex.position
            minimum.x = Swift.min(minimum.x, p.x); minimum.y = Swift.min(minimum.y, p.y); minimum.z = Swift.min(minimum.z, p.z)
            maximum.x = Swift.max(maximum.x, p.x); maximum.y = Swift.max(maximum.y, p.y); maximum.z = Swift.max(maximum.z, p.z)
        }
        return Bounds3D(min: minimum, max: maximum)
    }
}

public enum Primitive3DKind: String, Codable, Sendable, CaseIterable {
    case cube
    case sphere
    case plane
}

public enum CameraProjection3D: String, Codable, Sendable {
    case perspective
    case orthographic
}

public struct Camera3D: Codable, Sendable, Equatable {
    public var projection: CameraProjection3D
    public var fieldOfViewDegrees: Double
    public var nearClip: Double
    public var farClip: Double
    public var orthographicScale: Double
    public init(projection: CameraProjection3D = .perspective, fieldOfViewDegrees: Double = 50, nearClip: Double = 0.01, farClip: Double = 10_000, orthographicScale: Double = 10) {
        self.projection = projection; self.fieldOfViewDegrees = fieldOfViewDegrees; self.nearClip = nearClip; self.farClip = farClip; self.orthographicScale = orthographicScale
    }
}

public enum LightKind3D: String, Codable, Sendable, CaseIterable {
    case ambient
    case directional
    case point
    case spot
}

public struct Light3D: Codable, Sendable, Equatable {
    public var kind: LightKind3D
    public var color: ColorRGBA3D
    public var intensity: Double
    public var range: Double
    public var spotAngleDegrees: Double
    public var castsShadows: Bool
    public init(kind: LightKind3D = .directional, color: ColorRGBA3D = .white, intensity: Double = 1, range: Double = 100, spotAngleDegrees: Double = 45, castsShadows: Bool = true) {
        self.kind = kind; self.color = color; self.intensity = intensity; self.range = range; self.spotAngleDegrees = spotAngleDegrees; self.castsShadows = castsShadows
    }
}

public enum MaterialShadingModel3D: String, Codable, Sendable {
    case unlit
    case lambert
    case physicallyBased
}

public struct Material3D: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var shadingModel: MaterialShadingModel3D
    public var baseColor: ColorRGBA3D
    public var metallic: Double
    public var roughness: Double
    public var emissiveColor: ColorRGBA3D
    public var opacity: Double
    public init(id: UUID = UUID(), name: String = "Material", shadingModel: MaterialShadingModel3D = .physicallyBased, baseColor: ColorRGBA3D = .white, metallic: Double = 0, roughness: Double = 0.5, emissiveColor: ColorRGBA3D = .black, opacity: Double = 1) {
        self.id = id; self.name = name; self.shadingModel = shadingModel; self.baseColor = baseColor; self.metallic = metallic; self.roughness = roughness; self.emissiveColor = emissiveColor; self.opacity = opacity
    }
}

public enum Scene3DNodePayload: Codable, Sendable, Equatable {
    case mesh(Mesh3D, materialID: UUID?)
    case camera(Camera3D)
    case light(Light3D)
    case group
}

public struct Scene3DNode: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var transform: Transform3D
    public var isVisible: Bool
    public var payload: Scene3DNodePayload
    public init(id: UUID = UUID(), name: String, transform: Transform3D = .identity, isVisible: Bool = true, payload: Scene3DNodePayload) {
        self.id = id; self.name = name; self.transform = transform; self.isVisible = isVisible; self.payload = payload
    }
}

public struct Scene3DDocument: Codable, Sendable, Equatable {
    public var nodes: [Scene3DNode]
    public var materials: [Material3D]
    public var activeCameraID: UUID?
    public init(nodes: [Scene3DNode] = [], materials: [Material3D] = [], activeCameraID: UUID? = nil) {
        self.nodes = nodes; self.materials = materials; self.activeCameraID = activeCameraID
    }

    public static var starter: Scene3DDocument {
        let material = Material3D(name: "Default")
        let cube = Scene3DNode(name: "Cube", payload: .mesh(.cube(size: 2), materialID: material.id))
        let camera = Scene3DNode(name: "Camera", transform: Transform3D(position: Vector3D(x: 0, y: 0, z: 6)), payload: .camera(Camera3D()))
        let light = Scene3DNode(name: "Key Light", transform: Transform3D(rotationDegrees: Vector3D(x: -35, y: 35, z: 0)), payload: .light(Light3D()))
        return Scene3DDocument(nodes: [cube, camera, light], materials: [material], activeCameraID: camera.id)
    }
}
