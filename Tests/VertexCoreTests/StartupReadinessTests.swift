import Testing
@testable import VertexCore

@Test("Startup readiness is independent of the phase number")
func startupReadinessIsIndependentOfPhaseNumber() {
    let futureMilestone = Milestone(
        number: 7,
        title: "Motion Engine",
        status: .implemented,
        deliverables: [],
        sourceAdoptions: [],
        artifactPolicy: "test"
    )

    #expect(
        StartupReadinessPolicy.shouldEnterApp(
            architectureContracts: CoreArchitectureCatalog.contracts,
            milestone: futureMilestone
        )
    )
}
