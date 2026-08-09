import VertexProject

extension ProjectWorkspaceViewModel {
    func insertNewComposition(_ composition: ProjectComposition) throws {
        guard let project else {
            throw ProjectError.invalidOperation("Create or open a project before creating a composition.")
        }
        let validated = try composition.validated(layerByID: [:])
        perform(
            .insertComposition(
                validated,
                ownedLayers: [],
                index: project.compositionRegistry.count
            ),
            mergeKey: nil
        )
    }
}
