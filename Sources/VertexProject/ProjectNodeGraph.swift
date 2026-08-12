import Foundation
import VertexCore

public enum ProjectNodeValueType: String, Codable, CaseIterable, Hashable, Sendable {
    case image
    case mask
    case scalar
    case vector2
    case color
    case boolean

    public var canonicalPortID: String {
        switch self {
        case .image: "image"
        case .mask: "mask"
        case .scalar: "value"
        case .vector2: "vector"
        case .color: "color"
        case .boolean: "boolean"
        }
    }
}

public enum ProjectNodePortDirection: String, Codable, Hashable, Sendable {
    case input
    case output
}

public struct ProjectNodePort: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var valueType: ProjectNodeValueType
    public var direction: ProjectNodePortDirection
    public var allowsMultipleConnections: Bool

    public init(
        id: String,
        label: String,
        valueType: ProjectNodeValueType,
        direction: ProjectNodePortDirection,
        allowsMultipleConnections: Bool = false
    ) {
        self.id = id
        self.label = label
        self.valueType = valueType
        self.direction = direction
        self.allowsMultipleConnections = allowsMultipleConnections
    }
}

public struct ProjectNodePosition: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = ProjectNodePosition(x: 0, y: 0)

    public func validated() throws -> Self {
        guard x.isFinite, y.isFinite else {
            throw ProjectError.invalidValue("Node positions must be finite.")
        }
        return self
    }
}

public struct ProjectNodeEndpoint: Codable, Equatable, Hashable, Sendable {
    public var nodeID: VertexID
    public var portID: String

    public init(nodeID: VertexID, portID: String) {
        self.nodeID = nodeID
        self.portID = portID
    }
}

public struct ProjectNodeParameterAddress: Codable, Equatable, Hashable, Sendable {
    public var nodeID: VertexID
    public var parameterID: String

    public init(nodeID: VertexID, parameterID: String) {
        self.nodeID = nodeID
        self.parameterID = parameterID
    }
}

public struct ProjectNodeConnection: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var from: ProjectNodeEndpoint
    public var to: ProjectNodeEndpoint

    public init(id: VertexID = VertexID(), from: ProjectNodeEndpoint, to: ProjectNodeEndpoint) {
        self.id = id
        self.from = from
        self.to = to
    }
}

public struct ProjectNodeParameterLink: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var source: ProjectNodeEndpoint
    public var target: ProjectNodeParameterAddress
    public var scale: Double
    public var offset: Double

    public init(
        id: VertexID = VertexID(),
        source: ProjectNodeEndpoint,
        target: ProjectNodeParameterAddress,
        scale: Double = 1,
        offset: Double = 0
    ) {
        self.id = id
        self.source = source
        self.target = target
        self.scale = scale
        self.offset = offset
    }
}

public enum ProjectNodeMathOperation: String, Codable, CaseIterable, Sendable {
    case add
    case subtract
    case multiply
    case divide
    case minimum
    case maximum
}

public enum ProjectNodeUtility: Codable, Equatable, Sendable {
    case constant(Double)
    case clamp(minimum: Double, maximum: Double)
    case remap(inputMinimum: Double, inputMaximum: Double, outputMinimum: Double, outputMaximum: Double)
    case boolean(Bool)

    public func validated() throws -> Self {
        switch self {
        case .constant(let value):
            guard value.isFinite else { throw ProjectError.invalidValue("Node constants must be finite.") }
        case .clamp(let minimum, let maximum):
            guard minimum.isFinite, maximum.isFinite, minimum <= maximum else {
                throw ProjectError.invalidValue("Clamp bounds must be finite and ordered.")
            }
        case .remap(let inputMinimum, let inputMaximum, let outputMinimum, let outputMaximum):
            let values = [inputMinimum, inputMaximum, outputMinimum, outputMaximum]
            guard values.allSatisfy(\.isFinite), inputMinimum != inputMaximum else {
                throw ProjectError.invalidValue("Remap values must be finite and the input range must be nonzero.")
            }
        case .boolean:
            break
        }
        return self
    }
}

public enum ProjectNodeKind: Codable, Equatable, Sendable {
    case mediaInput(mediaID: VertexID)
    case layerInput(layerID: VertexID)
    case compositionInput(compositionID: VertexID)
    case solidColor(ProjectRGBAColor)
    case effect(ProjectEffect)
    case maskStack([ProjectMask])
    case matte(ProjectTrackMatteMode)
    case merge(LayerBlendMode)
    case transform(LayerTransform)
    case math(ProjectNodeMathOperation)
    case utility(ProjectNodeUtility)
    case macro(macroID: VertexID)
    case macroInput(ProjectNodeValueType)
    case macroOutput(ProjectNodeValueType)
    case output

