import Foundation
import Testing
import VertexCore
@testable import VertexProject

@Test("Mask validates cubic geometry and deterministic flattening")
func maskGeometryAndFlattening() throws {
    let path = ProjectBezierPath.ellipse(centerX: 0.5, centerY: 0.5, radiusX: 0.25, radiusY: 0.2)
    let mask = try ProjectMask(
        id: VertexID(rawValue: "82000000-0000-0000-0000-000000000001"),
        name: "Ellipse",
        path: path,
        mode: .add,
        opacity: 0.75,
        featherPixels: 12,
        expansionPixels: 3,
        inverted: false,
        enabled: true
    ).validated()

    let flattened = try mask.flattenedSegments(segmentsPerCurve: 8)
    #expect(flattened.count == 32)
    #expect(flattened.first?.start == path.vertices[0].anchor)
    #expect(flattened.allSatisfy { segment in
        [segment.start.x, segment.start.y, segment.end.x, segment.end.y].allSatisfy(\.isFinite)
    })
}

@Test("Mask validation rejects unsupported mobile bounds and invalid parameters")
func maskValidationLimits() {
    let path = ProjectBezierPath.rectangle(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    #expect(throws: ProjectError.self) {
        try ProjectMask(name: "Bad opacity", path: path, opacity: 1.1).validated()
    }
    #expect(throws: ProjectError.self) {
        try ProjectMask(name: "Bad feather", path: path, featherPixels: -1).validated()
    }

    let tooMany = ProjectBezierPath(
        vertices: (0..<65).map { index in
            ProjectBezierVertex(anchor: .init(x: Double(index) / 64.0, y: 0.5))
        },
        closed: true
    )
    #expect(throws: ProjectError.self) {
        try ProjectMask(name: "Too many", path: tooMany).validated()
    }
}

@Test("Layer mask collection rejects duplicate IDs and more than sixteen masks")
func maskCollectionLimits() throws {
    let path = ProjectBezierPath.rectangle(x: 0, y: 0, width: 1, height: 1)
    let sharedID = VertexID(rawValue: "82000000-0000-0000-0000-000000000010")
    let duplicate = [
        ProjectMask(id: sharedID, name: "A", path: path),
        ProjectMask(id: sharedID, name: "B", path: path)
    ]
    #expect(throws: ProjectError.self) { try duplicate.validatedMasks() }

    let seventeen = (0..<17).map { index in
        ProjectMask(
            id: VertexID(rawValue: String(format: "82000000-0000-0000-0000-%012d", 100 + index)),
            name: "Mask \(index)",
            path: path
        )
    }
    #expect(throws: ProjectError.self) { try seventeen.validatedMasks() }
}

@Test("Track matte exposes four production modes")
func trackMatteModes() {
    #expect(Set(ProjectTrackMatteMode.allCases) == Set([.alpha, .alphaInverted, .luma, .lumaInverted]))
}
