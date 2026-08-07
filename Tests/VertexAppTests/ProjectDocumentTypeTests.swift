import Testing
import UniformTypeIdentifiers
@testable import Vertex

@Test("Canonical project type edits vertexproject packages only")
func canonicalProjectDocumentType() {
    #expect(UTType.vertexProject.preferredFilenameExtension == "vertexproject")
    #expect(UTType.legacyAEProject.preferredFilenameExtension == "aeproject")
    #expect(ProjectPackageFileDocument.readableContentTypes == [.vertexProject])
    #expect(ProjectPackageFileDocument.writableContentTypes == [.vertexProject])
    #expect(!ProjectPackageFileDocument.readableContentTypes.contains(.legacyAEProject))
}
