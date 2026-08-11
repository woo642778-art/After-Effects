import Testing
import VertexCore
@testable import VertexProject

private func sample(_ seconds: Int64, x: Double, y: Double, width: Double = 0.2, rotation: Double = 0, confidence: Double = 1) -> ProjectTrackingSample {
    ProjectTrackingSample(
        time: RationalTime(value: seconds, timescale: 1),
        region: ProjectTrackingRegion(x: x, y: y, width: width, height: 0.2),
        rotationDegrees: rotation,
        confidence: confidence
    )
}

@Test("Follow and stabilize solves apply opposite exact translation deltas")
func trackingTranslationSolve() throws {
    let track = ProjectMotionTrack(name: "Point", kind: .point, samples: [
        sample(0, x: 0.2, y: 0.3),
        sample(1, x: 0.3, y: 0.25),
        sample(2, x: 0.4, y: 0.2)
    ])
    let follow = try track.transformChannels(mode: .follow, basePosition: .init(x: 0.5, y: 0.5))
    let stabilize = try track.transformChannels(mode: .stabilize, basePosition: .init(x: 0.5, y: 0.5))
    #expect(follow.count == 2)
    #expect(stabilize.count == 2)
    #expect(abs(follow[0].keyframes.last!.value.scalarValue! - 0.7) < 1e-12)
    #expect(abs(stabilize[0].keyframes.last!.value.scalarValue! - 0.3) < 1e-12)
    #expect(abs(follow[1].keyframes.last!.value.scalarValue! - 0.4) < 1e-12)
    #expect(abs(stabilize[1].keyframes.last!.value.scalarValue! - 0.6) < 1e-12)
}

@Test("Planar solve generates scale and rotation channels")
func planarTrackingSolve() throws {
    let track = ProjectMotionTrack(name: "Plane", kind: .planar, samples: [
        sample(0, x: 0.2, y: 0.2, width: 0.2, rotation: 5),
        sample(1, x: 0.25, y: 0.25, width: 0.3, rotation: 20)
    ])
    let follow = try track.planarTransformChannels(mode: .follow, basePosition: .init(x: 0.5, y: 0.5), baseScale: 1, baseRotationDegrees: 10)
    #expect(follow.count == 5)
    #expect(follow[2].property == .layer(.scaleX))
    #expect(abs(follow[2].keyframes.last!.value.scalarValue! - 1.5) < 1e-12)
    #expect(abs(follow[4].keyframes.last!.value.scalarValue! - 25) < 1e-12)
}

@Test("Confidence threshold filters weak tracking samples without changing exact time")
func trackingConfidenceThreshold() throws {
    let track = ProjectMotionTrack(name: "Object", kind: .object, samples: [
        sample(0, x: 0.2, y: 0.2, confidence: 0.95),
        sample(1, x: 0.25, y: 0.25, confidence: 0.2),
        sample(2, x: 0.3, y: 0.3, confidence: 0.9)
    ])
    let channels = try track.transformChannels(mode: .follow, basePosition: .init(x: 0.5, y: 0.5), minimumConfidence: 0.8)
    #expect(channels[0].keyframes.count == 2)
    #expect(channels[0].keyframes.last?.time == RationalTime(value: 2, timescale: 1))
}

@Test("Rotoscope track becomes an animatable mask path channel")
func rotoscopeMaskChannel() throws {
    let maskID = VertexID(rawValue: "14000000-0000-0000-0000-000000000001")
    let first = ProjectBezierPath.rectangle(x: 0.1, y: 0.1, width: 0.4, height: 0.4)
    let second = ProjectBezierPath.rectangle(x: 0.2, y: 0.15, width: 0.4, height: 0.4)
    let track = ProjectRotoscopeTrack(name: "Subject", keyframes: [
        .init(time: .zero, path: first),
        .init(time: RationalTime(value: 1, timescale: 1), path: second)
    ])
    let channel = try track.maskAnimationChannel(maskID: maskID)
    #expect(channel.property == .mask(maskID: maskID, property: .path))
    #expect(channel.keyframes.count == 2)
    #expect(channel.keyframes[1].value == .bezierPath(second))
}

@Test("Camera motion summary reports translation zoom rotation and confidence")
func cameraMotionSummary() throws {
    let track = ProjectMotionTrack(name: "Camera", kind: .planar, samples: [
        sample(0, x: 0.1, y: 0.2, width: 0.2, rotation: 2, confidence: 0.8),
        sample(1, x: 0.2, y: 0.25, width: 0.3, rotation: 12, confidence: 1)
    ])
    let summary = try track.cameraMotionSummary()
    #expect(abs(summary.translationX - 0.15) < 0.000_001)
    #expect(abs(summary.translationY - 0.05) < 0.000_001)
    #expect(abs(summary.zoomRatio - 1.5) < 0.000_001)
    #expect(abs(summary.rotationDegrees - 10) < 0.000_001)
    #expect(abs(summary.confidence - 0.9) < 0.000_001)
}

private extension ProjectAnimatableValue {
    var scalarValue: Double? {
        guard case .scalar(let value) = self else { return nil }
        return value
    }
}
