import CoreGraphics
import CoreImage
import Foundation
import VertexComposition
import VertexCore
import VertexProcedural
import VertexProject
import VertexRenderMetal

struct ParticleEffectRenderer {
    private static let metalRenderer = try? MetalParticleRenderer()
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    func filteredImage(effect: ProjectEffect, input: CIImage, time: RationalTime) throws -> CIImage? {
        guard Self.particleTypes.contains(effect.type) else { return nil }
        guard let renderer = Self.metalRenderer else {
            throw CompositionError.graphCompilationFailed("Metal particle renderer is unavailable.")
        }
        let configuration = try configuration(for: effect)
        var states = ParticleSimulator.states(configuration: configuration, time: time)
        let trailsEnabled = try boolean(effect, V17EffectParameterID.trails)
        if trailsEnabled {
            let trails = ParticleSimulator.trails(configuration: configuration, time: time)
            let trailStates = trails.values.flatMap { points in
                points.enumerated().map { index, point in
                    ParticleState(
                        birthIndex: -(index + 1),
                        position: point.position,
                        velocity: .zero,
                        ageSeconds: 0,
                        normalizedAge: 0,
                        size: configuration.size * 0.55,
                        opacity: point.opacity * 0.5
                    )
                }
            }
            states.insert(contentsOf: trailStates, at: 0)
        }

        let style = renderStyle(for: effect.type)
        let width = max(1, Int(input.extent.width.rounded()))
        let height = max(1, Int(input.extent.height.rounded()))
        let texture = try renderer.render(states: states, width: width, height: height, style: style)
        guard var overlay = CIImage(mtlTexture: texture, options: [.colorSpace: Self.colorSpace]) else {
            throw CompositionError.graphCompilationFailed("Core Image could not bridge the Metal particle texture.")
        }
        if input.extent.origin != .zero {
            overlay = overlay.transformed(by: CGAffineTransform(translationX: input.extent.minX, y: input.extent.minY))
        }
        overlay = overlay.cropped(to: input.extent)

        if style.additive {
            guard let filter = CIFilter(name: "CIAdditionCompositing") else {
                throw CompositionError.graphCompilationFailed("CIAdditionCompositing is unavailable.")
            }
            filter.setValue(overlay, forKey: kCIInputImageKey)
            filter.setValue(input, forKey: kCIInputBackgroundImageKey)
            return filter.outputImage?.cropped(to: input.extent)
        }
        return overlay.composited(over: input).cropped(to: input.extent)
    }

    static let particleTypes: Set<ProjectEffectType> = [
        .vertexParticleField, .vertexSparks, .vertexSnow, .vertexDust, .vertexStarfield, .vertexTrailParticles
    ]

