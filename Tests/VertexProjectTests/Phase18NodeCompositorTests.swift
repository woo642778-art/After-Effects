import Testing
import VertexCore
@testable import VertexProject

@Test("V18 free node graph evaluates only output ancestors while preserving inactive workspace nodes")
func v18FreeGraphEvaluationPlan() throws {
    let source = ProjectNode(name: "Media", kind: .mediaInput(mediaID: VertexID(rawValue: "10000000-0000-0000-0000-000000000001")), position: .init(x: 40, y: 80))
    let effect = ProjectNode(name: "Exposure", kind: .effect(ProjectEffect.makeDefault(.exposure)), position: .init(x: 300, y: 80))
    let output = ProjectNode(name: "Output", kind: .output, position: .init(x: 560, y: 80))
    let inactive = ProjectNode(name: "Unused Constant", kind: .utility(.constant(0.5)), position: .init(x: 40, y: 360))
    let graph = ProjectNodeGraph(
        compositionID: VertexID(rawValue: "20000000-0000-0000-0000-000000000001"),
        nodes: [source, effect, output, inactive],
        connections: [
            ProjectNodeConnection(from: .init(nodeID: source.id, portID: "image"), to: .init(nodeID: effect.id, portID: "image")),
            ProjectNodeConnection(from: .init(nodeID: effect.id, portID: "image"), to: .init(nodeID: output.id, portID: "image"))
        ]
    )

    let plan = try graph.evaluationPlan()
    #expect(plan.orderedNodes.map(\.id) == [source.id, effect.id, output.id])
    #expect(plan.inactiveNodeIDs == [inactive.id])
}

@Test("V18 node graph rejects cycles and incompatible port types")
func v18GraphValidationRejectsInvalidConnections() throws {
    let source = ProjectNode(name: "Media", kind: .mediaInput(mediaID: VertexID()), position: .zero)
    let transform = ProjectNode(name: "Transform", kind: .transform(.identity), position: .init(x: 200, y: 0))
    let output = ProjectNode(name: "Output", kind: .output, position: .init(x: 400, y: 0))

    let cyclic = ProjectNodeGraph(
        compositionID: VertexID(),
        nodes: [source, transform, output],
        connections: [
            .init(from: .init(nodeID: source.id, portID: "image"), to: .init(nodeID: transform.id, portID: "image")),
            .init(from: .init(nodeID: transform.id, portID: "image"), to: .init(nodeID: output.id, portID: "image")),
            .init(from: .init(nodeID: transform.id, portID: "image"), to: .init(nodeID: transform.id, portID: "image"))
        ]
    )
    #expect(throws: ProjectError.self) { try cyclic.evaluationPlan() }

    let scalar = ProjectNode(name: "Scalar", kind: .utility(.constant(1)), position: .zero)
    let incompatible = ProjectNodeGraph(
        compositionID: VertexID(),
        nodes: [scalar, output],
        connections: [
            .init(from: .init(nodeID: scalar.id, portID: "value"), to: .init(nodeID: output.id, portID: "image"))
        ]
    )
    #expect(throws: ProjectError.self) { try incompatible.evaluationPlan() }
}

@Test("V18 parameter links validate scalar sources, effect targets, and acyclic dependencies")
func v18ParameterLinkValidation() throws {
    let constant = ProjectNode(name: "Amount", kind: .utility(.constant(0.75)), position: .zero)
    let effect = ProjectNode(name: "Exposure", kind: .effect(ProjectEffect.makeDefault(.exposure)), position: .init(x: 220, y: 0))
    let link = ProjectNodeParameterLink(
        source: .init(nodeID: constant.id, portID: "value"),
        target: .init(nodeID: effect.id, parameterID: "amount"),
        scale: 2,
        offset: -0.5
    )
    let graph = ProjectNodeGraph(compositionID: VertexID(), nodes: [constant, effect], parameterLinks: [link])
    _ = try graph.validatedStructure(requireOutput: false)
}

@Test("V18 node macros and groups remain deterministic Codable project data")
func v18MacrosGroupsRoundTrip() throws {
    let macroInput = ProjectNode(name: "Macro Input", kind: .macroInput(.image), position: .zero)
    let macroOutput = ProjectNode(name: "Macro Output", kind: .macroOutput(.image), position: .init(x: 200, y: 0))
    let macro = ProjectNodeMacro(
        name: "Passthrough",
        nodes: [macroInput, macroOutput],
        connections: [.init(from: .init(nodeID: macroInput.id, portID: "image"), to: .init(nodeID: macroOutput.id, portID: "image"))]
    )
    _ = try macro.validated()

    let group = ProjectNodeGroup(name: "Utility Group", nodeIDs: [macroInput.id, macroOutput.id], collapsed: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(group)
    #expect(try JSONDecoder().decode(ProjectNodeGroup.self, from: data) == group)
}
