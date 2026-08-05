import Foundation

public struct ArchitectureContract: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let guarantee: String

    public init(id: String, title: String, guarantee: String) {
        self.id = id
        self.title = title
        self.guarantee = guarantee
    }
}

public enum CoreArchitectureCatalog {
    public static let contracts: [ArchitectureContract] = [
        ArchitectureContract(id: "exact-time", title: "Exact rational time", guarantee: "Timeline values never depend on floating-point seconds."),
        ArchitectureContract(id: "stable-id", title: "Stable entity identity", guarantee: "Project entities use canonical UUID identifiers across saves and migrations."),
        ArchitectureContract(id: "coordinates", title: "Explicit coordinate spaces", guarantee: "Every geometry conversion names its source and destination space."),
        ArchitectureContract(id: "color", title: "Explicit color metadata", guarantee: "Primaries, transfer function, matrix, and alpha mode travel with every frame."),
        ArchitectureContract(id: "dependency-graph", title: "Acyclic dependency evaluation", guarantee: "Render and composition dependencies are ordered deterministically and cycles fail explicitly."),
        ArchitectureContract(id: "errors", title: "Structured errors", guarantee: "Every subsystem emits stable domains, codes, messages, and diagnostic context.")
    ]
}
