import Foundation
import SwiftUI

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
