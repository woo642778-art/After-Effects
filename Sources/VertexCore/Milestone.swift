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
        number: 7,
        title: "Offline AI Studio",
        status: .inProgress,
        deliverables: [
            "Startup state that cannot deadlock on milestone, AI, Metal, or project readiness",
            "Fully offline video Depth Map and Cutout workflows with project-usable results",
            "Fully offline AI Upscale and Restoration with Preview, Balanced, and Max Quality tiers",
            "Chunked full-video AI processing with progress, cancellation, checkpointing, and resume",
            "Pinned model provenance, license, checksum, conversion, and packaged-resource audits",
            "Versioned After Effects 7.0.0 unsigned IPA artifact with model inventory"
        ],
        sourceAdoptions: [
            SourceAdoption(
                id: "vision",
                repository: "Apple Vision",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "On-device person and foreground segmentation fast paths"
            ),
            SourceAdoption(
                id: "coreml",
                repository: "Apple Core ML",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "On-device neural inference, model loading, and compute-unit selection"
            ),
            SourceAdoption(
                id: "depth-anything-v2-small",
                repository: "DepthAnything/Depth-Anything-V2",
                license: "Apache-2.0 for Small checkpoint; final inclusion requires lockfile audit",
                mode: .researchOnly,
                purpose: "Primary monocular depth candidate for an offline Core ML path"
            ),
            SourceAdoption(
                id: "real-esrgan",
                repository: "xinntao/Real-ESRGAN",
                license: "BSD-3-Clause code; checkpoint redistribution audited separately",
                mode: .researchOnly,
                purpose: "General and anime/game super-resolution candidate family"
            ),
            SourceAdoption(
                id: "sam2",
                repository: "facebookresearch/sam2",
                license: "Apache-2.0 upstream code/checkpoints; iOS runtime validation required",
                mode: .researchOnly,
                purpose: "Prompt-driven quality cutout and video mask propagation candidate"
            )
        ],
        artifactPolicy: "Phase 7 publishes After-Effects-7.0.0-unsigned.ipa only after startup, portable AI, native inference, full-video job, persistence, Simulator, Release, model-manifest, packaged-resource, architecture, and SHA-256 gates pass. The IPA remains unsigned until signing credentials are supplied."
    )
}
