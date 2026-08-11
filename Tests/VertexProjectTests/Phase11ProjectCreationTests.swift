import Testing
@testable import VertexProject

@Test("New projects start empty until the user creates a composition")
func phase12NewProjectStartsEmpty() throws {
    let project = try ProjectDocument.makeNew(name: "Untitled Project")

    #expect(project.compositionRegistry.isEmpty)
    #expect(project.activeCompositionID == nil)
    #expect(project.layerRegistry.isEmpty)
}

@Test("Project metadata is written by the current app contract")
func phase12ProjectAppVersion() throws {
    let project = try ProjectDocument.makeNew(name: "Version Check")

    #expect(project.metadata.createdByAppVersion == ProjectDocument.currentAppVersion)
    #expect(project.metadata.lastSavedByAppVersion == ProjectDocument.currentAppVersion)
}