    private func configuration(for effect: ProjectEffect) throws -> ParticleSystemConfiguration {
        let seed = UInt64(try integer(effect, V17EffectParameterID.seed))
        let birthRate = try scalar(effect, V17EffectParameterID.birthRate)
        let lifetime = try scalar(effect, V17EffectParameterID.lifetime)
        let speed = try scalar(effect, V17EffectParameterID.speed)
        let spread = try scalar(effect, V17EffectParameterID.spread) * .pi / 180
        let gravity = try scalar(effect, V17EffectParameterID.gravity)
        let turbulence = try scalar(effect, V17EffectParameterID.turbulence)
        let size = try scalar(effect, V17EffectParameterID.size)
        let opacity = try scalar(effect, V17EffectParameterID.intensity)
        let collision = try boolean(effect, V17EffectParameterID.collision)
        let trails = try boolean(effect, V17EffectParameterID.trails)

        let emitter: ParticleEmitterShape
        let angle: Double
        let acceleration: ParticleVector2
        let maxParticles: Int
        let lifetimeVariance: Double
        let speedVariance: Double
        let turbulenceScale: Double
        switch effect.type {
        case .vertexSparks:
            emitter = .point(.init(x: 0.5, y: 0.68)); angle = -.pi / 2; acceleration = .init(x: 0, y: gravity); maxParticles = 1_800; lifetimeVariance = lifetime * 0.28; speedVariance = speed * 0.4; turbulenceScale = 4.0
        case .vertexSnow:
            emitter = .line(start: .init(x: 0, y: 0.02), end: .init(x: 1, y: 0.02)); angle = .pi / 2; acceleration = .init(x: 0, y: abs(gravity)); maxParticles = 2_500; lifetimeVariance = lifetime * 0.25; speedVariance = speed * 0.45; turbulenceScale = 1.8
        case .vertexDust:
            emitter = .box(min: .init(x: 0.02, y: 0.02), max: .init(x: 0.98, y: 0.98)); angle = 0; acceleration = .init(x: 0, y: gravity); maxParticles = 2_000; lifetimeVariance = lifetime * 0.35; speedVariance = max(0.01, speed * 0.8); turbulenceScale = 1.2
        case .vertexStarfield:
            emitter = .box(min: .init(x: 0.02, y: 0.02), max: .init(x: 0.98, y: 0.98)); angle = -.pi / 2; acceleration = .zero; maxParticles = 2_500; lifetimeVariance = lifetime * 0.1; speedVariance = speed * 0.6; turbulenceScale = 0.4
        case .vertexTrailParticles:
            emitter = .point(.init(x: 0.5, y: 0.5)); angle = -.pi / 2; acceleration = .init(x: 0, y: gravity); maxParticles = 1_600; lifetimeVariance = lifetime * 0.25; speedVariance = speed * 0.35; turbulenceScale = 3.0
        default:
            emitter = .box(min: .init(x: 0.35, y: 0.35), max: .init(x: 0.65, y: 0.65)); angle = -.pi / 2; acceleration = .init(x: 0, y: gravity); maxParticles = 2_000; lifetimeVariance = lifetime * 0.3; speedVariance = speed * 0.35; turbulenceScale = 2.2
        }

        return ParticleSystemConfiguration(
            seed: seed,
            emitter: emitter,
            birthRate: birthRate,
            maxParticles: maxParticles,
            lifetime: lifetime,
            lifetimeVariance: lifetimeVariance,
            initialSpeed: speed,
            speedVariance: speedVariance,
            angleRadians: angle,
            spreadRadians: spread,
            acceleration: acceleration,
            turbulenceStrength: turbulence,
            turbulenceScale: turbulenceScale,
            collisionEnabled: collision,
            restitution: 0.7,
            size: size,
            sizeVariance: size * 0.35,
            startOpacity: opacity,
            endOpacity: 0,
            trailSamples: trails ? 8 : 0
        )
    }

    private func renderStyle(for type: ProjectEffectType) -> ParticleRenderStyle {
        switch type {
        case .vertexSparks: .init(color: .init(red: 1.0, green: 0.58, blue: 0.12, alpha: 1), additive: true)
        case .vertexSnow: .init(color: .init(red: 0.88, green: 0.94, blue: 1.0, alpha: 1), additive: false)
        case .vertexDust: .init(color: .init(red: 0.90, green: 0.78, blue: 0.56, alpha: 0.65), additive: true)
        case .vertexStarfield: .init(color: .init(red: 0.76, green: 0.86, blue: 1.0, alpha: 1), additive: true)
        case .vertexTrailParticles: .init(color: .init(red: 0.42, green: 0.72, blue: 1.0, alpha: 1), additive: true)
        default: .init(color: .init(red: 0.82, green: 0.88, blue: 1.0, alpha: 0.9), additive: true)
        }
    }

    private func scalar(_ effect: ProjectEffect, _ id: String) throws -> Double {
        guard case .scalar(let value)? = effect.parameter(id: id)?.value else {
            throw CompositionError.graphCompilationFailed("Particle parameter is missing or invalid: \(id).")
        }
        return value
    }

    private func integer(_ effect: ProjectEffect, _ id: String) throws -> Int {
        guard case .integer(let value)? = effect.parameter(id: id)?.value else {
            throw CompositionError.graphCompilationFailed("Particle integer parameter is missing or invalid: \(id).")
        }
        return value
    }

    private func boolean(_ effect: ProjectEffect, _ id: String) throws -> Bool {
        guard case .boolean(let value)? = effect.parameter(id: id)?.value else {
            throw CompositionError.graphCompilationFailed("Particle boolean parameter is missing or invalid: \(id).")
        }
        return value
    }
}
