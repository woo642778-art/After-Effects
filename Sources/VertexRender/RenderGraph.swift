import Foundation
import VertexCore
import VertexMedia

public enum RenderNodeKind: Codable, Equatable, Sendable {
    case source(PortableImage)
    case solidColor(RenderRGBAColor)
    case operations([RenderOperation])
    case mask(RenderMaskStack)
    case matte(RenderTrackMatteMode)
    case composite(RenderBlendMode)
    case adjustment([RenderOperation], mix: Double)
    case output
}

public struct RenderNode: Codable, Equatable, Sendable, Identifiable {
    public let id: VertexID
    public let dependencies: [VertexID]
    public let kind: RenderNodeKind

    public init(id: VertexID = VertexID(), dependencies: [VertexID], kind: RenderNodeKind) {
        self.id = id
        self.dependencies = dependencies
        self.kind = kind
    }
}

public struct RenderEvaluationPlan: Equatable, Sendable {
    public var orderedNodes: [RenderNode]
    public var outputNodeID: VertexID
    public var consumerCounts: [VertexID: Int]

    public init(orderedNodes: [RenderNode], outputNodeID: VertexID, consumerCounts: [VertexID: Int]) {
        self.orderedNodes = orderedNodes
        self.outputNodeID = outputNodeID
        self.consumerCounts = consumerCounts
    }
}

public struct RenderGraph: Codable, Equatable, Sendable {
    public let nodes: [RenderNode]

    public init(nodes: [RenderNode]) {
        self.nodes = nodes
    }

    public func evaluationPlan() throws -> RenderEvaluationPlan {
        guard !nodes.isEmpty else { throw RenderError.invalidGraph("The graph is empty.") }

        let grouped = Dictionary(grouping: nodes, by: \.id)
        guard grouped.values.allSatisfy({ $0.count == 1 }) else {
            throw RenderError.invalidGraph("Node identifiers must be unique.")
        }

        let outputNodes = nodes.filter {
            if case .output = $0.kind { return true }
            return false
        }
        guard outputNodes.count == 1, let output = outputNodes.first else {
            throw RenderError.invalidGraph("The graph must contain exactly one output node.")
        }

        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        for node in nodes {
            for dependency in node.dependencies where nodeByID[dependency] == nil {
                throw RenderError.missingNode(dependency.rawValue)
            }
            try validateArityAndValues(node)
        }

        enum VisitState { case visiting, visited }
        var states: [VertexID: VisitState] = [:]
        var ordered: [RenderNode] = []
        var stack: [VertexID] = []

        func visit(_ node: RenderNode) throws {
            if let state = states[node.id] {
                switch state {
                case .visited: return
                case .visiting:
                    let start = stack.firstIndex(of: node.id) ?? 0
                    let cycleIDs = Array(stack[start...]) + [node.id]
                    throw RenderError.cycle(cycleIDs.map(\.rawValue))
                }
            }
            states[node.id] = .visiting
            stack.append(node.id)
            for dependencyID in node.dependencies {
                guard let dependency = nodeByID[dependencyID] else {
                    throw RenderError.missingNode(dependencyID.rawValue)
                }
                try visit(dependency)
            }
            _ = stack.popLast()
            states[node.id] = .visited
            ordered.append(node)
        }

        try visit(output)
        guard ordered.count == nodes.count else {
            let disconnected = Set(nodes.map(\.id)).subtracting(ordered.map(\.id))
            throw RenderError.invalidGraph(
                "Disconnected nodes are not allowed: \(disconnected.map(\.rawValue).sorted().joined(separator: ", "))."
            )
        }

        var consumers: [VertexID: Int] = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, 0) })
        for node in nodes {
            for dependency in node.dependencies {
                consumers[dependency, default: 0] += 1
            }
        }
        return RenderEvaluationPlan(
            orderedNodes: ordered,
            outputNodeID: output.id,
            consumerCounts: consumers
        )
    }

    public func validatedNodes() throws -> [RenderNode] {
        try evaluationPlan().orderedNodes
    }

    @available(*, deprecated, message: "Use evaluationPlan() and node-local execution")
    public func sourceImage() throws -> PortableImage {
        let images = try evaluationPlan().orderedNodes.compactMap { node -> PortableImage? in
            if case .source(let image) = node.kind { return image }
            return nil
        }
        guard let first = images.first else {
            throw RenderError.invalidGraph("No image source was found.")
        }
        return first
    }

    @available(*, deprecated, message: "Use evaluationPlan() and node-local execution")
    public func flattenedOperations() throws -> [RenderOperation] {
        try evaluationPlan().orderedNodes.flatMap { node -> [RenderOperation] in
            if case .operations(let operations) = node.kind { return operations }
            return []
        }
    }

    private func validateArityAndValues(_ node: RenderNode) throws {
        switch node.kind {
        case .source(let image):
            guard node.dependencies.isEmpty else {
                throw RenderError.invalidGraph("Source nodes cannot have dependencies.")
            }
            guard !image.data.isEmpty else {
                throw RenderError.unsupportedImage("Source image data is empty.")
            }

        case .solidColor(let color):
            guard node.dependencies.isEmpty else {
                throw RenderError.invalidGraph("Solid-color nodes cannot have dependencies.")
            }
            _ = try color.validated()

        case .operations(let operations):
            guard node.dependencies.count == 1 else {
                throw RenderError.invalidGraph("An operation node must have exactly one dependency.")
            }
            for operation in operations { _ = try operation.validated() }

        case .mask(let stack):
            guard node.dependencies.count == 1 else {
                throw RenderError.invalidGraph("A mask node must have exactly one source dependency.")
            }
            _ = try stack.validated()

        case .matte:
            guard node.dependencies.count == 2 else {
                throw RenderError.invalidGraph("A matte node must have ordered [source, matte] dependencies.")
            }
            guard node.dependencies[0] != node.dependencies[1] else {
                throw RenderError.invalidGraph("Track-matte source and target dependencies must be different nodes.")
            }

        case .composite:
            guard node.dependencies.count == 2 else {
                throw RenderError.invalidGraph("A composite node must have ordered [backdrop, source] dependencies.")
            }
            guard node.dependencies[0] != node.dependencies[1] else {
                throw RenderError.invalidGraph("Composite backdrop and source must be different nodes.")
            }

        case .adjustment(let operations, let mix):
            guard node.dependencies.count == 1 else {
                throw RenderError.invalidGraph("An adjustment node must have exactly one dependency.")
            }
            guard mix.isFinite, (0...1).contains(mix) else {
                throw RenderError.invalidRequest("Adjustment mix must be finite and within 0...1.")
            }
            for operation in operations { _ = try operation.validated() }

        case .output:
            guard node.dependencies.count == 1 else {
                throw RenderError.invalidGraph("The output node must have exactly one dependency.")
            }
        }
    }
}
