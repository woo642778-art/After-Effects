import Testing
import VertexCore
@testable import VertexProject

@Test("Tracking solve channels evaluate through the project animation engine")
func trackingSolveAnimationEvaluation() throws {
    let track = ProjectMotionTrack(name: "Planar Integration", kind: .planar, samples: [
        .init(
            time: .zero,
            region: .init(x: 0.20, y: 0.20, width: 0.20, height: 0.20),
            rotationDegrees: 5,
            confidence: 1
        ),
        .init(
            time: RationalTime(value: 2, timescale: 1),
            region: .init(x: 0.40, y: 0.30, width: 0.40, height: 0.40),
            rotationDegrees: 25,
            confidence: 1
        )
    ])

    let channels = try track.planarTransformChannels(
        mode: .follow,
        basePosition: .init(x: 0.5, y: 0.5),
        baseScale: 1,
        baseRotationDegrees: 10
    )
    let midpoint = RationalTime(value: 1, timescale: 1)

    let positionX = try #require(channels.channel(for: .layer(.positionX)))
    let positionY = try #require(channels.channel(for: .layer(.positionY)))
    let scaleX = try #require(channels.channel(for: .layer(.scaleX)))
    let scaleY = try #require(channels.channel(for: .layer(.scaleY)))
    let rotation = try #require(channels.channel(for: .layer(.rotationDegrees)))

    #expect(abs(try positionX.evaluatedValue(at: midpoint).scalar - 0.60) < 1e-12)
    #expect(abs(try positionY.evaluatedValue(at: midpoint).scalar - 0.55) < 1e-12)
    #expect(abs(try scaleX.evaluatedValue(at: midpoint).scalar - 1.50) < 1e-12)
    #expect(abs(try scaleY.evaluatedValue(at: midpoint).scalar - 1.50) < 1e-12)
    #expect(abs(try rotation.evaluatedValue(at: midpoint).scalar - 20.0) < 1e-12)
}

private extension ProjectAnimatableValue {
    var scalar: Double {
        get throws {
            guard case .scalar(let value) = self else {
                throw ProjectError.invalidValue("Expected a scalar tracking animation value.")
            }
            return value
        }
    }
}
