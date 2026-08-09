import Testing
@testable import VertexProject

@Test("Vertex2 12 new projects start empty until the user creates a composition")
func phase12NewProjectStartsEmpty() throws {
    let project = try ProjectDocument.makeNew(name: "Untitled Project")

    #expect(project.compositionRegistry.isEmpty)
    #expect(project.activeCompositionID == nil)
    #expect(project.layerRegistry.isEmpty)
}

@Test("Vertex2 12 project metadata is written by the 12.0 app contract")
func phase12ProjectAppVersion() throws {
    let project = try ProjectDocument.makeNew(name: "Version Check")

    #expect(ProjectDocument.currentAppVersion == "12.0.0")
    #expect(project.metadata.createdByAppVersion == "12.0.0")
    #expect(project.metadata.lastSavedByAppVersion == "12.0.0")
}
