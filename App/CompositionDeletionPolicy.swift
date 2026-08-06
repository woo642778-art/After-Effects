import VertexProject

@MainActor
extension ProjectWorkspaceViewModel {
    var activeCompositionDeletionBlockReason: String? {
        guard let project, let composition = activeComposition else {
            return "Select a composition before deleting it."
        }
        guard project.compositionRegistry.count > 1 else {
            return "A project must retain at least one composition."
        }
        let reference = project.layerRegistry.first { layer in
            guard layer.compositionID != composition.id,
                  case .composition(let targetID, _) = layer.source else { return false }
            return targetID == composition.id
        }
        if let reference {
            let ownerName = project.composition(id: reference.compositionID)?.name ?? "another composition"
            return "Cannot delete this composition because “\(reference.name)” in “\(ownerName)” references it."
        }
        return nil
    }
}
