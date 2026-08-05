import Foundation

public struct DependencyCycle<Node: Hashable & Sendable>: Error, Equatable, Sendable {
    public let path: [Node]

    public init(path: [Node]) {
        self.path = path
    }
}

private enum DependencyVisitState: Sendable {
    case visiting
    case visited
}

public struct DependencyGraph<Node: Hashable & Sendable>: Sendable {
    private var insertionOrder: [Node] = []
    private var dependencies: [Node: [Node]] = [:]

    public init() {}

    public mutating func addNode(_ node: Node) {
        guard dependencies[node] == nil else { return }
        dependencies[node] = []
        insertionOrder.append(node)
    }

    public mutating func addDependency(from node: Node, dependsOn dependency: Node) {
        addNode(node)
        addNode(dependency)
        guard dependencies[node]?.contains(dependency) == false else { return }
        dependencies[node, default: []].append(dependency)
    }

    public func directDependencies(of node: Node) -> [Node] {
        dependencies[node] ?? []
    }

    public func topologicalOrder() throws -> [Node] {
        var states: [Node: DependencyVisitState] = [:]
        var stack: [Node] = []
        var result: [Node] = []

        func visit(_ node: Node) throws {
            if let state = states[node] {
                switch state {
                case .visited:
                    return
                case .visiting:
                    let cycleStart = stack.firstIndex(of: node) ?? 0
                    throw DependencyCycle(path: Array(stack[cycleStart...]) + [node])
                }
            }

            states[node] = .visiting
            stack.append(node)
            for dependency in dependencies[node] ?? [] {
                try visit(dependency)
            }
            _ = stack.popLast()
            states[node] = .visited
            result.append(node)
        }

        for node in insertionOrder {
            try visit(node)
        }
        return result
    }
}
