import Foundation

public enum Model3DFormat: String, Codable, Sendable, CaseIterable {
    case gltf
    case glb
    case usdz

    public init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "gltf": self = .gltf
        case "glb": self = .glb
        case "usdz": self = .usdz
        default: return nil
        }
    }
}

public enum Model3DValidationError: Error, Sendable, Equatable {
    case unsupportedExtension(String)
    case unreadableGLTF
    case invalidGLBHeader
    case missingGLBJSONChunk
}

public struct Model3DAssetDescriptor: Codable, Sendable, Equatable {
    public var format: Model3DFormat
    public var byteCount: Int
    public var sceneCount: Int?
    public var meshCount: Int?
    public var materialCount: Int?
    public init(format: Model3DFormat, byteCount: Int, sceneCount: Int? = nil, meshCount: Int? = nil, materialCount: Int? = nil) {
        self.format = format; self.byteCount = byteCount; self.sceneCount = sceneCount; self.meshCount = meshCount; self.materialCount = materialCount
    }
}

public enum Model3DInspector {
    public static func inspect(data: Data, fileExtension: String) throws -> Model3DAssetDescriptor {
        guard let format = Model3DFormat(fileExtension: fileExtension) else {
            throw Model3DValidationError.unsupportedExtension(fileExtension)
        }
        switch format {
        case .gltf:
            return try inspectGLTFJSON(data, format: .gltf, totalBytes: data.count)
        case .glb:
            guard data.count >= 20 else { throw Model3DValidationError.invalidGLBHeader }
            let magic = UInt32(data[0]) | UInt32(data[1]) << 8 | UInt32(data[2]) << 16 | UInt32(data[3]) << 24
            guard magic == 0x46546C67 else { throw Model3DValidationError.invalidGLBHeader }
            let chunkLength = Int(UInt32(data[12]) | UInt32(data[13]) << 8 | UInt32(data[14]) << 16 | UInt32(data[15]) << 24)
            let chunkType = UInt32(data[16]) | UInt32(data[17]) << 8 | UInt32(data[18]) << 16 | UInt32(data[19]) << 24
            guard chunkType == 0x4E4F534A, chunkLength >= 0, data.count >= 20 + chunkLength else {
                throw Model3DValidationError.missingGLBJSONChunk
            }
            return try inspectGLTFJSON(data.subdata(in: 20..<(20 + chunkLength)), format: .glb, totalBytes: data.count)
        case .usdz:
            return Model3DAssetDescriptor(format: .usdz, byteCount: data.count)
        }
    }

    private static func inspectGLTFJSON(_ data: Data, format: Model3DFormat, totalBytes: Int) throws -> Model3DAssetDescriptor {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Model3DValidationError.unreadableGLTF
        }
        return Model3DAssetDescriptor(
            format: format,
            byteCount: totalBytes,
            sceneCount: (object["scenes"] as? [Any])?.count,
            meshCount: (object["meshes"] as? [Any])?.count,
            materialCount: (object["materials"] as? [Any])?.count
        )
    }
}
