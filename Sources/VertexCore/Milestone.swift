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
        title: "Layers and Compositions",
        status: .implemented,
        deliverables: [
            "Schema 2 project compositions, stable layer identities, deterministic migration, and durable command history",
            "Real multi-source VertexRender DAG with explicit top-to-bottom Z-order and exact composition time",
            "Metal Normal, Add, Multiply, and Screen blending with premultiplied alpha and adjustment layers",
            "Basic nested-composition rendering with source offsets, parent In/Out ranges, cycle checks, and resource limits",
            "Functional exact-frame composition preview, ordered layer list, inspector, media relinking, Undo, Redo, autosave, and recovery",
            "Versioned After Effects 6.0.0 unsigned IPA artifact"
        ],
        sourceAdoptions: [
            SourceAdoption(
                id: "foundation",
                repository: "Apple Foundation",
                license: "Apple platform SDK and Swift core libraries",
                mode: .wrappedDependency,
                purpose: "Schema-aware package migration, deterministic persistence, file access, recovery, and export adapters"
            ),
            SourceAdoption(
                id: "avfoundation",
                repository: "Apple AVFoundation",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "Exact media-frame resolution behind the VertexComposition frame-resolver protocol"
            ),
            SourceAdoption(
                id: "metal",
                repository: "Apple Metal",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "Multi-source layer, blend, adjustment, and nested-composition GPU execution"
            ),
            SourceAdoption(
                id: "metalpetal",
                repository: "MetalPetal/MetalPetal",
                license: "MIT",
                mode: .researchOnly,
                purpose: "Audited future filter backend candidate; not linked into Phase 6"
            ),
            SourceAdoption(
                id: "videoio",
                repository: "MetalPetal/VideoIO",
                license: "MIT",
                mode: .researchOnly,
                purpose: "Audited future timed playback and video-export candidate; not linked into Phase 6"
            ),
            SourceAdoption(
                id: "videolab",
                repository: "ruanjx/VideoLab",
                license: "MIT",
                mode: .designReference,
                purpose: "Layer and composition architecture reference only; no source copied"
            ),
            SourceAdoption(
                id: "minicut",
                repository: "fwcd/mini-cut",
                license: "GPL-3.0",
                mode: .behavioralReference,
                purpose: "Timeline interaction research only; no source copied into the product"
            )
        ],
        artifactPolicy: "Phase 6 publishes After-Effects-6.0.0-unsigned.ipa. Every later successful phase increments the major version to match its phase number. The IPA remains unsigned until user-provided signing credentials are applied."
    )
}
