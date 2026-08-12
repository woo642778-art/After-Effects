import Foundation
import VertexCore

public extension ProjectNodeGraph {
    static func makeFromLayerStack(project: ProjectDocument, compositionID: VertexID) throws -> ProjectNodeGraph {
        let project = try project.validated()
        guard let composition = project.composition(id: compositionID) else {
            throw ProjectError.invalidValue("Layer-to-node bridge could not find composition \(compositionID.rawValue).")
        }

        var nodes: [ProjectNode] = []
        var connections: [ProjectNodeConnection] = []
        var column = 0

        func nodeID(_ role: String, _ components: [String] = []) throws -> VertexID {
            try DeterministicVertexID.derive(
                domain: "vertex18.node-bridge.\(role)",
                components: [project.projectID.rawValue, compositionID.rawValue] + components
            )
        }
        func connection(_ from: ProjectNodeEndpoint, _ to: ProjectNodeEndpoint, role: String) throws -> ProjectNodeConnection {
            ProjectNodeConnection(
                id: try DeterministicVertexID.derive(
                    domain: "vertex18.node-bridge.connection",
                    components: [project.projectID.rawValue, compositionID.rawValue, role, from.nodeID.rawValue, from.portID, to.nodeID.rawValue, to.portID]
                ),
                from: from,
                to: to
            )
        }
        func appendNode(id: VertexID, name: String, kind: ProjectNodeKind, row: Int = 0) {
            nodes.append(ProjectNode(
                id: id,
                name: name,
                kind: kind,
                position: ProjectNodePosition(x: Double(column * 220 + 70), y: Double(row * 180 + 100))
            ))
            column += 1
        }

        let backgroundID = try nodeID("background")
        appendNode(id: backgroundID, name: "Background", kind: .solidColor(composition.backgroundColor))
        var accumulator = ProjectNodeEndpoint(nodeID: backgroundID, portID: "image")

        let layerByID = Dictionary(uniqueKeysWithValues: project.layerRegistry.map { ($0.id, $0) })
        for (stackIndex, layerID) in composition.layerIDs.reversed().enumerated() {
            guard let layer = layerByID[layerID], layer.enabled else { continue }

            let sourceKind: ProjectNodeKind
            switch layer.source {
            case .media(let mediaID, _):
                sourceKind = .mediaInput(mediaID: mediaID)
            case .composition(let childID, _):
                sourceKind = .compositionInput(compositionID: childID)
            case .adjustment:
                sourceKind = .layerInput(layerID: layer.id)
            case .null, .guide, .camera, .light:
                continue
            }

            let sourceID = try nodeID("layer-source", [layer.id.rawValue])
            appendNode(id: sourceID, name: layer.name, kind: sourceKind, row: stackIndex)
            var prepared = ProjectNodeEndpoint(nodeID: sourceID, portID: "image")

            for (effectIndex, effect) in layer.effects.enumerated() where effect.enabled {
                let effectID = try nodeID("layer-effect", [layer.id.rawValue, String(effectIndex), effect.id.rawValue])
                appendNode(id: effectID, name: effect.type.descriptor.displayName, kind: .effect(effect), row: stackIndex)
                let input = ProjectNodeEndpoint(nodeID: effectID, portID: "image")
                connections.append(try connection(prepared, input, role: "effect-\(layer.id.rawValue)-\(effectIndex)"))
                prepared = ProjectNodeEndpoint(nodeID: effectID, portID: "image")
            }

            if !layer.masks.isEmpty {
                let maskID = try nodeID("layer-masks", [layer.id.rawValue])
                appendNode(id: maskID, name: "\(layer.name) Masks", kind: .maskStack(layer.masks), row: stackIndex)
                let input = ProjectNodeEndpoint(nodeID: maskID, portID: "image")
                connections.append(try connection(prepared, input, role: "mask-\(layer.id.rawValue)"))
                prepared = ProjectNodeEndpoint(nodeID: maskID, portID: "image")
            }

            let transformID = try nodeID("layer-transform", [layer.id.rawValue])
            appendNode(id: transformID, name: "\(layer.name) Transform", kind: .transform(layer.transform), row: stackIndex)
            let transformInput = ProjectNodeEndpoint(nodeID: transformID, portID: "image")
            connections.append(try connection(prepared, transformInput, role: "transform-\(layer.id.rawValue)"))
            prepared = ProjectNodeEndpoint(nodeID: transformID, portID: "image")

            if let matte = layer.trackMatte, let matteLayer = layerByID[matte.sourceLayerID] {
                let matteSourceID = try nodeID("matte-source", [layer.id.rawValue, matteLayer.id.rawValue])
                let matteSourceKind: ProjectNodeKind
                switch matteLayer.source {
                case .media(let mediaID, _): matteSourceKind = .mediaInput(mediaID: mediaID)
                case .composition(let childID, _): matteSourceKind = .compositionInput(compositionID: childID)
                default: matteSourceKind = .layerInput(layerID: matteLayer.id)
                }
                appendNode(id: matteSourceID, name: "\(matteLayer.name) Matte", kind: matteSourceKind, row: stackIndex + 1)
                let matteID = try nodeID("matte", [layer.id.rawValue])
                appendNode(id: matteID, name: "\(layer.name) Matte", kind: .matte(matte.mode), row: stackIndex)
                connections.append(try connection(prepared, .init(nodeID: matteID, portID: "image"), role: "matte-image-\(layer.id.rawValue)"))
                connections.append(try connection(.init(nodeID: matteSourceID, portID: "image"), .init(nodeID: matteID, portID: "matte"), role: "matte-source-\(layer.id.rawValue)"))
                prepared = .init(nodeID: matteID, portID: "image")
            }

            let mergeID = try nodeID("merge", [layer.id.rawValue])
            appendNode(id: mergeID, name: "Merge \(layer.name)", kind: .merge(layer.blendMode), row: stackIndex)
            connections.append(try connection(accumulator, .init(nodeID: mergeID, portID: "background"), role: "merge-bg-\(layer.id.rawValue)"))
            connections.append(try connection(prepared, .init(nodeID: mergeID, portID: "foreground"), role: "merge-fg-\(layer.id.rawValue)"))
            accumulator = .init(nodeID: mergeID, portID: "image")
        }

        let outputID = try nodeID("output")
        appendNode(id: outputID, name: "Output", kind: .output)
        connections.append(try connection(accumulator, .init(nodeID: outputID, portID: "image"), role: "output"))

        return try ProjectNodeGraph(
            compositionID: compositionID,
            nodes: nodes,
            connections: connections
        ).validatedStructure(requireOutput: true)
    }
}
