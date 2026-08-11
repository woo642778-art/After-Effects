import Foundation
import VertexCore

public enum ParticleSimulator {
    public static func states(configuration raw: ParticleSystemConfiguration, time: RationalTime) -> [ParticleState] {
        let configuration = sanitized(raw)
        guard configuration.birthRate > 0, configuration.maxParticles > 0, configuration.lifetime > 0 else { return [] }
        let now = max(0, time.seconds)
        let maximumLifetime = configuration.lifetime + configuration.lifetimeVariance
        let newestBirth = Int(floor(now * configuration.birthRate))
        let oldestBirth = max(0, Int(floor(max(0, now - maximumLifetime) * configuration.birthRate)) - 1)
        var result: [ParticleState] = []
        result.reserveCapacity(min(configuration.maxParticles, max(0, newestBirth - oldestBirth + 1)))

        if newestBirth >= oldestBirth {
            for birthIndex in oldestBirth...newestBirth {
                let birthTime = Double(birthIndex) / configuration.birthRate
                let lifetime = max(0.05, configuration.lifetime + ParticleRandom.signed(configuration.seed, birthIndex, 0) * configuration.lifetimeVariance)
                let age = now - birthTime
                guard age >= 0, age <= lifetime else { continue }
                result.append(state(configuration: configuration, birthIndex: birthIndex, age: age, lifetime: lifetime))
            }
        }
        if result.count > configuration.maxParticles {
            result.removeFirst(result.count - configuration.maxParticles)
        }
        return result
    }

    public static func trails(configuration raw: ParticleSystemConfiguration, time: RationalTime) -> [Int: [ParticleTrailPoint]] {
        let configuration = sanitized(raw)
        let sampleCount = min(max(configuration.trailSamples, 0), 32)
        guard sampleCount > 0 else { return [:] }
        let current = states(configuration: configuration, time: time)
        var output: [Int: [ParticleTrailPoint]] = [:]
        output.reserveCapacity(current.count)
        for particle in current {
            let lifetime = max(0.05, configuration.lifetime + ParticleRandom.signed(configuration.seed, particle.birthIndex, 0) * configuration.lifetimeVariance)
            let step = max(1.0 / 60.0, min(0.08, lifetime / Double(max(sampleCount, 1))))
            var points: [ParticleTrailPoint] = []
            for index in stride(from: sampleCount - 1, through: 0, by: -1) {
                let age = particle.ageSeconds - Double(index) * step
                guard age >= 0 else { continue }
                let state = state(configuration: configuration, birthIndex: particle.birthIndex, age: age, lifetime: lifetime)
                let fade = Double(points.count + 1) / Double(sampleCount)
                points.append(.init(position: state.position, opacity: state.opacity * fade))
            }
            if points.last?.position != particle.position {
                points.append(.init(position: particle.position, opacity: particle.opacity))
            }
            if points.count > sampleCount { points.removeFirst(points.count - sampleCount) }
            output[particle.birthIndex] = points
        }
        return output
    }

    private static func state(configuration: ParticleSystemConfiguration, birthIndex: Int, age: Double, lifetime: Double) -> ParticleState {
        let origin = emitterPosition(configuration.emitter, seed: configuration.seed, index: birthIndex)
        let speed = max(0, configuration.initialSpeed + ParticleRandom.signed(configuration.seed, birthIndex, 4) * configuration.speedVariance)
        let angle = configuration.angleRadians + ParticleRandom.signed(configuration.seed, birthIndex, 5) * configuration.spreadRadians * 0.5
        let initialVelocity = ParticleVector2(x: cos(angle) * speed, y: sin(angle) * speed)
        let phaseX = ParticleRandom.unit(configuration.seed, birthIndex, 6) * Double.pi * 2
        let phaseY = ParticleRandom.unit(configuration.seed, birthIndex, 7) * Double.pi * 2
        let frequency = max(0.05, configuration.turbulenceScale)
        let turbulenceX = sin(age * frequency * 2.13 + phaseX) * configuration.turbulenceStrength
        let turbulenceY = cos(age * frequency * 1.71 + phaseY) * configuration.turbulenceStrength
        let turbulenceDisplacement = ParticleVector2(
            x: turbulenceX * age * 0.45,
            y: turbulenceY * age * 0.45
        )
        var position = origin
            + initialVelocity * age
            + configuration.acceleration * (0.5 * age * age)
            + turbulenceDisplacement
        var velocity = initialVelocity
            + configuration.acceleration * age
            + ParticleVector2(x: turbulenceX, y: turbulenceY)

        if configuration.collisionEnabled {
            let reflectedX = reflected(position.x, velocity: velocity.x, restitution: configuration.restitution)
            let reflectedY = reflected(position.y, velocity: velocity.y, restitution: configuration.restitution)
            position = .init(x: reflectedX.position, y: reflectedY.position)
            velocity = .init(x: reflectedX.velocity, y: reflectedY.velocity)
        }

        let normalizedAge = min(max(age / lifetime, 0), 1)
        let sizeVariation = ParticleRandom.signed(configuration.seed, birthIndex, 8) * configuration.sizeVariance
        let size = max(0.0001, configuration.size + sizeVariation) * (0.75 + 0.25 * sin(normalizedAge * Double.pi))
        let opacity = max(0, min(1, configuration.startOpacity + (configuration.endOpacity - configuration.startOpacity) * normalizedAge))
        return ParticleState(
            birthIndex: birthIndex,
            position: position,
            velocity: velocity,
            ageSeconds: age,
            normalizedAge: normalizedAge,
            size: size,
            opacity: opacity
        )
    }

    private static func emitterPosition(_ emitter: ParticleEmitterShape, seed: UInt64, index: Int) -> ParticleVector2 {
        let u = ParticleRandom.unit(seed, index, 1)
        let v = ParticleRandom.unit(seed, index, 2)
        switch emitter {
        case .point(let point):
            return point
        case .line(let start, let end):
            return .init(x: start.x + (end.x - start.x) * u, y: start.y + (end.y - start.y) * u)
        case .box(let minPoint, let maxPoint):
            return .init(x: minPoint.x + (maxPoint.x - minPoint.x) * u, y: minPoint.y + (maxPoint.y - minPoint.y) * v)
        }
    }

    private static func reflected(_ value: Double, velocity: Double, restitution: Double) -> (position: Double, velocity: Double) {
        guard value < 0 || value > 1 else { return (value, velocity) }
        let period = 2.0
        var phase = value.truncatingRemainder(dividingBy: period)
        if phase < 0 { phase += period }
        let position = phase <= 1 ? phase : 2 - phase
        let segment = Int(floor(value))
        let flipped = abs(segment) % 2 == 1
        return (min(max(position, 0), 1), (flipped ? -velocity : velocity) * min(max(restitution, 0), 1))
    }

    private static func sanitized(_ value: ParticleSystemConfiguration) -> ParticleSystemConfiguration {
        var result = value
        result.birthRate = min(max(result.birthRate, 0), 20_000)
        result.maxParticles = min(max(result.maxParticles, 0), 20_000)
        result.lifetime = min(max(result.lifetime, 0), 120)
        result.lifetimeVariance = min(max(result.lifetimeVariance, 0), result.lifetime)
        result.restitution = min(max(result.restitution, 0), 1)
        result.startOpacity = min(max(result.startOpacity, 0), 1)
        result.endOpacity = min(max(result.endOpacity, 0), 1)
        result.trailSamples = min(max(result.trailSamples, 0), 32)
        return result
    }
}
