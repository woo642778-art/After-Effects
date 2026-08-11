import CoreGraphics
import CoreImage
import Foundation
import VertexComposition
import VertexProject

/// Native implementations added by the large V16 effects expansion.
///
/// Commercial plugin binaries, shaders, presets and assets are not used here. The
/// Vertex-prefixed looks are independent Core Image filter chains built from public
/// image-processing primitives.
struct NativeExpandedFrameEffectProcessor {
    private static let legacyNativeTypes: Set<ProjectEffectType> = [
        .gaussianBlur, .fastBoxBlur, .directionalBlur, .sharpen, .median, .noiseReduction,
        .exposure, .colorControls, .hueAdjust, .vibrance, .gammaAdjust, .highlightShadow,
        .sepiaTone, .invert, .posterize, .mosaic, .findEdges, .glow, .vignette, .cartoon, .twirl
    ]

    static let expandedTypes: Set<ProjectEffectType> = Set(
        ProjectEffectType.allCases.filter { $0.isNativePixelEffect && !legacyNativeTypes.contains($0) }
    )

    func filteredImage(effect: ProjectEffect, input: CIImage) throws -> CIImage? {
        guard Self.expandedTypes.contains(effect.type) else { return nil }
        let extent = input.extent

        switch effect.type {
        // MARK: Blur & Sharpen
        case .discBlur:
            return try apply("CIDiscBlur", input: input, values: ["inputRadius": try scalar(effect, .radius)])
        case .zoomBlur:
            return try apply("CIZoomBlur", input: input, values: [
                "inputCenter": try center(effect, in: extent),
                "inputAmount": try scalar(effect, .amount)
            ])
        case .bokehBlur:
            return try apply("CIBokehBlur", input: input, values: [
                "inputRadius": try scalar(effect, .radius),
                "inputRingAmount": try scalar(effect, .ringAmount),
                "inputRingSize": try scalar(effect, .ringSize),
                "inputSoftness": try scalar(effect, .softness)
            ])
        case .unsharpMask:
            return try apply("CIUnsharpMask", input: input, values: [
                "inputRadius": try scalar(effect, .radius),
                "inputIntensity": try scalar(effect, .intensity)
            ])
        case .morphologyGradient:
            return try apply("CIMorphologyGradient", input: input, values: ["inputRadius": try scalar(effect, .radius)])
        case .morphologyMinimum:
            return try apply("CIMorphologyMinimum", input: input, values: ["inputRadius": try scalar(effect, .radius)])
        case .morphologyMaximum:
            return try apply("CIMorphologyMaximum", input: input, values: ["inputRadius": try scalar(effect, .radius)])
        case .morphologyRectangleMinimum:
            return try apply("CIMorphologyRectangleMinimum", input: input, values: [
                "inputWidth": try scalar(effect, .width), "inputHeight": try scalar(effect, .height)
            ])
        case .morphologyRectangleMaximum:
            return try apply("CIMorphologyRectangleMaximum", input: input, values: [
                "inputWidth": try scalar(effect, .width), "inputHeight": try scalar(effect, .height)
            ])
        case .depthOfField:
            let y = extent.minY + extent.height * (try scalar(effect, .focusPosition))
            let half = max(1, extent.height * (try scalar(effect, .focusWidth)) * 0.5)
            return try apply("CIDepthOfField", input: input, values: [
                "inputPoint0": CIVector(x: extent.minX, y: y - half),
                "inputPoint1": CIVector(x: extent.maxX, y: y + half),
                "inputSaturation": try scalar(effect, .saturation),
                "inputUnsharpMaskRadius": 2.0,
                "inputUnsharpMaskIntensity": 0.4,
                "inputRadius": try scalar(effect, .radius)
            ])

        // MARK: Color / Channel
        case .temperatureTint:
            return try apply("CITemperatureAndTint", input: input, values: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: try scalar(effect, .temperature), y: try scalar(effect, .tint))
            ])
        case .colorMonochrome:
            return try apply("CIColorMonochrome", input: input, values: [
                "inputColor": CIColor(red: 0.76, green: 0.78, blue: 0.82),
                "inputIntensity": try scalar(effect, .intensity)
            ])
        case .colorClamp:
            let lower = try scalar(effect, .minimum)
            let upper = max(lower, try scalar(effect, .maximum))
            return try apply("CIColorClamp", input: input, values: [
                "inputMinComponents": CIVector(x: lower, y: lower, z: lower, w: 0),
                "inputMaxComponents": CIVector(x: upper, y: upper, z: upper, w: 1)
            ])
        case .photoChrome: return try apply("CIPhotoEffectChrome", input: input)
        case .photoFade: return try apply("CIPhotoEffectFade", input: input)
        case .photoInstant: return try apply("CIPhotoEffectInstant", input: input)
        case .photoMono: return try apply("CIPhotoEffectMono", input: input)
        case .photoNoir: return try apply("CIPhotoEffectNoir", input: input)
        case .photoProcess: return try apply("CIPhotoEffectProcess", input: input)
        case .photoTonal: return try apply("CIPhotoEffectTonal", input: input)
        case .photoTransfer: return try apply("CIPhotoEffectTransfer", input: input)
        case .linearToSRGB: return try apply("CILinearToSRGBToneCurve", input: input)
        case .sRGBToLinear: return try apply("CISRGBToneCurveToLinear", input: input)
        case .colorThreshold:
            return try threshold(input, value: try scalar(effect, .threshold))
        case .colorThresholdOtsu:
            return try apply("CIColorThresholdOtsu", input: input)

