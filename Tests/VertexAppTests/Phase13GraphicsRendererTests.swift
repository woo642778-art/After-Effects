import Testing
import UIKit
import VertexProject
@testable import Vertex

@Test("Graphics renderer produces a decodable composition-sized text image")
@MainActor func graphicsRendererProducesTextPixels() throws {
    let document = ProjectGraphicDocument(
        kind: .text,
        canvasWidth: 640,
        canvasHeight: 360,
        fill: .solid(ProjectRGBAColor(red: 1, green: 1, blue: 1, alpha: 1)),
        stroke: ProjectGraphicStroke(color: ProjectRGBAColor(red: 0, green: 0, blue: 0, alpha: 1), width: 3),
        text: ProjectTextGraphic(text: "Vertex 그래픽", fontSize: 72, tracking: 2)
    )
    let data = try GeneratedGraphicRenderer.pngData(for: document)
    let image = try #require(UIImage(data: data))
    #expect(Int(image.size.width) == 640)
    #expect(Int(image.size.height) == 360)
    #expect(data.count > 1_000)
}

@Test("Graphics renderer supports gradient repeated star output")
@MainActor func graphicsRendererProducesVectorPixels() throws {
    let document = ProjectGraphicDocument(
        kind: .star,
        canvasWidth: 512,
        canvasHeight: 512,
        fill: .linearGradient(
            start: ProjectRGBAColor(red: 1, green: 0, blue: 0, alpha: 1),
            end: ProjectRGBAColor(red: 0, green: 0.2, blue: 1, alpha: 1),
            angleDegrees: 35
        ),
        stroke: ProjectGraphicStroke(color: ProjectRGBAColor(red: 1, green: 1, blue: 1, alpha: 1), width: 4),
        vector: ProjectVectorGraphic(starPoints: 6, trimStart: 0.05, trimEnd: 0.9, repeaterCount: 4, repeaterRotationDegrees: 12)
    )
    let data = try GeneratedGraphicRenderer.pngData(for: document)
    #expect(UIImage(data: data) != nil)
    #expect(data.count > 1_000)
}
