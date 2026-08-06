import Foundation
import VertexCore
import VertexMedia

public enum RenderNodeKind: Codable, Equatable, Sendable {
    case source(PortableImage)
    case operations([RenderOperation])
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

public struct RenderGraph: Codable, Equatable, Sendable {
    public let nodes: [RenderNode]

    public init(nodes: [RenderNode]) {
        self.nodes = nodes
    }

    public func validatedNodes() throws -> [RenderNode] {
        guard !nodes.isEmpty else { throw RenderError.invalidGraph("The graph is empty.") }

        let grouped = Dictionary(grouping: nodes, by: \.id)
        guard grouped.values.allSatisfy({ $0.count == 1 }) else {
            throw RenderError.invalidGraph("Node identifiers must be unique.")
        }

        let outputNodes = nodes.filter {
            if case .output = $0.kind { return true }
            return false
        }
        guard outputNodes.count == 1 else {
            throw RenderError.invalidGraph("The graph must contain exactly one output node.")
        }

        let sourceNodes = nodes.filter {
            if case .source = $0.kind { return true }
            return false
        }
        guard sourceNodes.count == 1 else {
            throw RenderError.invalidGraph("Phase 4 graphs must contain exactly one source node.")
        }

        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        for node in nodes {
            for dependency in node.dependencies where nodeByID[dependency] == nil {
                throw RenderError.missingNode(dependency.rawValue)
            }
            switch node.kind {
            case .source(let image):
                guard node.dependencies.isEmpty else {
                    throw RenderError.invalidGraph("Source nodes cannot have dependencies.")
                }
                guard !image.data.isEmpty else {
                    throw RenderError.unsupportedImage("Source image data is empty.")
                }
            case .operations(let operations):
                guard node.dependencies.count == 1 else {
                    throw RenderError.invalidGraph("An operation node must have exactly one dependency.")
                }
                for operation in operations { _ = try operation.validated() }
            case .output:
                guard node.dependencies.count == 1 else {
                    throw RenderError.invalidGraph("The output node must have exactly one dependency.")
                }
            }
        }

        enum VisitState { case visiting, visited }
        var states: [VertexID: VisitState] = [:]
        var ordered: [RenderNode] = []
        var stack: [VertexID] = []

        func visit(_ node: RenderNode) throws {
            if let state = states[node.id] {
                switch state {
                case .visited:
                    return
                case .visiting:
                    let start = stack.firstIndex(of: node.id) ?? 0
                    let cycleIDs = Array(stack[start...]) + [node.id]
                    throw RenderError.cycle(cycleIDs.map(\.rawValue))
                }
            }

            states[node.id] = .visiting
            stack.append(node.id)
            for dependencyID in node.dependencies.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let dependency = nodeByID[dependencyID] else {
                    throw RenderError.missingNode(dependencyID.rawValue)
                }
                try visit(dependency)
            }
            _ = stack.popLast()
            states[node.id] = .visited
            ordered.append(node)
        }

        for node in nodes.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            try visit(node)
        }

        return ordered
    }

    public func sourceImage() throws -> PortableImage {
        let validated = try validatedNodes()
        guard let image = validated.compactMap({ node -> PortableImage? in
            if case .source(let image) = node.kind { return image }
            return nil
        }).first else {
            throw RenderError.invalidGraph("No source image was found.")
        }
        return image
    }

    public func flattenedOperations() throws -> [RenderOperation] {
        try validatedNodes().flatMap { node -> [RenderOperation] in
            if case .operations(let operations) = node.kind { return operations }
            return []
        }
    }
}
