import Testing
@testable import VertexProject

@Test("Vertex2 11 new projects start empty until the user creates a composition")
func phase11NewProjectStartsEmpty() throws {
    let project = try ProjectDocument.makeNew(name: "Untitled Project")

    #expect(project.compositionRegistry.isEmpty)
    #expect(project.activeCompositionID == nil)
    #expect(project.layerRegistry.isEmpty)
}

@Test("Vertex2 11 project metadata is written by the 11.0 app contract")
func phase11ProjectAppVersion() throws {
    let project = try ProjectDocument.makeNew(name: "Version Check")

    #expect(ProjectDocument.currentAppVersion == "11.0.0")
    #expect(project.metadata.createdByAppVersion == "11.0.0")
    #expect(project.metadata.lastSavedByAppVersion == "11.0.0")
}
