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

    public init(
        id: String,
        repository: String,
        license: String,
        mode: AdoptionMode,
        purpose: String
    ) {
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

    public init(
        number: Int,
        title: String,
        status: MilestoneStatus,
        deliverables: [String],
        sourceAdoptions: [SourceAdoption],
        artifactPolicy: String
    ) {
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
        number: 2,
        title: "Core Architecture and Product Identity",
        status: .implemented,
        deliverables: [
            "Exact rational timeline time with explicit rescaling and overflow handling",
            "Stable UUID entity identity and structured subsystem errors",
            "Explicit coordinate-space conversion and color metadata contracts",
            "Deterministic dependency ordering with cycle detection",
            "After Effects app identity, generated Ae icon, startup loading, and Made by Maze attribution",
            "Once-per-installation Telegram promotion for the AE Motion channel"
        ],
        sourceAdoptions: [
            SourceAdoption(
                id: "metalpetal",
                repository: "MetalPetal/MetalPetal",
                license: "MIT",
                mode: .directDependency,
                purpose: "GPU image processing, compositing, filters, and render-graph optimization"
            ),
            SourceAdoption(
                id: "videoio",
                repository: "MetalPetal/VideoIO",
                license: "MIT",
                mode: .wrappedDependency,
                purpose: "AVFoundation preview, frame output, and export adapters"
            ),
            SourceAdoption(
                id: "videolab",
                repository: "ruanjx/VideoLab",
                license: "MIT",
                mode: .designReference,
                purpose: "Layer, keyframe, operation, and pre-composition architecture study"
            ),
            SourceAdoption(
                id: "cabbage",
                repository: "VideoFlint/Cabbage",
                license: "MIT",
                mode: .designReference,
                purpose: "AVFoundation timeline and resource abstraction study"
            ),
            SourceAdoption(
                id: "minicut",
                repository: "fwcd/mini-cut",
                license: "GPL-3.0",
                mode: .behavioralReference,
                purpose: "Timeline interaction research only; no source copied into the MIT product"
            ),
            SourceAdoption(
                id: "otio",
                repository: "AcademySoftwareFoundation/OpenTimelineIO",
                license: "Apache-2.0",
                mode: .wrappedDependency,
                purpose: "Future timeline interchange with professional NLE applications"
            )
        ],
        artifactPolicy: "Every buildable phase publishes an unsigned IPA. Installable signed IPAs require user-provided signing credentials."
    )
}
