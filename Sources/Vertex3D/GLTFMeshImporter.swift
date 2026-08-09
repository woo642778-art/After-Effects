import Foundation

public enum Model3DImportError: Error, Sendable, Equatable {
    case unsupportedFormat(String)
    case malformedDocument(String)
    case missingMesh
    case unsupportedPrimitiveMode(Int)
    case unsupportedAccessor(String)
    case externalResourceMissing(String)
    case platformImporterRequired(Model3DFormat)
}

public enum Model3DImporter {
    public static func loadMesh(from url: URL) throws -> Mesh3D {
        guard let format = Model3DFormat(fileExtension: url.pathExtension) else {
            throw Model3DImportError.unsupportedFormat(url.pathExtension)
        }
        switch format {
        case .gltf:
            return try loadGLTF(json: Data(contentsOf: url), baseURL: url.deletingLastPathComponent(), binaryChunk: nil)
        case .glb:
            let chunks = try parseGLB(Data(contentsOf: url))
            return try loadGLTF(json: chunks.json, baseURL: url.deletingLastPathComponent(), binaryChunk: chunks.binary)
        case .usdz:
            throw Model3DImportError.platformImporterRequired(.usdz)
        }
    }

    public static func loadGLB(data: Data) throws -> Mesh3D {
        let chunks = try parseGLB(data)
        return try loadGLTF(json: chunks.json, baseURL: nil, binaryChunk: chunks.binary)
    }

    public static func loadGLTF(json: Data, baseURL: URL? = nil, binaryChunk: Data? = nil) throws -> Mesh3D {
        guard let root = try JSONSerialization.jsonObject(with: json) as? [String: Any],
              let meshes = root["meshes"] as? [[String: Any]],
              let firstMesh = meshes.first,
              let primitives = firstMesh["primitives"] as? [[String: Any]],
              let primitive = primitives.first else { throw Model3DImportError.missingMesh }
        let mode = primitive["mode"] as? Int ?? 4
        guard mode == 4 else { throw Model3DImportError.unsupportedPrimitiveMode(mode) }
        guard let accessors = root["accessors"] as? [[String: Any]],
              let bufferViews = root["bufferViews"] as? [[String: Any]],
              let buffers = root["buffers"] as? [[String: Any]],
              let attributes = primitive["attributes"] as? [String: Any],
              let positionAccessor = attributes["POSITION"] as? Int else {
            throw Model3DImportError.malformedDocument("Missing glTF accessors or POSITION attribute")
        }
        let loadedBuffers = try loadBuffers(buffers, baseURL: baseURL, binaryChunk: binaryChunk)
        let positions = try readVector3Accessor(positionAccessor, accessors: accessors, bufferViews: bufferViews, buffers: loadedBuffers)
        let normals: [Vector3D]? = try (attributes["NORMAL"] as? Int).map {
            try readVector3Accessor($0, accessors: accessors, bufferViews: bufferViews, buffers: loadedBuffers)
        }
        let uvs: [Vector2D]? = try (attributes["TEXCOORD_0"] as? Int).map {
            try readVector2Accessor($0, accessors: accessors, bufferViews: bufferViews, buffers: loadedBuffers)
        }
        let indices: [Int]
        if let accessor = primitive["indices"] as? Int {
            indices = try readIndexAccessor(accessor, accessors: accessors, bufferViews: bufferViews, buffers: loadedBuffers)
        } else {
            indices = Array(positions.indices)
        }
        guard indices.count.isMultiple(of: 3) else {
            throw Model3DImportError.malformedDocument("Triangle index count must be divisible by three")
        }
        var vertices = positions.enumerated().map { index, position in
            MeshVertex(
                position: position,
                normal: normals.flatMap { index < $0.count ? $0[index] : nil } ?? .zero,
                uv: uvs.flatMap { index < $0.count ? $0[index] : nil } ?? .init()
            )
        }
        let triangles = stride(from: 0, to: indices.count, by: 3).map { offset in
            MeshTriangle(indices[offset], indices[offset + 1], indices[offset + 2])
        }
        guard triangles.allSatisfy({ vertices.indices.contains($0.a) && vertices.indices.contains($0.b) && vertices.indices.contains($0.c) }) else {
            throw Model3DImportError.malformedDocument("Index accessor references a missing vertex")
        }
        if normals == nil {
            var accumulated = Array(repeating: Vector3D.zero, count: vertices.count)
            for triangle in triangles {
                let a = vertices[triangle.a].position
                let b = vertices[triangle.b].position
                let c = vertices[triangle.c].position
                let face = (b - a).cross(c - a).normalized
                accumulated[triangle.a] = accumulated[triangle.a] + face
                accumulated[triangle.b] = accumulated[triangle.b] + face
                accumulated[triangle.c] = accumulated[triangle.c] + face
            }
            for index in vertices.indices { vertices[index].normal = accumulated[index].normalized }
        }
        return Mesh3D(vertices: vertices, triangles: triangles)
    }

