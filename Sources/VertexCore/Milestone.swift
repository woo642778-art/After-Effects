import Foundation

public enum MilestoneStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case inProgress
    case implemented
    case validated
}

public enum AdoptionMode: String, Codable, CaseIterable, Sendable {
    case directDependency
    case wrappedDependency
    case selectivePort
    case designReference
    case behavioralReference
    case researchOnly
    case rejected
}

public struct SourceAdoption: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let repository: String
    public let license: String
    public let mode: AdoptionMode
    public let purpose: String

    public init(id: String, repository: String, license: String, mode: AdoptionMode, purpose: String) {
        self.id = id
        self.repository = repository
        self.license = license
        self.mode = mode
        self.purpose = purpose
    }
}

public struct Milestone: Codable, Equatable, Sendable {
    public let number: Int
    public let title: String
    public let status: MilestoneStatus
    public let deliverables: [String]
    public let sourceAdoptions: [SourceAdoption]
    public let artifactPolicy: String

    public init(number: Int, title: String, status: MilestoneStatus, deliverables: [String], sourceAdoptions: [SourceAdoption], artifactPolicy: String) {
        precondition(number >= 0, "Milestone number must be non-negative")
        precondition(!title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Milestone title must not be empty")
        self.number = number
        self.title = title
        self.status = status
        self.deliverables = deliverables
        self.sourceAdoptions = sourceAdoptions
        self.artifactPolicy = artifactPolicy
    }
}

public enum MilestoneCatalog {
    public static let current = Milestone(
        number: 6,
        title: "Layers, Compositions, and Multi-Source Rendering",
        status: .implemented,
        deliverables: [
            "Canonical schema 2 projects with stable composition and layer identities",
            "Session-only Undo and Redo for composition and layer editing with no persisted command history",
            "Deterministic schema 1 to 2 migration and non-destructive legacy schema 2 import",
            "Multi-source backend-neutral render DAG with Normal, Add, Multiply, Screen, adjustment layers, and nested compositions",
            "Exact-frame composition preview and PNG output through the shared Metal render path",
            "Versioned After Effects 6.0.0 unsigned IPA artifact"
        ],
        sourceAdoptions: [
            SourceAdoption(
                id: "foundation",
                repository: "Apple Foundation",
                license: "Apple platform SDK and Swift core libraries",
                mode: .wrappedDependency,
                purpose: "Canonical project packages, deterministic serialization, and atomic snapshot persistence"
            ),
            SourceAdoption(
                id: "avfoundation",
                repository: "Apple AVFoundation",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "Exact-time media frame resolution behind Vertex media adapters"
            ),
            SourceAdoption(
                id: "metal",
                repository: "Apple Metal",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "Multi-node composition execution, blending, adjustment processing, and preview output"
            ),
            SourceAdoption(
                id: "metalpetal",
                repository: "MetalPetal/MetalPetal",
                license: "MIT",
                mode: .researchOnly,
                purpose: "Filter and GPU architecture research only; not linked into Phase 6"
            ),
            SourceAdoption(
                id: "videolab",
                repository: "ruanjx/VideoLab",
                license: "MIT",
                mode: .designReference,
                purpose: "Layer and composition architecture study without source copying"
            )
        ],
        artifactPolicy: "Phase 6 publishes After-Effects-6.0.0-unsigned.ipa after portable, Simulator, native persistence, Metal pixel, Release, and artifact inspection gates pass. The IPA remains unsigned until signing credentials are supplied."
    )
}
