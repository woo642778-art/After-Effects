import Testing
@testable import Vertex

@Test("Only the latest publication token may update UI state")
func publicationGateRejectsStaleCompletions() {
    var gate = PublicationGate()
    let first = gate.begin()
    let second = gate.begin()

    #expect(!gate.accepts(first))
    #expect(gate.accepts(second))
}
