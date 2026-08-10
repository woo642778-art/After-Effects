import Testing
@testable import VertexProject

@Test("Bezier graphic morphs between matching exact topologies")
func bezierGraphicMorphing() throws {
    let source = ProjectBezierPath(
        vertices: [
            .init(anchor: .init(x: 0.2, y: 0.2)),
            .init(anchor: .init(x: 0.8, y: 0.2)),
            .init(anchor: .init(x: 0.8, y: 0.8)),
            .init(anchor: .init(x: 0.2, y: 0.8))
        ],
        closed: true
    )
    let target = ProjectBezierPath(
        vertices: [
            .init(anchor: .init(x: 0.5, y: 0.1)),
            .init(anchor: .init(x: 0.9, y: 0.5)),
            .init(anchor: .init(x: 0.5, y: 0.9)),
            .init(anchor: .init(x: 0.1, y: 0.5))
        ],
        closed: true
    )
    let vector = ProjectVectorGraphic(bezierPaths: [source], morphTargets: [target], morphProgress: 0.5)
    let resolved = try #require(vector.resolvedBezierPaths().first)
    #expect(resolved.vertices[0].anchor == ProjectVector2(x: 0.35, y: 0.15))
    #expect(resolved.closed)
}

@Test("Bezier graphic rejects mismatched morph topology")
func bezierGraphicRejectsMismatchedMorph() {
    let source = ProjectBezierPath.rectangle(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    let target = ProjectBezierPath(
        vertices: [
            .init(anchor: .init(x: 0.5, y: 0.1)),
            .init(anchor: .init(x: 0.9, y: 0.9)),
            .init(anchor: .init(x: 0.1, y: 0.9))
        ],
        closed: true
    )
    let graphic = ProjectGraphicDocument(
        kind: .bezier,
        canvasWidth: 1920,
        canvasHeight: 1080,
        fill: .solid(.black),
        vector: ProjectVectorGraphic(bezierPaths: [source], morphTargets: [target], morphProgress: 0.5)
    )
    #expect(throws: Error.self) { try graphic.validated() }
}

@Test("Text range selectors produce deterministic per-character weights")
func textRangeSelectorWeights() throws {
    let selector = try ProjectTextRangeSelector(start: 0.25, end: 0.75, amount: 0.8).validated()
    #expect(selector.weight(forCharacter: 0, characterCount: 5) == 0)
    #expect(selector.weight(forCharacter: 1, characterCount: 5) == 0.8)
    #expect(selector.weight(forCharacter: 2, characterCount: 5) == 0.8)
    #expect(selector.weight(forCharacter: 3, characterCount: 5) == 0.8)
    #expect(selector.weight(forCharacter: 4, characterCount: 5) == 0)
}

@Test("Text animator validates transform and selector ranges")
func textAnimatorValidation() throws {
    let animator = ProjectTextAnimator(
        selector: .init(start: 0, end: 0.5, amount: 1),
        opacity: 0.4,
        positionX: 25,
        positionY: -10,
        scale: 1.2,
        rotationDegrees: 12,
        tracking: 5
    )
    _ = try animator.validated()
    let text = ProjectTextGraphic(text: "Vertex", animators: [animator])
    _ = try text.validated()
}