    private static func loadBuffers(_ descriptions: [[String: Any]], baseURL: URL?, binaryChunk: Data?) throws -> [Data] {
        try descriptions.enumerated().map { index, description in
            if let uri = description["uri"] as? String {
                if uri.hasPrefix("data:") {
                    guard let comma = uri.firstIndex(of: ",") else { throw Model3DImportError.malformedDocument("Invalid data URI") }
                    let metadata = String(uri[..<comma])
                    let payload = String(uri[uri.index(after: comma)...])
                    if metadata.contains(";base64") {
                        guard let data = Data(base64Encoded: payload) else { throw Model3DImportError.malformedDocument("Invalid base64 buffer") }
                        return data
                    }
                    guard let decoded = payload.removingPercentEncoding else { throw Model3DImportError.malformedDocument("Invalid percent encoded buffer") }
                    return Data(decoded.utf8)
                }
                guard let baseURL else { throw Model3DImportError.externalResourceMissing(uri) }
                let resourceURL = baseURL.appendingPathComponent(uri)
                guard FileManager.default.fileExists(atPath: resourceURL.path) else { throw Model3DImportError.externalResourceMissing(uri) }
                return try Data(contentsOf: resourceURL)
            }
            if index == 0, let binaryChunk { return binaryChunk }
            throw Model3DImportError.malformedDocument("Buffer has no URI and no GLB binary chunk")
        }
    }