        // MARK: Stylize / Halftone
        case .crystallize:
            return try apply("CICrystallize", input: input, values: [
                "inputRadius": try scalar(effect, .radius), "inputCenter": try center(effect, in: extent)
            ])
        case .edgeWork:
            return try apply("CIEdgeWork", input: input, values: ["inputRadius": try scalar(effect, .radius)])
        case .gloom:
            return try apply("CIGloom", input: input, values: [
                "inputRadius": try scalar(effect, .radius), "inputIntensity": try scalar(effect, .intensity)
            ])
        case .hexagonalPixelate:
            return try apply("CIHexagonalPixellate", input: input, values: [
                "inputScale": try scalar(effect, .scale), "inputCenter": try center(effect, in: extent)
            ])
        case .lineOverlay:
            return try apply("CILineOverlay", input: input, values: [
                "inputNRNoiseLevel": try scalar(effect, .noiseLevel),
                "inputNRSharpness": try scalar(effect, .sharpness),
                "inputEdgeIntensity": try scalar(effect, .edgeIntensity),
                "inputThreshold": try scalar(effect, .threshold),
                "inputContrast": try scalar(effect, .contrast)
            ])
        case .pointillize:
            return try apply("CIPointillize", input: input, values: [
                "inputRadius": try scalar(effect, .radius), "inputCenter": try center(effect, in: extent)
            ])
        case .circularScreen:
            return try apply("CICircularScreen", input: input, values: screenValues(effect, extent: extent, includeAngle: false))
        case .dotScreen:
            return try apply("CIDotScreen", input: input, values: screenValues(effect, extent: extent, includeAngle: true))
        case .hatchedScreen:
            return try apply("CIHatchedScreen", input: input, values: screenValues(effect, extent: extent, includeAngle: true))
        case .lineScreen:
            return try apply("CILineScreen", input: input, values: screenValues(effect, extent: extent, includeAngle: true))
        case .cmykHalftone:
            return try apply("CICMYKHalftone", input: input, values: screenValues(effect, extent: extent, includeAngle: true))

