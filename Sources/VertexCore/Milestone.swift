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
        number: 8,
        title: "Masks and Mattes",
        status: .inProgress,
        deliverables: [
            "Reusable exact-time animation channels for layer and mask properties",
            "Animated cubic Bezier masks with vertex and tangent editing",
            "Feather, expansion, opacity, invert, and ordered Add/Subtract/Intersect mask modes",
            "Alpha, Alpha Inverted, Luma, and Luma Inverted track mattes with reference-cycle protection",
            "Metal-backed mask and matte rendering with preview/export semantic parity",
            "Versioned Vertex2 8.0.0 unsigned IPA with deterministic schema-4 project migration"
        ],
        sourceAdoptions: [
            SourceAdoption(
                id: "apple-metal-phase8",
                repository: "Apple Metal",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "GPU mask coverage, matte extraction, and premultiplied-alpha compositing"
            ),
            SourceAdoption(
                id: "apple-swiftui-phase8",
                repository: "Apple SwiftUI",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "Layer property, keyframe, mask-path, and track-matte editing surfaces"
            )
        ],
        artifactPolicy: "Phase 8 publishes Vertex2-8.0.0-unsigned.ipa only after schema migration, animation, mask, matte, Metal pixel, persistence, Simulator, Phase 7 AI regression, iOS 17 arm64 Release, artifact inspection, and SHA-256 gates pass. The IPA remains unsigned until signing credentials are supplied."
    )
}
