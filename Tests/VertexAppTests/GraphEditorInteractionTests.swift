import Testing
import VertexProject
@testable import Vertex

@Test("Graph editor clamps temporal handle X and preserves finite Y")
func graphEditorValidatesHandleDrag() throws {
    let handle = try GraphEditorMath.temporalHandle(x: 1.4, y: -0.25)
    #expect(handle.x == 1)
    #expect(handle.y == -0.25)
}

@Test("Graph editor speed mode shares canonical temporal handle model")
func graphEditorSpeedUsesSameHandle() throws {
    let source = ProjectBezierHandle(x: 0.35, y: 0.2)
    let adjusted = try GraphEditorMath.adjustedInfluence(source, deltaX: 0.1, deltaY: 0.3)
    #expect(abs(adjusted.x - 0.45) < 1e-12)
    #expect(abs(adjusted.y - 0.5) < 1e-12)
}
