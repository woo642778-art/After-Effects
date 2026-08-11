import Testing
import VertexCore
@testable import VertexProcedural

private func baseConfiguration(seed: UInt64 = 42) -> ParticleSystemConfiguration {
    ParticleSystemConfiguration(
        seed: seed,
        emitter: .box(min: .init(x: 0.35, y: 0.35), max: .init(x: 0.65, y: 0.65)),
        birthRate: 48,
        maxParticles: 160,
        lifetime: 2.5,
        lifetimeVariance: 0.4,
        initialSpeed: 0.12,
        speedVariance: 0.04,
        angleRadians: -.pi / 2,
        spreadRadians: .pi * 0.7,
        acceleration: .init(x: 0.01, y: 0.08),
        turbulenceStrength: 0.035,
        turbulenceScale: 2.2,
        collisionEnabled: true,
        restitution: 0.72,
        size: 0.018,
        sizeVariance: 0.008,
        startOpacity: 0.9,
        endOpacity: 0,
        trailSamples: 6
    )
}

@Test("same seed configuration and exact time produce identical ordered particle states")
func deterministicParticleState() {
    let configuration = baseConfiguration()
    let time = RationalTime(value: 73, timescale: 30)
    #expect(ParticleSimulator.states(configuration: configuration, time: time) == ParticleSimulator.states(configuration: configuration, time: time))
}

@Test("different seeds produce different particle layouts")
func seedChangesParticleLayout() {
    let time = RationalTime(value: 73, timescale: 30)
    let first = ParticleSimulator.states(configuration: baseConfiguration(seed: 10), time: time)
    let second = ParticleSimulator.states(configuration: baseConfiguration(seed: 11), time: time)
    #expect(first.map(\.position) != second.map(\.position))
}

@Test("particle counts remain bounded and expired particles disappear")
func birthLifetimeAndBoundedCount() {
    var configuration = baseConfiguration()
    configuration.birthRate = 500
    configuration.maxParticles = 64
    configuration.lifetime = 0.5
    configuration.lifetimeVariance = 0
    let states = ParticleSimulator.states(configuration: configuration, time: RationalTime(value: 10, timescale: 1))
    #expect(states.count <= 64)
    #expect(states.allSatisfy { $0.ageSeconds >= 0 && $0.ageSeconds <= 0.5 })
}

@Test("acceleration and turbulence alter trajectory deterministically")
func forcesAndTurbulenceAffectTrajectory() {
    var calm = baseConfiguration()
    calm.acceleration = .zero
    calm.turbulenceStrength = 0
    var forced = calm
    forced.acceleration = .init(x: 0.12, y: -0.07)
    forced.turbulenceStrength = 0.08

    let time = RationalTime(value: 47, timescale: 20)
    let calmStates = ParticleSimulator.states(configuration: calm, time: time)
    let forcedStates = ParticleSimulator.states(configuration: forced, time: time)
    #expect(calmStates.map(\.position) != forcedStates.map(\.position))
    #expect(forcedStates == ParticleSimulator.states(configuration: forced, time: time))
}

@Test("collision foundation keeps enabled particle positions in normalized bounds")
func collisionBoundsParticles() {
    var configuration = baseConfiguration()
    configuration.initialSpeed = 2.0
    configuration.speedVariance = 0.8
    configuration.acceleration = .init(x: 1.0, y: 1.0)
    configuration.collisionEnabled = true
    let states = ParticleSimulator.states(configuration: configuration, time: RationalTime(value: 9, timescale: 2))
    #expect(states.allSatisfy { (0...1).contains($0.position.x) && (0...1).contains($0.position.y) })
}

@Test("trail histories are bounded and end at current particle state")
func particleTrailsAreBounded() {
    let configuration = baseConfiguration()
    let time = RationalTime(value: 61, timescale: 30)
    let states = ParticleSimulator.states(configuration: configuration, time: time)
    let trails = ParticleSimulator.trails(configuration: configuration, time: time)
    #expect(trails.values.allSatisfy { $0.count <= configuration.trailSamples })
    for state in states.prefix(12) {
        if let trail = trails[state.birthIndex], let final = trail.last {
            #expect(final.position == state.position)
        }
    }
}