        // MARK: Distort
        case .bumpDistortion:
            return try apply("CIBumpDistortion", input: input, values: try radialDistortionValues(effect, extent: extent, hasScale: true))
        case .bumpLinear:
            var values = try radialDistortionValues(effect, extent: extent, hasScale: true)
            values["inputAngle"] = radians(try scalar(effect, .angle))
            return try apply("CIBumpDistortionLinear", input: input, values: values)
        case .circleSplash:
            return try apply("CICircleSplashDistortion", input: input, values: try radialDistortionValues(effect, extent: extent, hasScale: false))
        case .circularWrap:
            return try apply("CICircularWrap", input: input, values: [
                "inputCenter": try center(effect, in: extent),
                "inputRadius": try scalar(effect, .radius),
                "inputAngle": radians(try scalar(effect, .angle))
            ])
        case .droste:
            let inset = try scalar(effect, .inset)
            let p0 = CIVector(x: extent.minX + extent.width * inset, y: extent.minY + extent.height * inset)
            let p1 = CIVector(x: extent.maxX - extent.width * inset, y: extent.maxY - extent.height * inset)
            return try apply("CIDroste", input: input, values: [
                "inputInsetPoint0": p0, "inputInsetPoint1": p1,
                "inputStrands": try scalar(effect, .strands),
                "inputPeriodicity": try scalar(effect, .periodicity),
                "inputRotation": radians(try scalar(effect, .rotation)),
                "inputZoom": try scalar(effect, .zoom)
            ])
        case .holeDistortion:
            return try apply("CIHoleDistortion", input: input, values: try radialDistortionValues(effect, extent: extent, hasScale: false))
        case .lightTunnel:
            return try apply("CILightTunnel", input: input, values: [
                "inputCenter": try center(effect, in: extent),
                "inputRotation": radians(try scalar(effect, .rotation)),
                "inputRadius": try scalar(effect, .radius)
            ])
        case .pinchDistortion:
            return try apply("CIPinchDistortion", input: input, values: try radialDistortionValues(effect, extent: extent, hasScale: true))
        case .stretchCrop:
            return try apply("CIStretchCrop", input: input, values: [
                "inputSize": CIVector(x: extent.width, y: extent.height),
                "inputCropAmount": try scalar(effect, .cropAmount),
                "inputCenterStretchAmount": try scalar(effect, .centerStretch)
            ])
        case .torusLens:
            return try apply("CITorusLensDistortion", input: input, values: [
                "inputCenter": try center(effect, in: extent),
                "inputRadius": try scalar(effect, .radius),
                "inputWidth": try scalar(effect, .width),
                "inputRefraction": try scalar(effect, .refraction)
            ])
        case .vortexDistortion:
            return try apply("CIVortexDistortion", input: input, values: [
                "inputCenter": try center(effect, in: extent),
                "inputRadius": try scalar(effect, .radius),
                "inputAngle": radians(try scalar(effect, .angle))
            ])
        case .glassLozenge:
            let c = try point(effect, in: extent)
            let length = try scalar(effect, .length)
            let a = radians(try scalar(effect, .angle))
            let dx = cos(a) * length * 0.5
            let dy = sin(a) * length * 0.5
            return try apply("CIGlassLozenge", input: input, values: [
                "inputPoint0": CIVector(x: c.x - dx, y: c.y - dy),
                "inputPoint1": CIVector(x: c.x + dx, y: c.y + dy),
                "inputRadius": try scalar(effect, .radius),
                "inputRefraction": try scalar(effect, .refraction)
            ])

