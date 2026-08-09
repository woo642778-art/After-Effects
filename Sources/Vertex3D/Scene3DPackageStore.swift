import Foundation

public enum Scene3DPackageStoreError: Error, Sendable, Equatable {
    case invalidProjectPackage(String)
}

public actor Scene3DPackageStore {
    public init() {}

    public func load(from packageURL: URL) throws -> Scene3DDocument {
        try validate(packageURL)
        let url = sceneURL(in: packageURL)
        guard FileManager.default.fileExists(atPath: url.path) else { return .starter }
        return try JSONDecoder().decode(Scene3DDocument.self, from: Data(contentsOf: url))
    }

    public func save(_ scene: Scene3DDocument, to packageURL: URL) throws {
        try validate(packageURL)
        let directory = packageURL.appendingPathComponent("Scene3D", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(scene)
        let destination = sceneURL(in: packageURL)
        let temporary = destination.appendingPathExtension("tmp")
        try data.write(to: temporary, options: .atomic)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: destination)
        }
    }

    private func sceneURL(in packageURL: URL) -> URL {
        packageURL.appendingPathComponent("Scene3D", isDirectory: true).appendingPathComponent("scene.json")
    }

    private func validate(_ packageURL: URL) throws {
        guard packageURL.isFileURL, packageURL.pathExtension.lowercased() == "vertexproject" else {
            throw Scene3DPackageStoreError.invalidProjectPackage(packageURL.pathExtension)
        }
    }
}
