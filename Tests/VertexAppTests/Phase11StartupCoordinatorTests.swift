import Testing
@testable import Vertex

private struct StartupFixtureError: Error, Sendable {}

@Test @MainActor func phase11StartupPublishesRealStagesAndReachesReady() async {
    let services = VertexStartupServices(
        prepareProjectPersistence: {},
        prepareRenderer: {},
        prepareEffects: {},
        prepareAIModels: {},
        restoreWorkspace: {}
    )
    let coordinator = VertexStartupCoordinator(services: services)

    await coordinator.start()

    #expect(coordinator.phase == .ready)
    #expect(coordinator.warnings.isEmpty)
}

@Test @MainActor func phase11OptionalAIAndWorkspaceFailuresDoNotDeadlockStartup() async {
    let services = VertexStartupServices(
        prepareProjectPersistence: {},
        prepareRenderer: {},
        prepareEffects: {},
        prepareAIModels: { throw StartupFixtureError() },
        restoreWorkspace: { throw StartupFixtureError() }
    )
    let coordinator = VertexStartupCoordinator(services: services)

    await coordinator.start()

    #expect(coordinator.phase == .ready)
    #expect(coordinator.warnings.count == 2)
}

@Test @MainActor func phase11RequiredStartupFailureTerminatesFatally() async {
    let services = VertexStartupServices(
        prepareProjectPersistence: { throw StartupFixtureError() },
        prepareRenderer: {},
        prepareEffects: {},
        prepareAIModels: {},
        restoreWorkspace: {}
    )
    let coordinator = VertexStartupCoordinator(services: services)

    await coordinator.start()

    guard case .fatal = coordinator.phase else {
        Issue.record("Required startup failure must terminate in fatal state")
        return
    }
}
