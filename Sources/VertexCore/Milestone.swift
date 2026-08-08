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
        number: 9,
        title: "AE Workspace and Live AI Effects",
        status: .implemented,
        deliverables: [
            "Adaptive AE-style iPad workspace with Project, Composition, Effect Controls, Graph Editor, and Timeline panels",
            "Compact iPhone workspace backed by the same canonical playhead, selection, project commands, and render state",
            "Exact-time editable layer timeline with trim, move, split, ripple, roll, slip, slide, parenting, track mattes, blend mode, lock, solo, and visibility controls",
            "Ordered non-destructive Depth Map, Cutout, Upscale, and Restore layer effects with typed parameters and live preview rerendering",
            "Bounded AI frame scheduling and cache reuse with explicit computing, stale, cached, and failure semantics",
            "Value and Speed Graph Editor surfaces over canonical animation channels and temporal Bezier handles",
            "Atomic Extract / Bake to Layer workflow that verifies derived media before project registration",
            "Versioned Vertex2 9.0.0 build 9 unsigned iOS 17 arm64 IPA"
        ],
        sourceAdoptions: [
            SourceAdoption(
                id: "apple-swiftui-phase9",
                repository: "Apple SwiftUI",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "Adaptive iPad and iPhone professional editing workspace and interaction surfaces"
            ),
            SourceAdoption(
                id: "apple-coreml-phase9",
                repository: "Apple Core ML and Vision",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "On-device AI frame inference without a server dependency"
            ),
            SourceAdoption(
                id: "opentimelineio-phase9",
                repository: "AcademySoftwareFoundation/OpenTimelineIO",
                license: "Apache-2.0",
                mode: .designReference,
                purpose: "Timeline and track data-model reference only; no runtime dependency or copied implementation"
            ),
            SourceAdoption(
                id: "natron-phase9",
                repository: "NatronGitHub/Natron",
                license: "GPL-2.0",
                mode: .designReference,
                purpose: "Professional compositor workspace and effect-control interaction reference only; no source code copied"
            )
        ],
        artifactPolicy: "Phase 9 publishes Vertex2-9.0.0-unsigned.ipa only after AI model/license audits, complete Swift tests, iPhone and iPad Simulator tests, Metal compilation, unsigned iOS 17 arm64 Release build, bundle inspection, independent IPA audit, and SHA-256 verification pass. The IPA remains unsigned until external signing credentials are supplied."
    )
}
