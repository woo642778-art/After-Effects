import Testing
import UIKit
import VertexProject
@testable import Vertex

@Test("Generated PNG embeds and restores the editable Vertex graphic document")
@MainActor func generatedGraphicMetadataRoundTrip() throws {
    let document = ProjectGraphicDocument(
        kind: .text,
        canvasWidth: 640,
        canvasHeight: 360,
        fill: .linearGradient(
            start: ProjectRGBAColor(red: 1, green: 0, blue: 0, alpha: 1),
            end: ProjectRGBAColor(red: 0, green: 0, blue: 1, alpha: 1),
            angleDegrees: 30
        ),
        text: ProjectTextGraphic(
            text: "Vertex 안녕",
            fontSize: 72,
            animators: [ProjectTextAnimator(selector: .init(start: 0.2, end: 0.8), opacity: 0.7, positionY: -8, scale: 1.1)]
        )
    )
    let data = try GeneratedGraphicRenderer.pngData(for: document)
    #expect(UIImage(data: data) != nil)
    #expect(try GeneratedGraphicRenderer.editableDocument(from: data) == document)
}

@Test("Bezier union subtract intersect and xor produce decodable pixel output")
@MainActor func bezierBooleanModesRender() throws {
    let first = ProjectBezierPath.rectangle(x: 0.15, y: 0.2, width: 0.55, height: 0.6)
    let second = ProjectBezierPath.ellipse(centerX: 0.65, centerY: 0.5, radiusX: 0.25, radiusY: 0.3)
    for operation in ProjectShapeBooleanOperation.allCases {
        let document = ProjectGraphicDocument(
            kind: .bezier,
            canvasWidth: 512,
            canvasHeight: 512,
            fill: .solid(ProjectRGBAColor(red: 0.2, green: 0.8, blue: 1, alpha: 1)),
            stroke: ProjectGraphicStroke(color: ProjectRGBAColor(red: 1, green: 1, blue: 1, alpha: 1), width: 3),
            vector: ProjectVectorGraphic(bezierPaths: [first, second], booleanOperation: operation)
        )
        let data = try GeneratedGraphicRenderer.pngData(for: document)
        #expect(UIImage(data: data) != nil)
        #expect(data.count > 1_000)
    }
}
