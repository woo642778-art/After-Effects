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
        number: 3,
        title: "Media Input and Output Foundation",
        status: .implemented,
        deliverables: [
            "Portable media descriptors, exact requests, providers, cancellation, and structured errors",
            "AVFoundation metadata inspection without leaking platform types into VertexMedia",
            "Requested-time thumbnail decoding with preferred-transform handling",
            "Bounded normalized audio waveform extraction",
            "Real Files-based movie selection with metadata, thumbnail, and waveform presentation",
            "Versioned After Effects 3.0.0 unsigned IPA artifact"
        ],
        sourceAdoptions: [
            SourceAdoption(
                id: "avfoundation",
                repository: "Apple AVFoundation",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "Phase 3 production media metadata, frame decoding, and PCM extraction behind Vertex adapters"
            ),
            SourceAdoption(
                id: "metalpetal",
                repository: "MetalPetal/MetalPetal",
                license: "MIT",
                mode: .directDependency,
                purpose: "Deferred to Phase 4 GPU image processing and render graph"
            ),
            SourceAdoption(
                id: "videoio",
                repository: "MetalPetal/VideoIO",
                license: "MIT",
                mode: .researchOnly,
                purpose: "Isolated Phase 4 preview/export candidate; not imported by Phase 3 product code"
            ),
            SourceAdoption(
                id: "videolab",
                repository: "ruanjx/VideoLab",
                license: "MIT",
                mode: .designReference,
                purpose: "Future layer, keyframe, operation, and pre-composition architecture study"
            ),
            SourceAdoption(
                id: "minicut",
                repository: "fwcd/mini-cut",
                license: "GPL-3.0",
                mode: .behavioralReference,
                purpose: "Timeline interaction research only; no source copied into the MIT product"
            )
        ],
        artifactPolicy: "Phase 3 publishes After-Effects-3.0.0-unsigned.ipa. Every later successful phase increments the major version to match its phase number. The IPA remains unsigned until user-provided signing credentials are applied."
    )
}
