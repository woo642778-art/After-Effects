import Foundation
import SwiftUI
import VertexProject
import VertexRenderMetal

enum VertexStartupService: String, Equatable, Sendable {
    case projectPersistence
    case renderer
    case effects
    case aiModels
    case workspace
}

enum VertexStartupPhase: Equatable, Sendable {
    case coldStart
    case loading(VertexStartupService)
    case restoringSession
    case ready
    case fatal(String)
}

enum VertexStartupPreparationError: LocalizedError, Sendable {
    case applicationSupportUnavailable
    case effectRegistryEmpty
    case invalidWorkspacePreset(String)

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            "Application Support is unavailable."
        case .effectRegistryEmpty:
            "The built-in effect registry is empty."
        case .invalidWorkspacePreset(let raw):
            "Saved workspace preset is invalid: \(raw)"
        }
    }
}

struct VertexStartupServices: Sendable {
    var prepareProjectPersistence: @Sendable () async throws -> Void
    var prepareRenderer: @Sendable () async throws -> Void
    var prepareEffects: @Sendable () async throws -> Void
    var prepareAIModels: @Sendable () async throws -> Void
    var restoreWorkspace: @Sendable () async throws -> Void

    init(
        prepareProjectPersistence: @escaping @Sendable () async throws -> Void,
        prepareRenderer: @escaping @Sendable () async throws -> Void,
        prepareEffects: @escaping @Sendable () async throws -> Void,
        prepareAIModels: @escaping @Sendable () async throws -> Void,
        restoreWorkspace: @escaping @Sendable () async throws -> Void
    ) {
        self.prepareProjectPersistence = prepareProjectPersistence
        self.prepareRenderer = prepareRenderer
        self.prepareEffects = prepareEffects
        self.prepareAIModels = prepareAIModels
        self.restoreWorkspace = restoreWorkspace
    }

    static func live() -> VertexStartupServices {
        VertexStartupServices(
            prepareProjectPersistence: {
                guard let applicationSupport = FileManager.default.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                ).first else {
                    throw VertexStartupPreparationError.applicationSupportUnavailable
                }
                let projects = applicationSupport
                    .appendingPathComponent("After Effects", isDirectory: true)
                    .appendingPathComponent("Projects", isDirectory: true)
                try FileManager.default.createDirectory(
                    at: projects,
                    withIntermediateDirectories: true
                )
            },
            prepareRenderer: {
                _ = try MetalRenderBackend()
            },
            prepareEffects: {
                guard !ProjectEffectType.allCases.isEmpty else {
                    throw VertexStartupPreparationError.effectRegistryEmpty
                }
            },
            prepareAIModels: {
                _ = try BundledAIEnvironment.load()
            },
            restoreWorkspace: {
                guard let raw = UserDefaults.standard.string(forKey: "vertex2.workspace.preset") else {
                    return
                }
                let supported = Set(["standard", "minimal", "effects", "threeD", "export"])
                guard supported.contains(raw) else {
                    throw VertexStartupPreparationError.invalidWorkspacePreset(raw)
                }
            }
        )
    }
}

@MainActor
final class VertexStartupCoordinator: ObservableObject {
    @Published private(set) var phase: VertexStartupPhase = .coldStart
    @Published private(set) var warnings: [String] = []

    private let services: VertexStartupServices
    private var hasStarted = false

    init(services: VertexStartupServices) {
        self.services = services
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        warnings.removeAll(keepingCapacity: true)

        do {
            phase = .loading(.projectPersistence)
            try await services.prepareProjectPersistence()

            phase = .loading(.renderer)
            try await services.prepareRenderer()

            phase = .loading(.effects)
            try await services.prepareEffects()
        } catch {
            phase = .fatal(error.localizedDescription)
            return
        }

        phase = .loading(.aiModels)
        do {
            try await services.prepareAIModels()
        } catch {
            warnings.append(error.localizedDescription)
        }

        phase = .restoringSession
        do {
            try await services.restoreWorkspace()
        } catch {
            warnings.append(error.localizedDescription)
        }

        phase = .ready
    }
}
