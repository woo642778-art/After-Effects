import Foundation
import Vertex3D

#if canImport(ModelIO) && canImport(simd)
import ModelIO
import simd

public enum AppleModel3DImporterError: Error {
    case meshMissing
    case positionAttributeMissing
    case triangleSubmeshMissing
    case invalidIndexBuffer
}

public enum AppleModel3DImporter {
    public static func loadMesh(from url: URL) throws -> Mesh3D {
        let asset = MDLAsset(url: url)
        let meshObjects = asset.childObjects(of: MDLMesh.self).compactMap { $0 as? MDLMesh }
        guard let mesh = meshObjects.first else { throw AppleModel3DImporterError.meshMissing }
        if mesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributeNormal) == nil {
            mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.5)
        }
        guard let positions = mesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributePosition, as: .float3) else {
            throw AppleModel3DImporterError.positionAttributeMissing
        }
        let normals = mesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributeNormal, as: .float3)
        let texcoords = mesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributeTextureCoordinate, as: .float2)

        var vertices: [MeshVertex] = []
        vertices.reserveCapacity(mesh.vertexCount)
        for index in 0..<mesh.vertexCount {
            let p = positions.dataStart.advanced(by: index * positions.stride).assumingMemoryBound(to: SIMD3<Float>.self).pointee
            let n = normals.map { $0.dataStart.advanced(by: index * $0.stride).assumingMemoryBound(to: SIMD3<Float>.self).pointee } ?? SIMD3<Float>(0, 0, 0)
            let uv = texcoords.map { $0.dataStart.advanced(by: index * $0.stride).assumingMemoryBound(to: SIMD2<Float>.self).pointee } ?? SIMD2<Float>(0, 0)
            vertices.append(MeshVertex(
                position: Vector3D(x: Double(p.x), y: Double(p.y), z: Double(p.z)),
                normal: Vector3D(x: Double(n.x), y: Double(n.y), z: Double(n.z)),
                uv: Vector2D(x: Double(uv.x), y: Double(uv.y))
            ))
        }

        let submeshes = (mesh.submeshes as? [MDLSubmesh]) ?? []
        var triangles: [MeshTriangle] = []
        for submesh in submeshes where submesh.geometryType == .triangles {
            let buffer = submesh.indexBuffer(asIndexType: .uInt32)
            let map = buffer.map()
            let pointer = map.bytes.assumingMemoryBound(to: UInt32.self)
            guard submesh.indexCount.isMultiple(of: 3) else { throw AppleModel3DImporterError.invalidIndexBuffer }
            for offset in stride(from: 0, to: submesh.indexCount, by: 3) {
                triangles.append(MeshTriangle(Int(pointer[offset]), Int(pointer[offset + 1]), Int(pointer[offset + 2])))
            }
        }
        guard !triangles.isEmpty else { throw AppleModel3DImporterError.triangleSubmeshMissing }
        guard triangles.allSatisfy({ vertices.indices.contains($0.a) && vertices.indices.contains($0.b) && vertices.indices.contains($0.c) }) else {
            throw AppleModel3DImporterError.invalidIndexBuffer
        }
        return Mesh3D(vertices: vertices, triangles: triangles)
    }
}
#endif
