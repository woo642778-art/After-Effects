import Foundation

public enum MeshEditingError: Error, Sendable, Equatable {
    case invalidTriangleIndex(Int)
    case invalidVertexIndex(Int)
    case invalidTolerance
}

public extension Mesh3D {
    func flippedNormals() -> Mesh3D {
        Mesh3D(
            vertices: vertices.map { vertex in
                var next = vertex
                next.normal = next.normal * -1
                return next
            },
            triangles: triangles.map { MeshTriangle($0.a, $0.c, $0.b) }
        )
    }

    func mergedVertices(tolerance: Double = 0.000_001) throws -> Mesh3D {
        guard tolerance > 0, tolerance.isFinite else { throw MeshEditingError.invalidTolerance }
        struct Key: Hashable { var x: Int64; var y: Int64; var z: Int64 }
        func key(_ position: Vector3D) -> Key {
            Key(
                x: Int64((position.x / tolerance).rounded()),
                y: Int64((position.y / tolerance).rounded()),
                z: Int64((position.z / tolerance).rounded())
            )
        }
        var map: [Key: Int] = [:]
        var remap: [Int: Int] = [:]
        var output: [MeshVertex] = []
        for (index, vertex) in vertices.enumerated() {
            let k = key(vertex.position)
            if let existing = map[k] {
                remap[index] = existing
            } else {
                let newIndex = output.count
                map[k] = newIndex
                remap[index] = newIndex
                output.append(vertex)
            }
        }
        let outputTriangles = triangles.compactMap { triangle -> MeshTriangle? in
            guard let a = remap[triangle.a], let b = remap[triangle.b], let c = remap[triangle.c], a != b, b != c, c != a else { return nil }
            return MeshTriangle(a, b, c)
        }
        return Mesh3D(vertices: output, triangles: outputTriangles)
    }

    func subdivided() throws -> Mesh3D {
        struct Edge: Hashable {
            var low: Int
            var high: Int
            init(_ a: Int, _ b: Int) { low = min(a, b); high = max(a, b) }
        }
        var outputVertices = vertices
        var midpointCache: [Edge: Int] = [:]
        func midpoint(_ a: Int, _ b: Int) throws -> Int {
            guard vertices.indices.contains(a) else { throw MeshEditingError.invalidVertexIndex(a) }
            guard vertices.indices.contains(b) else { throw MeshEditingError.invalidVertexIndex(b) }
            let edge = Edge(a, b)
            if let cached = midpointCache[edge] { return cached }
            let va = vertices[a]
            let vb = vertices[b]
            let vertex = MeshVertex(
                position: (va.position + vb.position) / 2,
                normal: (va.normal + vb.normal).normalized,
                uv: Vector2D(x: (va.uv.x + vb.uv.x) / 2, y: (va.uv.y + vb.uv.y) / 2)
            )
            let index = outputVertices.count
            outputVertices.append(vertex)
            midpointCache[edge] = index
            return index
        }
        var outputTriangles: [MeshTriangle] = []
        outputTriangles.reserveCapacity(triangles.count * 4)
        for triangle in triangles {
            let ab = try midpoint(triangle.a, triangle.b)
            let bc = try midpoint(triangle.b, triangle.c)
            let ca = try midpoint(triangle.c, triangle.a)
            outputTriangles += [
                MeshTriangle(triangle.a, ab, ca), MeshTriangle(ab, triangle.b, bc),
                MeshTriangle(ca, bc, triangle.c), MeshTriangle(ab, bc, ca)
            ]
        }
        return Mesh3D(vertices: outputVertices, triangles: outputTriangles)
    }

    func extrudingFace(at triangleIndex: Int, distance: Double) throws -> Mesh3D {
        guard triangles.indices.contains(triangleIndex) else { throw MeshEditingError.invalidTriangleIndex(triangleIndex) }
        let face = triangles[triangleIndex]
        guard vertices.indices.contains(face.a), vertices.indices.contains(face.b), vertices.indices.contains(face.c) else {
            throw MeshEditingError.invalidVertexIndex(max(face.a, max(face.b, face.c)))
        }
        let pa = vertices[face.a].position
        let pb = vertices[face.b].position
        let pc = vertices[face.c].position
        let normal = (pb - pa).cross(pc - pa).normalized
        var outputVertices = vertices
        let old = [face.a, face.b, face.c]
        var cap: [Int] = []
        for index in old {
            var vertex = vertices[index]
            vertex.position = vertex.position + normal * distance
            vertex.normal = normal
            cap.append(outputVertices.count)
            outputVertices.append(vertex)
        }
        var outputTriangles = triangles
        outputTriangles[triangleIndex] = MeshTriangle(cap[0], cap[1], cap[2])
        for edge in 0..<3 {
            let next = (edge + 1) % 3
            outputTriangles.append(MeshTriangle(old[edge], old[next], cap[next]))
            outputTriangles.append(MeshTriangle(old[edge], cap[next], cap[edge]))
        }
        return Mesh3D(vertices: outputVertices, triangles: outputTriangles)
    }

    func insettingFace(at triangleIndex: Int, factor: Double) throws -> Mesh3D {
        guard triangles.indices.contains(triangleIndex) else { throw MeshEditingError.invalidTriangleIndex(triangleIndex) }
        let face = triangles[triangleIndex]
        let ids = [face.a, face.b, face.c]
        for id in ids where !vertices.indices.contains(id) { throw MeshEditingError.invalidVertexIndex(id) }
        let clamped = min(max(factor, 0), 1)
        let centroid = (vertices[face.a].position + vertices[face.b].position + vertices[face.c].position) / 3
        var outputVertices = vertices
        var inset: [Int] = []
        for id in ids {
            var vertex = vertices[id]
            vertex.position = vertex.position + (centroid - vertex.position) * clamped
            inset.append(outputVertices.count)
            outputVertices.append(vertex)
        }
        var outputTriangles = triangles
        outputTriangles[triangleIndex] = MeshTriangle(inset[0], inset[1], inset[2])
        for edge in 0..<3 {
            let next = (edge + 1) % 3
            outputTriangles.append(MeshTriangle(ids[edge], ids[next], inset[next]))
            outputTriangles.append(MeshTriangle(ids[edge], inset[next], inset[edge]))
        }
        return Mesh3D(vertices: outputVertices, triangles: outputTriangles)
    }

    func bevelingFace(at triangleIndex: Int, width: Double) throws -> Mesh3D {
        let factor = min(max(abs(width), 0), 0.95)
        let inset = try insettingFace(at: triangleIndex, factor: factor)
        return try inset.extrudingFace(at: triangleIndex, distance: width * 0.5)
    }

    static func combined(_ meshes: [Mesh3D]) -> Mesh3D {
        var vertices: [MeshVertex] = []
        var triangles: [MeshTriangle] = []
        for mesh in meshes {
            let offset = vertices.count
            vertices.append(contentsOf: mesh.vertices)
            triangles.append(contentsOf: mesh.triangles.map { MeshTriangle($0.a + offset, $0.b + offset, $0.c + offset) })
        }
        return Mesh3D(vertices: vertices, triangles: triangles)
    }
}
