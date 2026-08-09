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
        number: 10,
        title: "iPad AE Workspace and 3D",
        status: .implemented,
        deliverables: [
            "iPad-only adaptive AE-style workspace with Stage Manager aware panel collapse and resizable docks",
            "Composition, 3D, and Export workspaces behind one Vertex2 editing shell",
            "Portable editable 3D scene model with cube, sphere, plane, camera, light, materials, transforms, projection math, and deterministic mesh operations",
            "GLB and glTF triangle mesh import plus USDZ mesh import through Apple Model I/O",
            "MetalKit 3D viewport with depth testing, camera projection, indexed mesh rendering, and transform evaluation",
            "Project-package 3D scene persistence under the Vertex-owned Scene3D sidecar",
            "Exact-rational-time composition export through the existing composition graph and Metal render backend",
            "Transactional MOV, MP4, GIF, PNG sequence, and JPEG sequence writing with H.264, HEVC, and supported ProRes paths",
            "Versioned Vertex2 10.0.0 build 10 unsigned iPadOS 17 arm64 IPA"
        ],
        sourceAdoptions: [
            SourceAdoption(
                id: "apple-swiftui-phase10",
                repository: "Apple SwiftUI",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "Adaptive iPad-only professional editing, 3D, and export workspaces"
            ),
            SourceAdoption(
                id: "apple-metal-phase10",
                repository: "Apple Metal and MetalKit",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "2D composition rendering and depth-tested 3D viewport rendering"
            ),
            SourceAdoption(
                id: "apple-modelio-phase10",
                repository: "Apple Model I/O",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "USDZ normalization into Vertex-owned mesh structures"
            ),
            SourceAdoption(
                id: "apple-avfoundation-phase10",
                repository: "Apple AVFoundation",
                license: "Apple platform SDK",
                mode: .wrappedDependency,
                purpose: "Transactional frame-accurate delivery encoding"
            )
        ],
        artifactPolicy: "Phase 10 publishes Vertex2-10.0.0-unsigned.ipa only after portable Swift tests, iPad Simulator tests, native Metal/Model I/O/export compilation, unsigned iOS 17 arm64 Release build, bundle inspection, IPA audit, and SHA-256 verification pass. The IPA remains unsigned until external signing credentials are supplied."
    )
}