    public var ports: [ProjectNodePort] {
        func input(_ id: String, _ label: String, _ type: ProjectNodeValueType) -> ProjectNodePort {
            ProjectNodePort(id: id, label: label, valueType: type, direction: .input)
        }
        func output(_ id: String, _ label: String, _ type: ProjectNodeValueType) -> ProjectNodePort {
            ProjectNodePort(id: id, label: label, valueType: type, direction: .output, allowsMultipleConnections: true)
        }

        switch self {
        case .mediaInput, .layerInput, .compositionInput, .solidColor:
            return [output("image", "Image", .image)]
        case .effect, .maskStack, .transform, .macro:
            return [input("image", "Image", .image), output("image", "Image", .image)]
        case .matte:
            return [
                input("image", "Image", .image),
                input("matte", "Matte", .image),
                output("image", "Image", .image)
            ]
        case .merge:
            return [
                input("background", "Background", .image),
                input("foreground", "Foreground", .image),
                output("image", "Image", .image)
            ]
        case .math:
            return [
                input("a", "A", .scalar),
                input("b", "B", .scalar),
                output("value", "Value", .scalar)
            ]
        case .utility(let utility):
            switch utility {
            case .constant:
                return [output("value", "Value", .scalar)]
            case .clamp, .remap:
                return [input("value", "Value", .scalar), output("value", "Value", .scalar)]
            case .boolean:
                return [output("boolean", "Boolean", .boolean)]
            }
        case .macroInput(let type):
            return [output(type.canonicalPortID, "Input", type)]
        case .macroOutput(let type):
            return [input(type.canonicalPortID, "Output", type)]
        case .output:
            return [input("image", "Image", .image)]
        }
    }

    public func validated() throws -> Self {
        switch self {
        case .solidColor(let color):
            _ = try color.validated()
        case .effect(let effect):
            _ = try effect.validated()
        case .maskStack(let masks):
            _ = try masks.validatedMasks()
        case .transform(let transform):
            _ = try transform.validated()
        case .utility(let utility):
            _ = try utility.validated()
        default:
            break
        }
        return self
    }
}

public struct ProjectNode: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var name: String
    public var kind: ProjectNodeKind
    public var position: ProjectNodePosition
    public var enabled: Bool
    public var bypassed: Bool

    public init(
        id: VertexID = VertexID(),
        name: String,
        kind: ProjectNodeKind,
        position: ProjectNodePosition = .zero,
        enabled: Bool = true,
        bypassed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.position = position
        self.enabled = enabled
        self.bypassed = bypassed
    }

    public var ports: [ProjectNodePort] { kind.ports }

    public func port(id: String, direction: ProjectNodePortDirection) -> ProjectNodePort? {
        ports.first { $0.id == id && $0.direction == direction }
    }

    public func validated() throws -> Self {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.invalidValue("Node names must not be empty.")
        }
        _ = try position.validated()
        _ = try kind.validated()
        return self
    }
}

public struct ProjectNodeGroup: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var name: String
    public var nodeIDs: [VertexID]
    public var collapsed: Bool

    public init(id: VertexID = VertexID(), name: String, nodeIDs: [VertexID], collapsed: Bool = false) {
        self.id = id
        self.name = name
        self.nodeIDs = nodeIDs
        self.collapsed = collapsed
    }
}

public struct ProjectNodeMacro: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var name: String
    public var nodes: [ProjectNode]
    public var connections: [ProjectNodeConnection]
    public var parameterLinks: [ProjectNodeParameterLink]

    public init(
        id: VertexID = VertexID(),
        name: String,
        nodes: [ProjectNode],
        connections: [ProjectNodeConnection],
        parameterLinks: [ProjectNodeParameterLink] = []
    ) {
        self.id = id
        self.name = name
        self.nodes = nodes
        self.connections = connections
        self.parameterLinks = parameterLinks
    }

    public func validated() throws -> Self {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.invalidValue("Node macro names must not be empty.")
        }
        let graph = ProjectNodeGraph(
            compositionID: VertexID(rawValue: "00000000-0000-0000-0000-000000000018"),
            nodes: nodes,
            connections: connections,
            parameterLinks: parameterLinks
        )
        _ = try graph.validatedStructure(requireOutput: false)
        guard nodes.contains(where: { if case .macroInput = $0.kind { return true }; return false }),
              nodes.contains(where: { if case .macroOutput = $0.kind { return true }; return false }) else {
            throw ProjectError.invalidValue("Node macros require at least one macro input and output.")
        }
        return self
    }
}