        // MARK: Tile
        case .kaleidoscope:
            return try apply("CIKaleidoscope", input: input, values: [
                "inputCount": try scalar(effect, .count),
                "inputCenter": try center(effect, in: extent),
                "inputAngle": radians(try scalar(effect, .angle))
            ])
        case .opTile:
            var values = try tileValues(effect, extent: extent)
            values["inputScale"] = 2.8
            return try apply("CIOpTile", input: input, values: values)
        case .triangleKaleidoscope:
            return try apply("CITriangleKaleidoscope", input: input, values: [
                "inputPoint": try center(effect, in: extent),
                "inputSize": try scalar(effect, .width) * 7,
                "inputRotation": radians(try scalar(effect, .rotation)),
                "inputDecay": try scalar(effect, .decay)
            ])
        case .sixfoldReflectedTile:
            return try apply("CISixfoldReflectedTile", input: input, values: try tileValues(effect, extent: extent))
        case .twelvefoldReflectedTile:
            return try apply("CITwelvefoldReflectedTile", input: input, values: try tileValues(effect, extent: extent))
        case .parallelogramTile:
            var values = try tileValues(effect, extent: extent)
            values["inputAcuteAngle"] = Double.pi / 2
            return try apply("CIParallelogramTile", input: input, values: values)
        case .triangleTile:
            return try apply("CITriangleTile", input: input, values: try tileValues(effect, extent: extent))
        case .fourfoldReflectedTile:
            return try apply("CIFourfoldReflectedTile", input: input, values: try tileValues(effect, extent: extent))
        case .fourfoldRotatedTile:
            return try apply("CIFourfoldRotatedTile", input: input, values: try tileValues(effect, extent: extent))
        case .fourfoldTranslatedTile:
            return try apply("CIFourfoldTranslatedTile", input: input, values: try tileValues(effect, extent: extent))
        case .eightfoldReflectedTile:
            return try apply("CIEightfoldReflectedTile", input: input, values: try tileValues(effect, extent: extent))
        case .glideReflectedTile:
            return try apply("CIGlideReflectedTile", input: input, values: try tileValues(effect, extent: extent))
        case .sixfoldRotatedTile:
            return try apply("CISixfoldRotatedTile", input: input, values: try tileValues(effect, extent: extent))

        // MARK: Vertex2 clean-room looks
        case .vertexAuraGlow:
            return try auraGlow(effect, input: input)
        case .vertexDarkGlow:
            return try darkBloom(effect, input: input)
        case .vertexEdgeGlow:
            return try edgeRadiance(effect, input: input)
        case .vertexHalation:
            return try halation(effect, input: input)
        case .vertexFilmGrain:
            return try filmGrain(effect, input: input)
        case .vertexScanlines:
            return try scanlines(effect, input: input)
        case .vertexRGBSplit:
            return try rgbSplit(effect, input: input)
        case .vertexPrismBlur:
            return try apply("CIGaussianBlur", input: try rgbSplit(effect, input: input, amountID: .amount), values: [
                "inputRadius": try scalar(effect, .radius)
            ])
        case .vertexLightLeak:
            return try lightLeak(effect, input: input)
        case .vertexSunRays:
            return try sunRays(effect, input: input)

        // MARK: Keying / mattes
        case .lumaKey:
            return try lumaKey(effect, input: input)
        case .brightMatte:
            return try matte(effect, input: input, invert: false)
        case .darkMatte:
            return try matte(effect, input: input, invert: true)

