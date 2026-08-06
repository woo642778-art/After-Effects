import UniformTypeIdentifiers

enum ProjectDocumentTypes {
    static let canonicalExtension = "vertexproject"
    static let legacyExtension = "aeproject"
    static let canonicalIdentifier = "com.maze.vertex.project"
    static let legacyIdentifier = "com.woo642778.aftereffects.project.legacy"
}

extension UTType {
    static let vertexProject = UTType(
        filenameExtension: ProjectDocumentTypes.canonicalExtension,
        conformingTo: .package
    )!

    static let legacyAEProject = UTType(
        filenameExtension: ProjectDocumentTypes.legacyExtension,
        conformingTo: .package
    )!
}
