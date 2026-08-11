import Foundation

public enum V17EffectParameterID {
    public static let radius = "radius"
    public static let angle = "angle"
    public static let scale = "scale"
    public static let intensity = "intensity"
    public static let amount = "amount"
    public static let centerX = "centerX"
    public static let centerY = "centerY"
    public static let red = "red"
    public static let green = "green"
    public static let blue = "blue"
    public static let width = "width"
    public static let spacing = "spacing"
    public static let length = "length"
    public static let threshold = "threshold"
    public static let seed = "seed"
    public static let birthRate = "birthRate"
    public static let lifetime = "lifetime"
    public static let speed = "speed"
    public static let spread = "spread"
    public static let gravity = "gravity"
    public static let turbulence = "turbulence"
    public static let size = "size"
    public static let collision = "collision"
    public static let trails = "trails"
    public static let evolution = "evolution"
    public static let contrast = "contrast"
}

enum ProjectEffectV17Descriptors {
    private static func scalar(_ id: String, _ name: String, _ value: Double, _ range: ClosedRange<Double>, help: String = "") -> ProjectEffectParameterDescriptor {
        .init(id: id, displayName: name, defaultValue: .scalar(value), domain: .scalar(range), help: help)
    }

    private static func integer(_ id: String, _ name: String, _ value: Int, _ range: ClosedRange<Int>) -> ProjectEffectParameterDescriptor {
        .init(id: id, displayName: name, defaultValue: .integer(value), domain: .integer(range))
    }

    private static func boolean(_ id: String, _ name: String, _ value: Bool) -> ProjectEffectParameterDescriptor {
        .init(id: id, displayName: name, defaultValue: .boolean(value), domain: .boolean)
    }

    private static func descriptor(
        _ type: ProjectEffectType,
        _ name: String,
        _ category: ProjectEffectCategory,
        keywords: [String],
        summary: String,
        parameters: [ProjectEffectParameterDescriptor] = []
    ) -> ProjectEffectDescriptor {
        .init(type: type, displayName: name, category: category, executionMode: .nativePixel, keywords: keywords, summary: summary, parameters: parameters)
    }

    private static var center: [ProjectEffectParameterDescriptor] {
        [scalar(V17EffectParameterID.centerX, "Center X", 0.5, 0...1), scalar(V17EffectParameterID.centerY, "Center Y", 0.5, 0...1)]
    }

    private static func particleParameters(
        birthRate: Double,
        lifetime: Double,
        speed: Double,
        spread: Double,
        gravity: Double,
        turbulence: Double,
        size: Double,
        trails: Bool = false
    ) -> [ProjectEffectParameterDescriptor] {
        [
            integer(V17EffectParameterID.seed, "Seed", 1701, 0...999_999),
            scalar(V17EffectParameterID.birthRate, "Birth Rate", birthRate, 0...2_000),
            scalar(V17EffectParameterID.lifetime, "Lifetime", lifetime, 0.05...30),
            scalar(V17EffectParameterID.speed, "Speed", speed, 0...4),
            scalar(V17EffectParameterID.spread, "Spread", spread, 0...360),
            scalar(V17EffectParameterID.gravity, "Gravity", gravity, -3...3),
            scalar(V17EffectParameterID.turbulence, "Turbulence", turbulence, 0...1),
            scalar(V17EffectParameterID.size, "Particle Size", size, 0.001...0.15),
            scalar(V17EffectParameterID.intensity, "Opacity", 0.9, 0...1),
            boolean(V17EffectParameterID.collision, "Collision", false),
            boolean(V17EffectParameterID.trails, "Trails", trails)
        ]
    }