        default:
            return nil
        }
    }

    // MARK: Core Image helpers

    private enum Parameter: String {
        case radius, amount, centerX, centerY, ringAmount, ringSize, softness, intensity
        case width, height, temperature, tint, minimum, maximum, scale, noiseLevel, sharpness
        case edgeIntensity, threshold, contrast, angle, focusPosition, focusWidth, saturation
        case inset, strands, periodicity, rotation, zoom, cropAmount, centerStretch, refraction
        case length, count, decay, chroma, size, frequency
    }

    private func scalar(_ effect: ProjectEffect, _ id: Parameter) throws -> CGFloat {
        guard case .scalar(let value)? = effect.parameter(id: id.rawValue)?.value, value.isFinite else {
            throw CompositionError.graphCompilationFailed("Expanded effect parameter is missing or invalid: \(id.rawValue).")
        }
        return CGFloat(value)
    }

    private func radians(_ degrees: CGFloat) -> CGFloat { degrees * .pi / 180 }

    private func point(_ effect: ProjectEffect, in extent: CGRect) throws -> CGPoint {
        CGPoint(
            x: extent.minX + extent.width * (try scalar(effect, .centerX)),
            y: extent.minY + extent.height * (try scalar(effect, .centerY))
        )
    }

    private func center(_ effect: ProjectEffect, in extent: CGRect) throws -> CIVector {
        let p = try point(effect, in: extent)
        return CIVector(x: p.x, y: p.y)
    }

    private func apply(_ name: String, input: CIImage? = nil, values: [String: Any] = [:]) throws -> CIImage {
        guard let filter = CIFilter(name: name) else {
            throw CompositionError.graphCompilationFailed("Core Image filter is unavailable on this device: \(name).")
        }
        if let input, filter.inputKeys.contains(kCIInputImageKey) {
            filter.setValue(input, forKey: kCIInputImageKey)
        }
        for (key, value) in values where filter.inputKeys.contains(key) {
            filter.setValue(value, forKey: key)
        }
        guard let output = filter.outputImage else {
            throw CompositionError.graphCompilationFailed("Core Image filter produced no output: \(name).")
        }
        return output
    }

    private func screen(_ foreground: CIImage, over background: CIImage) throws -> CIImage {
        try apply("CIScreenBlendMode", input: foreground, values: [kCIInputBackgroundImageKey: background])
    }

    private func add(_ foreground: CIImage, over background: CIImage) throws -> CIImage {
        try apply("CIAdditionCompositing", input: foreground, values: [kCIInputBackgroundImageKey: background])
    }

    private func multiply(_ foreground: CIImage, over background: CIImage) throws -> CIImage {
        try apply("CIMultiplyBlendMode", input: foreground, values: [kCIInputBackgroundImageKey: background])
    }

    private func scaleRGB(_ image: CIImage, amount: CGFloat) throws -> CIImage {
        try apply("CIColorMatrix", input: image, values: [
            "inputRVector": CIVector(x: amount, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: amount, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: amount, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
    }

    private func threshold(_ image: CIImage, value: CGFloat) throws -> CIImage {
        if CIFilter(name: "CIColorThreshold") != nil {
            return try apply("CIColorThreshold", input: image, values: ["inputThreshold": value])
        }
        // iPadOS 17 contains CIColorThreshold; this fallback keeps project portability
        // deterministic on older Core Image environments used by tooling.
        return try apply("CIColorControls", input: image, values: [
            kCIInputSaturationKey: 0,
            kCIInputContrastKey: 12,
            kCIInputBrightnessKey: (0.5 - value) * 2
        ])
    }

    private func lumaMask(_ image: CIImage, threshold value: CGFloat, softness: CGFloat = 0, invert: Bool = false) throws -> CIImage {
        var gray = try apply("CIColorControls", input: image, values: [kCIInputSaturationKey: 0])
        if invert { gray = try apply("CIColorInvert", input: gray) }
        var mask = try threshold(gray, value: value)
        if softness > 0 {
            mask = try apply("CIGaussianBlur", input: mask, values: ["inputRadius": softness * 40])
        }
        return mask
    }

    private func transparent(extent: CGRect) throws -> CIImage {
        try apply("CIConstantColorGenerator", values: ["inputColor": CIColor(red: 0, green: 0, blue: 0, alpha: 0)])
            .cropped(to: extent)
    }

    private func maskedSource(_ source: CIImage, mask: CIImage) throws -> CIImage {
        try apply("CIBlendWithMask", input: source, values: [
            kCIInputBackgroundImageKey: transparent(extent: source.extent),
            kCIInputMaskImageKey: mask
        ])
    }

    private func screenValues(_ effect: ProjectEffect, extent: CGRect, includeAngle: Bool) throws -> [String: Any] {
        var values: [String: Any] = [
            "inputCenter": try center(effect, in: extent),
            "inputWidth": try scalar(effect, .width),
            "inputSharpness": try scalar(effect, .sharpness)
        ]
        if includeAngle { values["inputAngle"] = radians(try scalar(effect, .angle)) }
        return values
    }

    private func radialDistortionValues(_ effect: ProjectEffect, extent: CGRect, hasScale: Bool) throws -> [String: Any] {
        var values: [String: Any] = [
            "inputCenter": try center(effect, in: extent),
            "inputRadius": try scalar(effect, .radius)
        ]
        if hasScale { values["inputScale"] = try scalar(effect, .scale) }
        return values
    }

    private func tileValues(_ effect: ProjectEffect, extent: CGRect) throws -> [String: Any] {
        [
            "inputCenter": try center(effect, in: extent),
            "inputAngle": radians(try scalar(effect, .angle)),
            "inputWidth": try scalar(effect, .width)
        ]
    }

    // MARK: Vertex-owned composite looks

    private func auraGlow(_ effect: ProjectEffect, input: CIImage) throws -> CIImage {
        let mask = try lumaMask(input, threshold: try scalar(effect, .threshold), softness: 0.01)
        let selected = try maskedSource(input, mask: mask)
        let r = try scalar(effect, .radius)
        let near = try apply("CIGaussianBlur", input: selected, values: ["inputRadius": r])
        let far = try apply("CIGaussianBlur", input: selected, values: ["inputRadius": r * 2.25])
        let bloom = try add(try scaleRGB(near, amount: try scalar(effect, .intensity)), over: try scaleRGB(far, amount: try scalar(effect, .intensity) * 0.45))
        return try screen(bloom, over: input)
    }

    private func darkBloom(_ effect: ProjectEffect, input: CIImage) throws -> CIImage {
        let mask = try lumaMask(input, threshold: 1 - (try scalar(effect, .threshold)), softness: 0.02, invert: true)
        let black = try apply("CIConstantColorGenerator", values: ["inputColor": CIColor(red: 0.02, green: 0.03, blue: 0.05, alpha: try scalar(effect, .intensity) * 0.45)]).cropped(to: input.extent)
        let darkContribution = try maskedSource(black, mask: mask)
        let blurred = try apply("CIGaussianBlur", input: darkContribution, values: ["inputRadius": try scalar(effect, .radius)])
        return try multiply(blurred, over: input)
    }

    private func edgeRadiance(_ effect: ProjectEffect, input: CIImage) throws -> CIImage {
        let edges = try apply("CIEdges", input: input, values: ["inputIntensity": try scalar(effect, .intensity)])
        let bloom = try apply("CIBloom", input: edges, values: [
            "inputRadius": try scalar(effect, .radius), "inputIntensity": try scalar(effect, .intensity)
        ])
        return try screen(bloom, over: input)
    }

    private func halation(_ effect: ProjectEffect, input: CIImage) throws -> CIImage {
        let mask = try lumaMask(input, threshold: try scalar(effect, .threshold), softness: 0.025)
        var selected = try maskedSource(input, mask: mask)
        selected = try apply("CIColorMatrix", input: selected, values: [
            "inputRVector": CIVector(x: 1.15, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0.35, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0.15, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        selected = try apply("CIGaussianBlur", input: selected, values: ["inputRadius": try scalar(effect, .radius)])
        return try screen(try scaleRGB(selected, amount: try scalar(effect, .intensity)), over: input)
    }

    private func filmGrain(_ effect: ProjectEffect, input: CIImage) throws -> CIImage {
        var noise = try apply("CIRandomGenerator").cropped(to: input.extent)
        let size = max(1, try scalar(effect, .size))
        if size > 1 {
            noise = noise.transformed(by: CGAffineTransform(scaleX: size, y: size)).cropped(to: input.extent)
        }
        noise = try apply("CIColorControls", input: noise, values: [
            kCIInputSaturationKey: try scalar(effect, .chroma),
            kCIInputContrastKey: max(0.01, try scalar(effect, .amount) * 2),
            kCIInputBrightnessKey: -0.05
        ])
        return try apply("CISoftLightBlendMode", input: noise, values: [kCIInputBackgroundImageKey: input])
    }

    private func scanlines(_ effect: ProjectEffect, input: CIImage) throws -> CIImage {
        let spacing = max(1, try scalar(effect, .frequency))
        let intensity = try scalar(effect, .intensity)
        var lines = try apply("CIStripesGenerator", values: [
            "inputCenter": CIVector(x: input.extent.midX, y: input.extent.midY),
            "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: 1),
            "inputColor1": CIColor(red: 1 - intensity, green: 1 - intensity, blue: 1 - intensity, alpha: 1),
            "inputWidth": spacing,
            "inputSharpness": 1.0
        ])
        let a = radians(try scalar(effect, .angle) + 90)
        lines = lines.transformed(by: CGAffineTransform(rotationAngle: a)).cropped(to: input.extent)
        return try multiply(lines, over: input)
    }

    private func rgbSplit(_ effect: ProjectEffect, input: CIImage, amountID: Parameter = .amount) throws -> CIImage {
        let amount = try scalar(effect, amountID)
        let a = radians(try scalar(effect, .angle))
        let dx = cos(a) * amount
        let dy = sin(a) * amount
        let r = try channel(input, vector: CIVector(x: 1, y: 0, z: 0, w: 0)).transformed(by: CGAffineTransform(translationX: dx, y: dy))
        let g = try channel(input, vector: CIVector(x: 0, y: 1, z: 0, w: 0))
        let b = try channel(input, vector: CIVector(x: 0, y: 0, z: 1, w: 0)).transformed(by: CGAffineTransform(translationX: -dx, y: -dy))
        return try add(r, over: try add(g, over: b))
    }

    private func channel(_ input: CIImage, vector: CIVector) throws -> CIImage {
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        let r = vector.x > 0 ? vector : zero
        let g = vector.y > 0 ? vector : zero
        let b = vector.z > 0 ? vector : zero
        return try apply("CIColorMatrix", input: input, values: [
            "inputRVector": r,
            "inputGVector": g,
            "inputBVector": b,
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
    }

    private func lightLeak(_ effect: ProjectEffect, input: CIImage) throws -> CIImage {
        let p = try center(effect, in: input.extent)
        let intensity = try scalar(effect, .intensity)
        let gradient = try apply("CIRadialGradient", values: [
            "inputCenter": p,
            "inputRadius0": 0,
            "inputRadius1": try scalar(effect, .radius),
            "inputColor0": CIColor(red: 1, green: 0.24, blue: 0.04, alpha: min(1, intensity)),
            "inputColor1": CIColor(red: 0.35, green: 0.02, blue: 0.12, alpha: 0)
        ]).cropped(to: input.extent)
        return try screen(gradient, over: input)
    }

    private func sunRays(_ effect: ProjectEffect, input: CIImage) throws -> CIImage {
        let intensity = try scalar(effect, .intensity)
        let rays = try apply("CISunbeamsGenerator", values: [
            "inputCenter": try center(effect, in: input.extent),
            "inputColor": CIColor(red: 1, green: 0.84, blue: 0.56, alpha: min(1, intensity)),
            "inputSunRadius": try scalar(effect, .radius) * 0.24,
            "inputMaxStriationRadius": try scalar(effect, .radius),
            "inputStriationStrength": 0.55,
            "inputStriationContrast": 1.25,
            "inputTime": 0
        ]).cropped(to: input.extent)
        return try screen(try scaleRGB(rays, amount: intensity), over: input)
    }

    // MARK: Mattes

    private func lumaKey(_ effect: ProjectEffect, input: CIImage) throws -> CIImage {
        let mask = try lumaMask(input, threshold: try scalar(effect, .threshold), softness: try scalar(effect, .softness))
        return try maskedSource(input, mask: mask)
    }

    private func matte(_ effect: ProjectEffect, input: CIImage, invert: Bool) throws -> CIImage {
        var mask = try lumaMask(input, threshold: try scalar(effect, .threshold), softness: try scalar(effect, .softness), invert: invert)
        mask = try apply("CIColorControls", input: mask, values: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.35])
        return mask
    }
}
