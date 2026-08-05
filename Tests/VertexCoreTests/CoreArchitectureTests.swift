import Foundation
import Testing
@testable import VertexCore

@Test("Rational time normalizes and compares without floating point")
func rationalTimeIsExact() throws {
    let half = RationalTime(value: 300, timescale: 600)
    let equivalentHalf = RationalTime(value: 12_000, timescale: 24_000)
    let oneFrame = RationalTime(value: 1, timescale: 24)

    #expect(half == equivalentHalf)
    #expect(oneFrame < half)
    #expect(try half.adding(half) == RationalTime(value: 1, timescale: 1))
}

@Test("Rational time rescaling has explicit rounding")
func rationalTimeRescaling() throws {
    let frame = RationalTime(value: 1, timescale: 24)

    #expect(try frame.rescaled(to: 600, rounding: .nearest) == RationalTime(value: 25, timescale: 600))
    #expect(try frame.rescaled(to: 1, rounding: .towardZero) == .zero)
}

@Test("Coordinate conversion round trips through normalized top-left space")
func coordinateConversionRoundTrips() throws {
    let canvas = VertexSize(width: 1920, height: 1080)
    let pixelPoint = VertexPoint(x: 960, y: 540)
    let normalized = try CoordinateConverter.convert(
        pixelPoint,
        from: .pixelsTopLeft,
        to: .normalizedCenter,
        canvas: canvas
    )

    #expect(normalized == VertexPoint(x: 0, y: 0))

    let restored = try CoordinateConverter.convert(
        normalized,
        from: .normalizedCenter,
        to: .pixelsTopLeft,
        canvas: canvas
    )
    #expect(restored == pixelPoint)
}

@Test("Dependency graph returns dependencies before dependents")
func dependencyGraphOrdersNodes() throws {
    var graph = DependencyGraph<String>()
    graph.addDependency(from: "output", dependsOn: "grade")
    graph.addDependency(from: "grade", dependsOn: "decode")

    #expect(try graph.topologicalOrder() == ["decode", "grade", "output"])
}

@Test("Dependency graph reports a stable cycle path")
func dependencyGraphDetectsCycle() {
    var graph = DependencyGraph<String>()
    graph.addDependency(from: "A", dependsOn: "B")
    graph.addDependency(from: "B", dependsOn: "C")
    graph.addDependency(from: "C", dependsOn: "A")

    #expect(throws: DependencyCycle<String>.self) {
        try graph.topologicalOrder()
    }
}

@Test("Stable IDs parse canonical UUID strings")
func stableIDParsing() throws {
    let value = "7F6F509E-845A-4B5A-9A80-21C1CBE65B25"
    let id = try VertexID(parsing: value)

    #expect(id.rawValue == value.lowercased())
    #expect(throws: VertexIDError.self) {
        try VertexID(parsing: "not-an-id")
    }
}

@Test("Color descriptors preserve explicit primaries, transfer, matrix, and alpha")
func colorDescriptorIsExplicit() {
    let descriptor = ColorDescriptor.rec2020PQ(alphaMode: .premultiplied)

    #expect(descriptor.primaries == .rec2020)
    #expect(descriptor.transferFunction == .pq)
    #expect(descriptor.matrix == .bt2020NonConstantLuminance)
    #expect(descriptor.alphaMode == .premultiplied)
}

@Test("One-time presentation gate consumes only once")
func presentationGateConsumesOnce() {
    var gate = OneTimePresentationGate(hasPresented: false)
    let first = gate.consumePresentation()
    let second = gate.consumePresentation()

    #expect(first)
    #expect(!second)
    #expect(gate.hasPresented)
}

@Test("Phase 2 is the active implemented milestone")
func phaseTwoIsActive() {
    #expect(MilestoneCatalog.current.number == 2)
    #expect(MilestoneCatalog.current.title == "Core Architecture and Product Identity")
    #expect(MilestoneCatalog.current.status == .implemented)
}