public struct ProjectNodeEvaluationPlan: Equatable, Sendable {
    public var orderedNodes: [ProjectNode]
    public var inactiveNodeIDs: [VertexID]

    public init(orderedNodes: [ProjectNode], inactiveNodeIDs: [VertexID]) {
        self.orderedNodes = orderedNodes
        self.inactiveNodeIDs = inactiveNodeIDs
    }
}

public struct ProjectNodeGraph: Codable, Equatable, Sendable {
    public var compositionID: VertexID
    public var nodes: [ProjectNode]
    public var connections: [ProjectNodeConnection]
    public var parameterLinks: [ProjectNodeParameterLink]
    public var groups: [ProjectNodeGroup]
    public var macros: [ProjectNodeMacro]

    public init(
        compositionID: VertexID,
        nodes: [ProjectNode],
        connections: [ProjectNodeConnection] = [],
        parameterLinks: [ProjectNodeParameterLink] = [],
        groups: [ProjectNodeGroup] = [],
        macros: [ProjectNodeMacro] = []
    ) {
        self.compositionID = compositionID
        self.nodes = nodes
        self.connections = connections
        self.parameterLinks = parameterLinks
        self.groups = groups
        self.macros = macros
    }

    @discardableResult
    public func validatedStructure(requireOutput: Bool = true) throws -> Self {
        guard Set(nodes.map(\.id)).count == nodes.count else { throw ProjectError.duplicateIdentity("node") }
        guard Set(connections.map(\.id)).count == connections.count else { throw ProjectError.duplicateIdentity("node connection") }
        guard Set(parameterLinks.map(\.id)).count == parameterLinks.count else { throw ProjectError.duplicateIdentity("node parameter link") }
        guard Set(groups.map(\.id)).count == groups.count else { throw ProjectError.duplicateIdentity("node group") }
        guard Set(macros.map(\.id)).count == macros.count else { throw ProjectError.duplicateIdentity("node macro") }

        for node in nodes { _ = try node.validated() }
        for macro in macros { _ = try macro.validated() }

        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let macroIDs = Set(macros.map(\.id))
        for node in nodes {
            if case .macro(let macroID) = node.kind, !macroIDs.contains(macroID) {
                throw ProjectError.invalidValue("Node references a missing macro: \(macroID.rawValue).")
            }
        }

        var occupiedSingleInputs = Set<ProjectNodeEndpoint>()
        for connection in connections {
            guard connection.from.nodeID != connection.to.nodeID else {
                throw ProjectError.invalidValue("Node connections may not connect a node to itself.")
            }
            guard let source = byID[connection.from.nodeID], let target = byID[connection.to.nodeID] else {
                throw ProjectError.invalidValue("Node connection references a missing node.")
            }
            guard let sourcePort = source.port(id: connection.from.portID, direction: .output),
                  let targetPort = target.port(id: connection.to.portID, direction: .input) else {
                throw ProjectError.invalidValue("Node connection references an invalid port or port direction.")
            }
            guard sourcePort.valueType == targetPort.valueType else {
                throw ProjectError.invalidValue("Node connection port types are incompatible.")
            }
            if !targetPort.allowsMultipleConnections {
                guard occupiedSingleInputs.insert(connection.to).inserted else {
                    throw ProjectError.invalidValue("A single-input node port has more than one connection.")
                }
            }
        }

        var occupiedParameterTargets = Set<ProjectNodeParameterAddress>()
        for link in parameterLinks {
            guard link.scale.isFinite, link.offset.isFinite else {
                throw ProjectError.invalidValue("Node parameter-link scale and offset must be finite.")
            }
            guard link.source.nodeID != link.target.nodeID else {
                throw ProjectError.invalidValue("A node parameter link may not target its own source node.")
            }
            guard let source = byID[link.source.nodeID],
                  let sourcePort = source.port(id: link.source.portID, direction: .output),
                  sourcePort.valueType == .scalar else {
                throw ProjectError.invalidValue("Node parameter links require a scalar output source.")
            }
            guard let target = byID[link.target.nodeID], target.acceptsLinkedScalarParameter(link.target.parameterID) else {
                throw ProjectError.invalidValue("Node parameter link targets an unsupported parameter: \(link.target.parameterID).")
            }
            guard occupiedParameterTargets.insert(link.target).inserted else {
                throw ProjectError.invalidValue("A node parameter may have only one incoming link.")
            }
        }

        let nodeIDs = Set(nodes.map(\.id))
        for group in groups {
            guard !group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ProjectError.invalidValue("Node group names must not be empty.")
            }
            guard Set(group.nodeIDs).count == group.nodeIDs.count, Set(group.nodeIDs).isSubset(of: nodeIDs) else {
                throw ProjectError.invalidValue("Node groups must reference unique nodes in the graph.")
            }
        }

