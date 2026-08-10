#if canImport(Vision) && canImport(AVFoundation)
import Testing
import VertexProject
@testable import VertexTrackingVision

@Test("Vision and project tracking rectangles round trip coordinate origins")
func trackingCoordinateRoundTrip() throws {
    let project = try ProjectTrackingRegion(x: 0.17, y: 0.23, width: 0.31, height: 0.29).validated()
    let vision = VisionMotionTracker.visionRegion(fromProject: project)
    #expect(abs(vision.origin.x - 0.17) < 1e-12)
    #expect(abs(vision.origin.y - 0.48) < 1e-12)
    let roundTrip = try VisionMotionTracker.projectRegion(fromVision: vision).validated()
    #expect(abs(roundTrip.x - project.x) < 1e-12)
    #expect(abs(roundTrip.y - project.y) < 1e-12)
    #expect(abs(roundTrip.width - project.width) < 1e-12)
    #expect(abs(roundTrip.height - project.height) < 1e-12)
}
#endif
