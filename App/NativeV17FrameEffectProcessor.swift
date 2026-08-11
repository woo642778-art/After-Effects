import CoreGraphics
import CoreImage
import Foundation
import VertexComposition
import VertexCore
import VertexProject

struct NativeV17FrameEffectProcessor {
    static let v17Types: Set<ProjectEffectType> = [
        .motionBlur, .pixelate, .sharpenLuminance, .maximumComponent, .minimumComponent,
        .whitePointAdjust, .falseColor, .colorMatrix, .maskToAlpha, .edges, .affineTile,
        .checkerboard, .stripes, .starShine, .vertexGlare, .vertexLightStreaks, .vertexAnalogDamage,
        .vertexParticleField, .vertexSparks, .vertexSnow, .vertexDust, .vertexStarfield, .vertexTrailParticles,
        .vertexFractalNoise, .vertexTurbulenceTexture, .vertexPlasma, .vertexCellularTexture, .vertexGrid, .vertexRings
    ]

    func filteredImage(effect: ProjectEffect, input: CIImage, time: RationalTime) throws -> CIImage? {
        guard Self.v17Types.contains(effect.type) else { return nil }
        if let particles = try ParticleEffectRenderer().filteredImage(effect: effect, input: input, time: time) {
            return particles
        }
        if let procedural = try ProceduralTextureRenderer().filteredImage(effect: effect, input: input, time: time) {
            return procedural
        }

        let extent = input.extent
        switch effect.type {
        case .motionBlur:
            return try apply("CIMotionBlur", input: input, values: [
                kCIInputRadiusKey: try scalar(effect, V17EffectParameterID.radius),
                kCIInputAngleKey: try scalar(effect, V17EffectParameterID.angle) * .pi / 180
            ])
        case .pixelate:
            return try apply("CIPixellate", input: input, values: [
                kCIInputScaleKey: try scalar(effect, V17EffectParameterID.scale),
                kCIInputCenterKey: CIVector(x: try center(effect, extent).x, y: try center(effect, extent).y)
            ])
        case .sharpenLuminance:
            return try apply("CISharpenLuminance", input: input, values: [
                kCIInputSharpnessKey: try scalar(effect, V17EffectParameterID.intensity),
                kCIInputRadiusKey: try scalar(effect, V17EffectParameterID.radius)
            ])
        case .maximumComponent:
            return try apply("CIMaximumComponent", input: input)
        case .minimumComponent:
            return try apply("CIMinimumComponent", input: input)
        case .whitePointAdjust:
            return try apply("CIWhitePointAdjust", input: input, values: [
                kCIInputColorKey: CIColor(
                    red: try scalar(effect, V17EffectParameterID.red),
                    green: try scalar(effect, V17EffectParameterID.green),
                    blue: try scalar(effect, V17EffectParameterID.blue)
                )
            ])
        case .falseColor:
            let mapped = try apply("CIFalseColor", input: input, values: [
                "inputColor0": CIColor(red: 0.03, green: 0.08, blue: 0.38),
                "inputColor1": CIColor(red: 1.0, green: 0.18, blue: 0.02)
            ]).cropped(to: extent)
            return mix(input, mapped, amount: try scalar(effect, V17EffectParameterID.intensity))
        case .colorMatrix:
            let a = try scalar(effect, V17EffectParameterID.amount)
            let base = 1.0 - abs(a) * 0.32
            let cross = a * 0.22
            return try apply("CIColorMatrix", input: input, values: [
                "inputRVector": CIVector(x: base, y: cross, z: -cross * 0.35, w: 0),
                "inputGVector": CIVector(x: -cross * 0.25, y: base, z: cross, w: 0),
                "inputBVector": CIVector(x: cross, y: -cross * 0.3, z: base, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ])
        case .maskToAlpha:
            return try apply("CIMaskToAlpha", input: input)
        case .edges:
            return try apply("CIEdges", input: input, values: [kCIInputIntensityKey: try scalar(effect, V17EffectParameterID.intensity)])
        case .affineTile:
            let scale = try scalar(effect, V17EffectParameterID.scale)
            let angle = try scalar(effect, V17EffectParameterID.angle) * .pi / 180
            let c = try center(effect, extent)
            var transform = CGAffineTransform(translationX: c.x, y: c.y)
            transform = transform.rotated(by: angle).scaledBy(x: scale, y: scale).translatedBy(x: -c.x, y: -c.y)
            return input.transformed(by: transform).applyingFilter("CIAffineTile").cropped(to: extent)
        case .vertexGlare:
            return try glare(effect, input: input)
        case .vertexLightStreaks:
            return try lightStreaks(effect, input: input)
        case .vertexAnalogDamage:
            return try analogDamage(effect, input: input, time: time)
        default:
            throw CompositionError.graphCompilationFailed("V17 effect route is incomplete: \(effect.type.rawValue).")
        }
    }

    private func glare(_ effect: ProjectEffect, input: CIImage) throws -> CIImage {
        let threshold = try scalar(effect, V17EffectParameterID.threshold)
        let radius = try scalar(effect, V17EffectParameterID.radius)
        let intensity = try scalar(effect, V17EffectParameterID.intensity)
        let bright = try thresholdImage(input, threshold: threshold)
        let near = try apply("CIGaussianBlur", input: bright, values: [kCIInputRadiusKey: max(0.5, radius * 0.45)]).cropped(to: input.extent)
        let far = try apply("CIGaussianBlur", input: bright, values: [kCIInputRadiusKey: max(1.0, radius * 1.7)]).cropped(to: input.extent)
        let boosted = try apply("CIColorMatrix", input: try addition(near, far), values: [
            "inputRVector": CIVector(x: intensity * 0.78, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: intensity * 0.90, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: intensity, w: 0)
        ])
        return try addition(input, boosted).cropped(to: input.extent)
    }

    private func lightStreaks(_ effect: ProjectEffect, input: CIImage) throws -> CIImage {
        let threshold = try scalar(effect, V17EffectParameterID.threshold)
        let length = try scalar(effect, V17EffectParameterID.length)
        let angle = try scalar(effect, V17EffectParameterID.angle) * .pi / 180
        let intensity = try scalar(effect, V17EffectParameterID.intensity)
        let bright = try thresholdImage(input, threshold: threshold)
        let streak = try apply("CIMotionBlur", input: bright, values: [kCIInputRadiusKey: length, kCIInputAngleKey: angle]).cropped(to: input.extent)
        let tint = try apply("CIColorMatrix", input: streak, values: [
            "inputRVector": CIVector(x: intensity, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: intensity * 0.82, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: intensity * 0.58, w: 0)
        ])
        return try addition(input, tint).cropped(to: input.extent)
    }

    private func analogDamage(_ effect: ProjectEffect, input: CIImage, time: RationalTime) throws -> CIImage {
        let seed = try integer(effect, V17EffectParameterID.seed)
        let amount = try scalar(effect, V17EffectParameterID.amount)
        let phase = Double(seed % 97) * 0.173 + time.seconds * 5.2
        let offset = CGFloat(sin(phase) * 14 * amount)
        let red = try apply("CIColorMatrix", input: input, values: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.34)
        ]).transformed(by: CGAffineTransform(translationX: offset, y: 0))
        let blue = try apply("CIColorMatrix", input: input, values: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.30)
        ]).transformed(by: CGAffineTransform(translationX: -offset * 0.75, y: 0))
        var result = try addition(input, try addition(red, blue)).cropped(to: input.extent)
        if amount > 0.001 {
            let stripes = try apply("CIStripesGenerator", values: [
                "inputCenter": CIVector(x: input.extent.midX, y: input.extent.midY + sin(phase * 0.7) * 18),
                "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: amount * 0.07),
                "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0),
                "inputWidth": 3.0 + amount * 4.0,
                "inputSharpness": 0.95
            ]).cropped(to: input.extent)
            result = stripes.composited(over: result).cropped(to: input.extent)
        }
        return result
    }

    private func thresholdImage(_ input: CIImage, threshold: Double) throws -> CIImage {
        try apply("CIColorThreshold", input: input, values: ["inputThreshold": threshold]).cropped(to: input.extent)
    }

    private func addition(_ a: CIImage, _ b: CIImage) throws -> CIImage {
        try apply("CIAdditionCompositing", input: b, values: [kCIInputBackgroundImageKey: a])
    }

    private func mix(_ a: CIImage, _ b: CIImage, amount: Double) -> CIImage {
        let alpha = min(max(amount, 0), 1)
        let faded = b.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)])
        return faded.composited(over: a).cropped(to: a.extent)
    }

    private func apply(_ name: String, input: CIImage? = nil, values: [String: Any] = [:]) throws -> CIImage {
        guard let filter = CIFilter(name: name) else { throw CompositionError.graphCompilationFailed("Core Image filter is unavailable: \(name).") }
        if let input { filter.setValue(input, forKey: kCIInputImageKey) }
        for (key, value) in values { filter.setValue(value, forKey: key) }
        guard let output = filter.outputImage else { throw CompositionError.graphCompilationFailed("Core Image filter produced no output: \(name).") }
        return output
    }

    private func center(_ effect: ProjectEffect, _ extent: CGRect) throws -> CGPoint {
        CGPoint(x: extent.minX + extent.width * (try scalar(effect, V17EffectParameterID.centerX)), y: extent.minY + extent.height * (try scalar(effect, V17EffectParameterID.centerY)))
    }

    private func scalar(_ effect: ProjectEffect, _ id: String) throws -> Double {
        guard case .scalar(let value)? = effect.parameter(id: id)?.value else { throw CompositionError.graphCompilationFailed("V17 scalar parameter is missing or invalid: \(id).") }
        return value
    }

    private func integer(_ effect: ProjectEffect, _ id: String) throws -> Int {
        guard case .integer(let value)? = effect.parameter(id: id)?.value else { throw CompositionError.graphCompilationFailed("V17 integer parameter is missing or invalid: \(id).") }
        return value
    }
}