        let outputCount = nodes.reduce(into: 0) { count, node in
            if case .output = node.kind { count += 1 }
        }
        if requireOutput, outputCount != 1 {
            throw ProjectError.invalidValue("A compositing node graph requires exactly one Output node.")
        }
        if outputCount > 1 {
            throw ProjectError.invalidValue("A compositing node graph may contain at most one Output node.")
        }

        _ = try topologicalOrder(activeNodeIDs: nodeIDs)
        return self
    }

    public func evaluationPlan() throws -> ProjectNodeEvaluationPlan {
        _ = try validatedStructure(requireOutput: true)
        guard let output = nodes.first(where: { if case .output = $0.kind { return true }; return false }) else {
            throw ProjectError.invalidValue("A compositing node graph requires an Output node.")
        }

        let incoming = dependencyMap()
        var active = Set<VertexID>()
        var stack: [VertexID] = [output.id]
        while let current = stack.popLast() {
            guard active.insert(current).inserted else { continue }
            stack.append(contentsOf: incoming[current] ?? [])
        }

        let orderedIDs = try topologicalOrder(activeNodeIDs: active)
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let ordered = orderedIDs.compactMap { byID[$0] }
        let inactive = nodes.map(\.id).filter { !active.contains($0) }
        return ProjectNodeEvaluationPlan(orderedNodes: ordered, inactiveNodeIDs: inactive)
    }

    public func node(id: VertexID) -> ProjectNode? {
        nodes.first { $0.id == id }
    }

    public func incomingConnection(nodeID: VertexID, portID: String) -> ProjectNodeConnection? {
        connections.first { $0.to.nodeID == nodeID && $0.to.portID == portID }
    }

    private func dependencyMap() -> [VertexID: [VertexID]] {
        var result: [VertexID: [VertexID]] = [:]
        for node in nodes { result[node.id] = [] }
        for connection in connections { result[connection.to.nodeID, default: []].append(connection.from.nodeID) }
        for link in parameterLinks { result[link.target.nodeID, default: []].append(link.source.nodeID) }
        return result
    }

    private func topologicalOrder(activeNodeIDs: Set<VertexID>) throws -> [VertexID] {
        let incoming = dependencyMap()
        var remaining = activeNodeIDs
        var emitted = Set<VertexID>()
        var ordered: [VertexID] = []
        ordered.reserveCapacity(activeNodeIDs.count)

        while !remaining.isEmpty {
            var progressed = false
            for node in nodes where remaining.contains(node.id) {
                let dependencies = (incoming[node.id] ?? []).filter { activeNodeIDs.contains($0) }
                if dependencies.allSatisfy({ emitted.contains($0) }) {
                    ordered.append(node.id)
                    emitted.insert(node.id)
                    remaining.remove(node.id)
                    progressed = true
                }
            }
            guard progressed else {
                throw ProjectError.invalidValue("Compositing node graph contains a dependency cycle.")
            }
        }
        return ordered
    }
}

private extension ProjectNode {
    func acceptsLinkedScalarParameter(_ parameterID: String) -> Bool {
        switch kind {
        case .effect(let effect):
            guard let parameter = effect.parameter(id: parameterID) else { return false }
            if case .scalar = parameter.value { return true }
            return false
        case .transform:
            return ["positionX", "positionY", "anchorX", "anchorY", "scaleX", "scaleY", "rotationDegrees", "opacity"].contains(parameterID)
        case .utility:
            return ["minimum", "maximum", "inputMinimum", "inputMaximum", "outputMinimum", "outputMaximum"].contains(parameterID)
        default:
            return false
        }
    }
}
