import Foundation

public struct ParticleVector2: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public static let zero = ParticleVector2(x: 0, y: 0)

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static func + (lhs: Self, rhs: Self) -> Self { .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    public static func * (lhs: Self, rhs: Double) -> Self { .init(x: lhs.x * rhs, y: lhs.y * rhs) }
}

public enum ParticleEmitterShape: Codable, Equatable, Sendable {
    case point(ParticleVector2)
    case line(start: ParticleVector2, end: ParticleVector2)
    case box(min: ParticleVector2, max: ParticleVector2)
}

public struct ParticleSystemConfiguration: Codable, Equatable, Sendable {
    public var seed: UInt64
    public var emitter: ParticleEmitterShape
    public var birthRate: Double
    public var maxParticles: Int
    public var lifetime: Double
    public var lifetimeVariance: Double
    public var initialSpeed: Double
    public var speedVariance: Double
    public var angleRadians: Double
    public var spreadRadians: Double
    public var acceleration: ParticleVector2
    public var turbulenceStrength: Double
    public var turbulenceScale: Double
    public var collisionEnabled: Bool
    public var restitution: Double
    public var size: Double
    public var sizeVariance: Double
    public var startOpacity: Double
    public var endOpacity: Double
    public var trailSamples: Int

    public init(
        seed: UInt64,
        emitter: ParticleEmitterShape,
        birthRate: Double,
        maxParticles: Int,
        lifetime: Double,
        lifetimeVariance: Double,
        initialSpeed: Double,
        speedVariance: Double,
        angleRadians: Double,
        spreadRadians: Double,
        acceleration: ParticleVector2,
        turbulenceStrength: Double,
        turbulenceScale: Double,
        collisionEnabled: Bool,
        restitution: Double,
        size: Double,
        sizeVariance: Double,
        startOpacity: Double,
        endOpacity: Double,
        trailSamples: Int
    ) {
        self.seed = seed
        self.emitter = emitter
        self.birthRate = birthRate
        self.maxParticles = maxParticles
        self.lifetime = lifetime
        self.lifetimeVariance = lifetimeVariance
        self.initialSpeed = initialSpeed
        self.speedVariance = speedVariance
        self.angleRadians = angleRadians
        self.spreadRadians = spreadRadians
        self.acceleration = acceleration
        self.turbulenceStrength = turbulenceStrength
        self.turbulenceScale = turbulenceScale
        self.collisionEnabled = collisionEnabled
        self.restitution = restitution
        self.size = size
        self.sizeVariance = sizeVariance
        self.startOpacity = startOpacity
        self.endOpacity = endOpacity
        self.trailSamples = trailSamples
    }
}

public struct ParticleState: Codable, Equatable, Sendable, Identifiable {
    public var id: Int { birthIndex }
    public let birthIndex: Int
    public let position: ParticleVector2
    public let velocity: ParticleVector2
    public let ageSeconds: Double
    public let normalizedAge: Double
    public let size: Double
    public let opacity: Double

    public init(birthIndex: Int, position: ParticleVector2, velocity: ParticleVector2, ageSeconds: Double, normalizedAge: Double, size: Double, opacity: Double) {
        self.birthIndex = birthIndex
        self.position = position
        self.velocity = velocity
        self.ageSeconds = ageSeconds
        self.normalizedAge = normalizedAge
        self.size = size
        self.opacity = opacity
    }
}

public struct ParticleTrailPoint: Codable, Equatable, Sendable {
    public let position: ParticleVector2
    public let opacity: Double

    public init(position: ParticleVector2, opacity: Double) {
        self.position = position
        self.opacity = opacity
    }
}