    static let all: [ProjectEffectDescriptor] = [
        descriptor(.motionBlur, "Motion Blur", .blurAndSharpen, keywords: ["motion", "blur", "direction"], summary: "Directional motion blur through the native preview/export path.", parameters: [scalar(V17EffectParameterID.radius, "Radius", 20, 0...250), scalar(V17EffectParameterID.angle, "Angle", 0, -180...180)]),
        descriptor(.pixelate, "Pixelate", .stylize, keywords: ["pixel", "pixelate", "mosaic"], summary: "Center-aware square pixelation independent from the legacy mosaic control.", parameters: [scalar(V17EffectParameterID.scale, "Pixel Size", 18, 1...300)] + center),
        descriptor(.sharpenLuminance, "Sharpen Luminance", .blurAndSharpen, keywords: ["sharpen", "luma", "detail"], summary: "Luminance-focused sharpening with radius control.", parameters: [scalar(V17EffectParameterID.intensity, "Sharpness", 0.45, 0...2), scalar(V17EffectParameterID.radius, "Radius", 1.5, 0...20)]),
        descriptor(.maximumComponent, "Maximum Component", .channel, keywords: ["channel", "maximum", "rgb"], summary: "Maps each pixel to its strongest color component for channel analysis and stylization."),
        descriptor(.minimumComponent, "Minimum Component", .channel, keywords: ["channel", "minimum", "rgb"], summary: "Maps each pixel to its weakest color component for channel analysis and stylization."),
        descriptor(.whitePointAdjust, "White Point", .colorCorrection, keywords: ["white point", "balance", "color"], summary: "Adjust image white point with independent RGB controls.", parameters: [scalar(V17EffectParameterID.red, "Red", 1, 0...1), scalar(V17EffectParameterID.green, "Green", 1, 0...1), scalar(V17EffectParameterID.blue, "Blue", 1, 0...1)]),
        descriptor(.falseColor, "False Color", .colorCorrection, keywords: ["false color", "exposure", "analysis"], summary: "Vertex false-color exposure visualization with adjustable mix.", parameters: [scalar(V17EffectParameterID.intensity, "Mix", 1, 0...1)]),
        descriptor(.colorMatrix, "Color Matrix", .channel, keywords: ["matrix", "channel", "color"], summary: "Cross-channel color matrix treatment with animated strength.", parameters: [scalar(V17EffectParameterID.amount, "Amount", 0, -1...1)]),
        descriptor(.maskToAlpha, "Mask to Alpha", .keying, keywords: ["mask", "alpha", "matte"], summary: "Converts image luminance into an alpha representation for matte workflows."),
        descriptor(.edges, "Edges", .stylize, keywords: ["edge", "outline", "sobel"], summary: "High-contrast edge extraction with independent intensity.", parameters: [scalar(V17EffectParameterID.intensity, "Intensity", 1, 0...10)]),
        descriptor(.affineTile, "Affine Tile", .tile, keywords: ["tile", "repeat", "transform"], summary: "Repeating affine tile transform with animated scale and angle.", parameters: [scalar(V17EffectParameterID.scale, "Scale", 1, 0.1...5), scalar(V17EffectParameterID.angle, "Angle", 0, -180...180)] + center),
        descriptor(.checkerboard, "Checkerboard", .particlesAndProcedural, keywords: ["checker", "grid", "generator"], summary: "Deterministic procedural checker pattern composited over the source.", parameters: [scalar(V17EffectParameterID.scale, "Cell Size", 48, 2...500), scalar(V17EffectParameterID.intensity, "Opacity", 0.6, 0...1)]),
        descriptor(.stripes, "Stripes", .particlesAndProcedural, keywords: ["stripe", "line", "generator"], summary: "Procedural stripe pattern with width, angle, and opacity controls.", parameters: [scalar(V17EffectParameterID.width, "Width", 24, 1...300), scalar(V17EffectParameterID.angle, "Angle", 0, -180...180), scalar(V17EffectParameterID.intensity, "Opacity", 0.5, 0...1)]),
        descriptor(.starShine, "Star Shine", .particlesAndProcedural, keywords: ["star", "shine", "generator"], summary: "Procedural star-shine generator for flares and graphic accents.", parameters: [scalar(V17EffectParameterID.radius, "Radius", 40, 1...500), scalar(V17EffectParameterID.intensity, "Intensity", 0.8, 0...2)] + center),
        descriptor(.vertexGlare, "Vertex Glare", .stylize, keywords: ["vertex", "glare", "bloom", "highlight"], summary: "Vertex-owned thresholded multi-scale glare built without third-party shaders.", parameters: [scalar(V17EffectParameterID.threshold, "Threshold", 0.68, 0...1), scalar(V17EffectParameterID.radius, "Radius", 28, 0...250), scalar(V17EffectParameterID.intensity, "Intensity", 0.9, 0...3)]),
        descriptor(.vertexLightStreaks, "Vertex Light Streaks", .stylize, keywords: ["vertex", "streak", "light", "glare"], summary: "Vertex-owned directional highlight streak chain.", parameters: [scalar(V17EffectParameterID.threshold, "Threshold", 0.72, 0...1), scalar(V17EffectParameterID.length, "Length", 55, 0...300), scalar(V17EffectParameterID.angle, "Angle", 0, -180...180), scalar(V17EffectParameterID.intensity, "Intensity", 0.8, 0...3)]),
        descriptor(.vertexAnalogDamage, "Vertex Analog Damage", .stylize, keywords: ["vertex", "analog", "tape", "damage"], summary: "Vertex-owned scan jitter, channel offset, and deterministic grain treatment.", parameters: [integer(V17EffectParameterID.seed, "Seed", 1717, 0...999_999), scalar(V17EffectParameterID.amount, "Damage", 0.35, 0...1)]),

        descriptor(.vertexParticleField, "Vertex Particle Field", .particlesAndProcedural, keywords: ["particle", "field", "emitter"], summary: "General deterministic GPU particle emitter.", parameters: particleParameters(birthRate: 90, lifetime: 2.8, speed: 0.13, spread: 180, gravity: 0.05, turbulence: 0.12, size: 0.012)),
        descriptor(.vertexSparks, "Vertex Sparks", .particlesAndProcedural, keywords: ["particle", "spark", "trail"], summary: "Fast additive spark emitter with optional trails.", parameters: particleParameters(birthRate: 130, lifetime: 1.2, speed: 0.55, spread: 70, gravity: 0.45, turbulence: 0.08, size: 0.007, trails: true)),
        descriptor(.vertexSnow, "Vertex Snow", .particlesAndProcedural, keywords: ["particle", "snow", "weather"], summary: "Deterministic drifting snow field.", parameters: particleParameters(birthRate: 110, lifetime: 6.0, speed: 0.08, spread: 30, gravity: 0.06, turbulence: 0.2, size: 0.014)),
        descriptor(.vertexDust, "Vertex Dust", .particlesAndProcedural, keywords: ["particle", "dust", "atmosphere"], summary: "Slow atmospheric dust particles with soft turbulence.", parameters: particleParameters(birthRate: 65, lifetime: 7.5, speed: 0.035, spread: 360, gravity: -0.005, turbulence: 0.15, size: 0.009)),
        descriptor(.vertexStarfield, "Vertex Starfield", .particlesAndProcedural, keywords: ["particle", "star", "space"], summary: "Seeded starfield particles for space and depth backgrounds.", parameters: particleParameters(birthRate: 40, lifetime: 10, speed: 0.02, spread: 360, gravity: 0, turbulence: 0.01, size: 0.006)),
        descriptor(.vertexTrailParticles, "Vertex Trail Particles", .particlesAndProcedural, keywords: ["particle", "trail", "motion"], summary: "Particle emitter optimized for deterministic history trails.", parameters: particleParameters(birthRate: 85, lifetime: 2.2, speed: 0.28, spread: 120, gravity: 0.1, turbulence: 0.1, size: 0.009, trails: true)),
        descriptor(.vertexFractalNoise, "Vertex Fractal Noise", .particlesAndProcedural, keywords: ["fractal", "noise", "cloud", "procedural"], summary: "Seeded multi-octave Vertex noise texture.", parameters: [integer(V17EffectParameterID.seed, "Seed", 1701, 0...999_999), scalar(V17EffectParameterID.scale, "Scale", 90, 2...600), scalar(V17EffectParameterID.evolution, "Evolution", 0, -20...20), scalar(V17EffectParameterID.contrast, "Contrast", 1, 0...4)]),
        descriptor(.vertexTurbulenceTexture, "Vertex Turbulence Texture", .particlesAndProcedural, keywords: ["turbulence", "noise", "flow"], summary: "Seeded warped turbulence texture for displacement-like motion graphics.", parameters: [integer(V17EffectParameterID.seed, "Seed", 1711, 0...999_999), scalar(V17EffectParameterID.scale, "Scale", 70, 2...600), scalar(V17EffectParameterID.evolution, "Evolution", 0, -20...20), scalar(V17EffectParameterID.intensity, "Intensity", 0.8, 0...2)]),
        descriptor(.vertexPlasma, "Vertex Plasma", .particlesAndProcedural, keywords: ["plasma", "waves", "procedural"], summary: "Vertex-owned layered sinusoidal plasma field.", parameters: [scalar(V17EffectParameterID.scale, "Scale", 4, 0.2...20), scalar(V17EffectParameterID.evolution, "Evolution", 0, -20...20), scalar(V17EffectParameterID.intensity, "Opacity", 0.8, 0...1)]),
        descriptor(.vertexCellularTexture, "Vertex Cellular Texture", .particlesAndProcedural, keywords: ["cellular", "voronoi", "procedural"], summary: "Seeded cellular/Voronoi-like texture generated locally.", parameters: [integer(V17EffectParameterID.seed, "Seed", 1721, 0...999_999), scalar(V17EffectParameterID.scale, "Cell Size", 55, 4...400), scalar(V17EffectParameterID.contrast, "Contrast", 1.2, 0...4)]),
        descriptor(.vertexGrid, "Vertex Grid", .particlesAndProcedural, keywords: ["grid", "line", "procedural"], summary: "Procedural motion-design grid with animated spacing and line width.", parameters: [scalar(V17EffectParameterID.spacing, "Spacing", 64, 4...500), scalar(V17EffectParameterID.width, "Line Width", 2, 0.5...50), scalar(V17EffectParameterID.angle, "Angle", 0, -180...180), scalar(V17EffectParameterID.intensity, "Opacity", 0.65, 0...1)]),
        descriptor(.vertexRings, "Vertex Rings", .particlesAndProcedural, keywords: ["ring", "radial", "procedural"], summary: "Procedural concentric ring generator for graphic motion design.", parameters: [scalar(V17EffectParameterID.spacing, "Spacing", 42, 2...300), scalar(V17EffectParameterID.width, "Ring Width", 3, 0.5...50), scalar(V17EffectParameterID.intensity, "Opacity", 0.7, 0...1)] + center)
    ]
}
