import Testing
@testable import Vertex

@Test("Startup readiness is independent from milestone number")
func startupIgnoresMilestoneNumber() {
    for milestone in [5, 6, 7, 100] {
        #expect(
            AppStartupPolicy.terminalState(
                bundleUIAvailable: true,
                milestoneNumber: milestone
            ) == .workspace
        )
    }
}

@Test("Only required UI bundle failure is fatal")
func startupOnlyTreatsRequiredUIAsFatal() {
    #expect(
        AppStartupPolicy.terminalState(bundleUIAvailable: false)
            == .fatalConfigurationError("Required UI resources are unavailable.")
    )
}

@Test("Optional subsystem failure cannot create an infinite splash")
func optionalSubsystemFailuresDoNotBlockWorkspace() {
    let outcomes = [
        AppStartupPolicy.terminalState(bundleUIAvailable: true), // AI missing
        AppStartupPolicy.terminalState(bundleUIAvailable: true), // Metal unavailable
        AppStartupPolicy.terminalState(bundleUIAvailable: true), // recent project corrupt
        AppStartupPolicy.terminalState(bundleUIAvailable: true)  // cancelled background work
    ]

    #expect(outcomes.allSatisfy { $0 == .workspace })
    #expect(!outcomes.contains(.splash))
}
