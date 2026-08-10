import Testing
@testable import VertexProject

@Test("Text graphic validation accepts multilingual text and rejects empty content")
func textGraphicValidation() throws {
    let valid = ProjectGraphicDocument(
        kind: .text,
        canvasWidth: 1920,
        canvasHeight: 1080,
        fill: .solid(ProjectRGBAColor(red: 1, green: 1, blue: 1, alpha: 1)),
        text: ProjectTextGraphic(text: "Vertex 안녕하세요 こんにちは مرحبا", fontSize: 128, tracking: 3, pathArcDegrees: 120)
    )
    _ = try valid.validated()

    let invalid = ProjectGraphicDocument(
        kind: .text,
        canvasWidth: 1920,
        canvasHeight: 1080,
        fill: .solid(ProjectRGBAColor(red: 1, green: 1, blue: 1, alpha: 1)),
        text: ProjectTextGraphic(text: "")
    )
    #expect(throws: Error.self) { try invalid.validated() }
}

@Test("Vector graphic supports gradients trim paths and deterministic repeaters")
func vectorGraphicValidation() throws {
    let graphic = ProjectGraphicDocument(
        kind: .star,
        canvasWidth: 2048,
        canvasHeight: 2048,
        fill: .linearGradient(
            start: ProjectRGBAColor(red: 1, green: 0, blue: 0, alpha: 1),
            end: ProjectRGBAColor(red: 0, green: 0, blue: 1, alpha: 1),
            angleDegrees: 45
        ),
        stroke: ProjectGraphicStroke(color: ProjectRGBAColor(red: 1, green: 1, blue: 1, alpha: 1), width: 8),
        vector: ProjectVectorGraphic(
            starPoints: 7,
            innerRadius: 0.42,
            trimStart: 0.1,
            trimEnd: 0.85,
            repeaterCount: 12,
            repeaterRotationDegrees: 9,
            repeaterOffsetX: 4,
            repeaterOffsetY: -3
        )
    )
    #expect(try graphic.validated() == graphic)
}

@Test("Vector validation rejects inverted trim ranges and unbounded repeaters")
func vectorGraphicRejectsInvalidRanges() {
    let badTrim = ProjectGraphicDocument(
        kind: .ellipse,
        canvasWidth: 100,
        canvasHeight: 100,
        fill: .solid(ProjectRGBAColor(red: 1, green: 1, blue: 1, alpha: 1)),
        vector: ProjectVectorGraphic(trimStart: 0.8, trimEnd: 0.2)
    )
    #expect(throws: Error.self) { try badTrim.validated() }

    let badRepeater = ProjectGraphicDocument(
        kind: .rectangle,
        canvasWidth: 100,
        canvasHeight: 100,
        fill: .solid(ProjectRGBAColor(red: 1, green: 1, blue: 1, alpha: 1)),
        vector: ProjectVectorGraphic(repeaterCount: 1000)
    )
    #expect(throws: Error.self) { try badRepeater.validated() }
}
