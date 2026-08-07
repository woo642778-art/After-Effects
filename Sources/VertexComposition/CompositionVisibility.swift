import Foundation
import VertexCore
import VertexProject

struct CompositionVisibilityResolver {
    func participatingLayers(
        in composition: ProjectComposition,
        project: ProjectDocument,
        time: RationalTime
    ) throws -> [ProjectLayer] {
        guard composition.layerIDs.count <= 256 else {
            throw CompositionError.layerLimitExceeded(composition.layerIDs.count)
        }
        let layerByID = Dictionary(uniqueKeysWithValues: project.layerRegistry.map { ($0.id, $0) })
        let active = try composition.layerIDs.map { id -> ProjectLayer in
            guard let layer = layerByID[id] else {
                throw CompositionError.missingLayer(id.rawValue)
            }
            guard layer.compositionID == composition.id else {
                throw CompositionError.invalidLayerOrder("Layer \(id.rawValue) has a different owner.")
            }
            return layer
        }.filter { layer in
            layer.enabled && layer.timing.inPoint <= time && time < layer.timing.outPoint
        }

        let hasSolo = active.contains(where: \.solo)
        return active.filter { layer in
            if hasSolo && !layer.solo { return false }
            return !layer.source.isModelOnly
        }
    }
}
