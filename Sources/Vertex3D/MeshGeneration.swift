import Foundation

public extension Mesh3D {
    static func cube(size: Double = 2) -> Mesh3D {
        let h = max(0, size) / 2
        let positions = [
            Vector3D(x: -h, y: -h, z: -h), Vector3D(x: h, y: -h, z: -h),
            Vector3D(x: h, y: h, z: -h), Vector3D(x: -h, y: h, z: -h),
            Vector3D(x: -h, y: -h, z: h), Vector3D(x: h, y: -h, z: h),
            Vector3D(x: h, y: h, z: h), Vector3D(x: -h, y: h, z: h)
        ]
        let vertices = positions.map { MeshVertex(position: $0, normal: $0.normalized) }
        let triangles = [
            MeshTriangle(0, 2, 1), MeshTriangle(0, 3, 2),
            MeshTriangle(4, 5, 6), MeshTriangle(4, 6, 7),
            MeshTriangle(0, 1, 5), MeshTriangle(0, 5, 4),
            MeshTriangle(3, 7, 6), MeshTriangle(3, 6, 2),
            MeshTriangle(0, 4, 7), MeshTriangle(0, 7, 3),
            MeshTriangle(1, 2, 6), MeshTriangle(1, 6, 5)
        ]
        return Mesh3D(vertices: vertices, triangles: triangles)
    }

    static func plane(width: Double = 2, depth: Double = 2) -> Mesh3D {
        let x = max(0, width) / 2
        let z = max(0, depth) / 2
        let normal = Vector3D(x: 0, y: 1, z: 0)
        return Mesh3D(
            vertices: [
                MeshVertex(position: .init(x: -x, y: 0, z: -z), normal: normal, uv: .init(x: 0, y: 0)),
                MeshVertex(position: .init(x: x, y: 0, z: -z), normal: normal, uv: .init(x: 1, y: 0)),
                MeshVertex(position: .init(x: x, y: 0, z: z), normal: normal, uv: .init(x: 1, y: 1)),
                MeshVertex(position: .init(x: -x, y: 0, z: z), normal: normal, uv: .init(x: 0, y: 1))
            ],
            triangles: [MeshTriangle(0, 1, 2), MeshTriangle(0, 2, 3)]
        )
    }

    static func sphere(radius: Double = 1, segments: Int = 24, rings: Int = 16) -> Mesh3D {
        let radius = max(0, radius)
        let segments = max(3, segments)
        let rings = max(2, rings)
        var vertices: [MeshVertex] = []
        vertices.reserveCapacity((rings + 1) * (segments + 1))
        for ring in 0...rings {
            let v = Double(ring) / Double(rings)
            let phi = Double.pi * v
            for segment in 0...segments {
                let u = Double(segment) / Double(segments)
                let theta = 2 * Double.pi * u
                let normal = Vector3D(
                    x: sin(phi) * cos(theta),
                    y: cos(phi),
                    z: sin(phi) * sin(theta)
                ).normalized
                vertices.append(MeshVertex(position: normal * radius, normal: normal, uv: .init(x: u, y: v)))
            }
        }
        var triangles: [MeshTriangle] = []
        triangles.reserveCapacity(rings * segments * 2)
        let row = segments + 1
        for ring in 0..<rings {
            for segment in 0..<segments {
                let a = ring * row + segment
                let b = a + 1
                let c = a + row
                let d = c + 1
                triangles.append(MeshTriangle(a, c, b))
                triangles.append(MeshTriangle(b, c, d))
            }
        }
        return Mesh3D(vertices: vertices, triangles: triangles)
    }
}