    private static func accessor(_ index: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], buffers: [Data]) throws -> (Data, Int, Int, Int, String, Int) {
        guard accessors.indices.contains(index) else { throw Model3DImportError.unsupportedAccessor("Accessor index \(index)") }
        let descriptor = accessors[index]
        guard let viewIndex = descriptor["bufferView"] as? Int,
              bufferViews.indices.contains(viewIndex),
              let componentType = descriptor["componentType"] as? Int,
              let count = descriptor["count"] as? Int,
              let type = descriptor["type"] as? String else {
            throw Model3DImportError.unsupportedAccessor("Sparse or incomplete accessor")
        }
        let view = bufferViews[viewIndex]
        guard let bufferIndex = view["buffer"] as? Int, buffers.indices.contains(bufferIndex) else {
            throw Model3DImportError.unsupportedAccessor("Missing buffer")
        }
        let offset = (view["byteOffset"] as? Int ?? 0) + (descriptor["byteOffset"] as? Int ?? 0)
        let stride = view["byteStride"] as? Int ?? 0
        return (buffers[bufferIndex], offset, stride, componentType, type, count)
    }

    private static func readVector3Accessor(_ index: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], buffers: [Data]) throws -> [Vector3D] {
        let (data, offset, strideValue, componentType, type, count) = try accessor(index, accessors: accessors, bufferViews: bufferViews, buffers: buffers)
        guard componentType == 5126, type == "VEC3" else { throw Model3DImportError.unsupportedAccessor("VEC3 must use FLOAT") }
        let stride = strideValue == 0 ? 12 : strideValue
        return try (0..<count).map { element in
            let start = offset + element * stride
            return Vector3D(x: Double(try readFloat32(data, start)), y: Double(try readFloat32(data, start + 4)), z: Double(try readFloat32(data, start + 8)))
        }
    }

    private static func readVector2Accessor(_ index: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], buffers: [Data]) throws -> [Vector2D] {
        let (data, offset, strideValue, componentType, type, count) = try accessor(index, accessors: accessors, bufferViews: bufferViews, buffers: buffers)
        guard componentType == 5126, type == "VEC2" else { throw Model3DImportError.unsupportedAccessor("VEC2 must use FLOAT") }
        let stride = strideValue == 0 ? 8 : strideValue
        return try (0..<count).map { element in
            let start = offset + element * stride
            return Vector2D(x: Double(try readFloat32(data, start)), y: Double(try readFloat32(data, start + 4)))
        }
    }

    private static func readIndexAccessor(_ index: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], buffers: [Data]) throws -> [Int] {
        let (data, offset, strideValue, componentType, type, count) = try accessor(index, accessors: accessors, bufferViews: bufferViews, buffers: buffers)
        guard type == "SCALAR" else { throw Model3DImportError.unsupportedAccessor("Indices must be SCALAR") }
        let componentSize: Int
        switch componentType {
        case 5121: componentSize = 1
        case 5123: componentSize = 2
        case 5125: componentSize = 4
        default: throw Model3DImportError.unsupportedAccessor("Unsupported index component type")
        }
        let stride = strideValue == 0 ? componentSize : strideValue
        return try (0..<count).map { element in
            let start = offset + element * stride
            switch componentType {
            case 5121:
                guard data.indices.contains(start) else { throw Model3DImportError.malformedDocument("Index buffer overrun") }
                return Int(data[start])
            case 5123: return Int(try readUInt16(data, start))
            default: return Int(try readUInt32(data, start))
            }
        }
    }

    private static func parseGLB(_ data: Data) throws -> (json: Data, binary: Data?) {
        guard data.count >= 20,
              try readUInt32(data, 0) == 0x46546C67,
              try readUInt32(data, 4) == 2 else { throw Model3DImportError.malformedDocument("Invalid GLB header") }
        let declaredLength = Int(try readUInt32(data, 8))
        guard declaredLength <= data.count else { throw Model3DImportError.malformedDocument("Truncated GLB") }
        var offset = 12
        var json: Data?
        var binary: Data?
        while offset + 8 <= declaredLength {
            let length = Int(try readUInt32(data, offset))
            let type = try readUInt32(data, offset + 4)
            let start = offset + 8
            let end = start + length
            guard end <= declaredLength else { throw Model3DImportError.malformedDocument("Truncated GLB chunk") }
            if type == 0x4E4F534A { json = trimJSONPadding(data.subdata(in: start..<end)) }
            if type == 0x004E4942 { binary = data.subdata(in: start..<end) }
            offset = end
        }
        guard let json else { throw Model3DImportError.malformedDocument("GLB JSON chunk missing") }
        return (json, binary)
    }

    private static func trimJSONPadding(_ data: Data) -> Data {
        var end = data.count
        while end > 0, data[end - 1] == 0 || data[end - 1] == 0x20 { end -= 1 }
        return data.prefix(end)
    }

    private static func readFloat32(_ data: Data, _ offset: Int) throws -> Float { Float(bitPattern: try readUInt32(data, offset)) }

    private static func readUInt16(_ data: Data, _ offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else { throw Model3DImportError.malformedDocument("Buffer overrun") }
        return UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func readUInt32(_ data: Data, _ offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { throw Model3DImportError.malformedDocument("Buffer overrun") }
        return UInt32(data[offset]) | UInt32(data[offset + 1]) << 8 | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
    }
}
