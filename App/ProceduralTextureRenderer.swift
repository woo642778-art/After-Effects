import CoreGraphics
import CoreImage
import Foundation
import VertexComposition
import VertexCore
import VertexProject

struct ProceduralTextureRenderer {
    static let proceduralTypes: Set<ProjectEffectType> = [
        .checkerboard, .stripes, .starShine,
        .vertexFractalNoise, .vertexTurbulenceTexture, .vertexPlasma,
        .vertexCellularTexture, .vertexGrid, .vertexRings
    ]

    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    func filteredImage(effect: ProjectEffect, input: CIImage, time: RationalTime) throws -> CIImage? {
        guard Self.proceduralTypes.contains(effect.type) else { return nil }
        let extent = input.extent
        switch effect.type {
        case .checkerboard:
            let cell = try scalar(effect, V17EffectParameterID.scale)
            let opacity = try scalar(effect, V17EffectParameterID.intensity)
            let generated = try filter("CICheckerboardGenerator", values: [
                "inputCenter": CIVector(x: extent.midX, y: extent.midY),
                "inputColor0": CIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: opacity),
                "inputColor1": CIColor(red: 0.78, green: 0.80, blue: 0.86, alpha: opacity),
                "inputWidth": cell,
                "inputSharpness": 1.0
            ]).cropped(to: extent)
            return generated.composited(over: input)
        case .stripes:
            let width = try scalar(effect, V17EffectParameterID.width)
            let angle = try scalar(effect, V17EffectParameterID.angle) * .pi / 180
            let opacity = try scalar(effect, V17EffectParameterID.intensity)
            var generated = try filter("CIStripesGenerator", values: [
                "inputCenter": CIVector(x: extent.midX, y: extent.midY),
                "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: opacity),
                "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0),
                "inputWidth": width,
                "inputSharpness": 0.92
            ])
            generated = generated.transformed(by: CGAffineTransform(translationX: extent.midX, y: extent.midY).rotated(by: angle).translatedBy(x: -extent.midX, y: -extent.midY)).cropped(to: extent)
            return generated.composited(over: input)
        case .starShine:
            let radius = try scalar(effect, V17EffectParameterID.radius)
            let intensity = try scalar(effect, V17EffectParameterID.intensity)
            let c = try center(effect, extent)
            let generated = try filter("CIStarShineGenerator", values: [
                "inputCenter": CIVector(x: c.x, y: c.y),
                "inputColor": CIColor(red: 1, green: 0.86, blue: 0.55, alpha: min(intensity, 1)),
                "inputRadius": radius,
                "inputCrossScale": 18.0,
                "inputCrossAngle": 0.25,
                "inputCrossOpacity": min(1.0, intensity),
                "inputCrossWidth": 2.0,
                "inputEpsilon": -2.0
            ]).cropped(to: extent)
            return try addition(foreground: generated, background: input)
        case .vertexFractalNoise:
            let seed = try integer(effect, V17EffectParameterID.seed)
            let scale = try scalar(effect, V17EffectParameterID.scale)
            let evolution = try scalar(effect, V17EffectParameterID.evolution) + time.seconds * 0.18
            let contrast = try scalar(effect, V17EffectParameterID.contrast)
            let n0 = deterministicNoise(seed: seed, phase: evolution, cellSize: scale, extent: extent)
            let n1 = deterministicNoise(seed: seed ^ 0x5A17, phase: evolution * 1.37, cellSize: scale * 0.5, extent: extent)
            let n2 = deterministicNoise(seed: seed ^ 0x3C91, phase: evolution * 1.91, cellSize: scale * 0.25, extent: extent)
            let layered = try addition(foreground: n2.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0.22, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0.22, z: 0, w: 0), "inputBVector": CIVector(x: 0, y: 0, z: 0.22, w: 0)]), background: try addition(foreground: n1.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0.38, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0.38, z: 0, w: 0), "inputBVector": CIVector(x: 0, y: 0, z: 0.38, w: 0)]), background: n0))
            let adjusted = layered.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: contrast, kCIInputSaturationKey: 0.0]).cropped(to: extent)
            return adjusted.composited(over: input)
        case .vertexTurbulenceTexture:
            let seed = try integer(effect, V17EffectParameterID.seed)
            let scale = try scalar(effect, V17EffectParameterID.scale)
            let evolution = try scalar(effect, V17EffectParameterID.evolution) + time.seconds * 0.32
            let intensity = try scalar(effect, V17EffectParameterID.intensity)
            var noise = deterministicNoise(seed: seed, phase: evolution, cellSize: scale, extent: extent)
            noise = noise.applyingFilter("CITwirlDistortion", parameters: [
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
                kCIInputRadiusKey: max(extent.width, extent.height) * 0.7,
                kCIInputAngleKey: evolution * 0.35
            ]).cropped(to: extent)
            noise = noise.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.8, kCIInputSaturationKey: 0.15])
            return mix(input, noise, amount: min(max(intensity, 0), 1))
        case .vertexPlasma:
            let scale = try scalar(effect, V17EffectParameterID.scale)
            let evolution = try scalar(effect, V17EffectParameterID.evolution) + time.seconds * 0.45
            let opacity = try scalar(effect, V17EffectParameterID.intensity)
            let plasma = try plasma(extent: extent, scale: scale, evolution: evolution).cropped(to: extent)
            return mix(input, plasma, amount: opacity)
        case .vertexCellularTexture:
            let seed = try integer(effect, V17EffectParameterID.seed)
            let scale = try scalar(effect, V17EffectParameterID.scale)
            let contrast = try scalar(effect, V17EffectParameterID.contrast)
            let cellular = deterministicCellular(seed: seed, cellSize: scale, extent: extent)
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: contrast, kCIInputSaturationKey: 0.2])
                .cropped(to: extent)
            return cellular.composited(over: input)
        case .vertexGrid:
            let spacing = try scalar(effect, V17EffectParameterID.spacing)
            let lineWidth = try scalar(effect, V17EffectParameterID.width)
            let angle = try scalar(effect, V17EffectParameterID.angle) * .pi / 180
            let opacity = try scalar(effect, V17EffectParameterID.intensity)
            let grid = try grid(extent: extent, spacing: spacing, lineWidth: lineWidth, angle: angle, opacity: opacity)
            return grid.composited(over: input)
        case .vertexRings:
            let spacing = try scalar(effect, V17EffectParameterID.spacing)
            let lineWidth = try scalar(effect, V17EffectParameterID.width)
            let opacity = try scalar(effect, V17EffectParameterID.intensity)
            let c = try center(effect, extent)
            let rings = radialPattern(extent: extent, center: c, spacing: spacing, lineWidth: lineWidth, opacity: opacity)
            return rings.composited(over: input)
        default:
            return nil
        }
    }

    private func deterministicNoise(seed: Int, phase: Double, cellSize: Double, extent: CGRect) -> CIImage {
        let side = 96
        let phaseX = Int(floor(phase * 13))
        let phaseY = Int(floor(phase * 9))
        var bytes = [UInt8](repeating: 255, count: side * side * 4)
        for y in 0..<side {
            for x in 0..<side {
                let value = hashByte(x + phaseX, y + phaseY, seed)
                let i = (y * side + x) * 4
                bytes[i] = value; bytes[i + 1] = value; bytes[i + 2] = value; bytes[i + 3] = 255
            }
        }
        let base = CIImage(bitmapData: Data(bytes), bytesPerRow: side * 4, size: CGSize(width: side, height: side), format: .RGBA8, colorSpace: Self.colorSpace)
        let pixelScale = max(cellSize / Double(side), 0.02)
        let scaled = base.transformed(by: CGAffineTransform(scaleX: pixelScale, y: pixelScale))
        let tiled = scaled.applyingFilter("CIAffineTile").transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
        return tiled.cropped(to: extent)
    }

    private func deterministicCellular(seed: Int, cellSize: Double, extent: CGRect) -> CIImage {
        let side = 128
        let cells = max(3, min(22, Int(512 / max(cellSize, 8))))
        var points: [(Double, Double)] = []
        for i in 0..<(cells * cells) {
            let gx = i % cells
            let gy = i / cells
            let jx = Double(hashByte(gx, gy, seed)) / 255.0
            let jy = Double(hashByte(gy, gx, seed ^ 0x51A7)) / 255.0
            points.append(((Double(gx) + jx) / Double(cells), (Double(gy) + jy) / Double(cells)))
        }
        var bytes = [UInt8](repeating: 255, count: side * side * 4)
        for y in 0..<side {
            for x in 0..<side {
                let px = Double(x) / Double(side)
                let py = Double(y) / Double(side)
                var nearest = 2.0
                for p in points {
                    nearest = min(nearest, hypot(px - p.0, py - p.1))
                }
                let value = UInt8(min(255, max(0, Int(nearest * Double(cells) * 180))))
                let i = (y * side + x) * 4
                bytes[i] = value; bytes[i + 1] = UInt8(min(255, Int(value) + 20)); bytes[i + 2] = UInt8(max(0, Int(value) - 10)); bytes[i + 3] = 190
            }
        }
        let base = CIImage(bitmapData: Data(bytes), bytesPerRow: side * 4, size: CGSize(width: side, height: side), format: .RGBA8, colorSpace: Self.colorSpace)
        let sx = extent.width / CGFloat(side)
        let sy = extent.height / CGFloat(side)
        return base.transformed(by: CGAffineTransform(scaleX: sx, y: sy).translatedBy(x: extent.minX, y: extent.minY)).cropped(to: extent)
    }

    private func radialPattern(extent: CGRect, center: CGPoint, spacing: Double, lineWidth: Double, opacity: Double) -> CIImage {
        let width = max(1, Int(extent.width.rounded()))
        let height = max(1, Int(extent.height.rounded()))
        let renderW = min(width, 512)
        let renderH = min(height, 288)
        let sx = Double(renderW) / Double(width)
        let sy = Double(renderH) / Double(height)
        let cx = (Double(center.x - extent.minX)) * sx
        let cy = (Double(center.y - extent.minY)) * sy
        let scaledSpacing = max(1, spacing * min(sx, sy))
        let scaledWidth = max(0.5, lineWidth * min(sx, sy))
        var bytes = [UInt8](repeating: 0, count: renderW * renderH * 4)
        for y in 0..<renderH {
            for x in 0..<renderW {
                let distance = hypot(Double(x) - cx, Double(y) - cy)
                let phase = distance.truncatingRemainder(dividingBy: scaledSpacing)
                let edge = min(phase, scaledSpacing - phase)
                let a = UInt8(min(255, max(0, Int((1 - min(edge / scaledWidth, 1)) * opacity * 255))))
                let i = (y * renderW + x) * 4
                bytes[i] = 170; bytes[i + 1] = 205; bytes[i + 2] = 255; bytes[i + 3] = a
            }
        }
        let image = CIImage(bitmapData: Data(bytes), bytesPerRow: renderW * 4, size: CGSize(width: renderW, height: renderH), format: .RGBA8, colorSpace: Self.colorSpace)
        return image.transformed(by: CGAffineTransform(scaleX: CGFloat(width) / CGFloat(renderW), y: CGFloat(height) / CGFloat(renderH)).translatedBy(x: extent.minX, y: extent.minY)).cropped(to: extent)
    }

    private func plasma(extent: CGRect, scale: Double, evolution: Double) throws -> CIImage {
        let radius = max(extent.width, extent.height) / max(scale, 0.2)
        let colors: [CIColor] = [
            CIColor(red: 0.18, green: 0.35, blue: 1.0, alpha: 0.8),
            CIColor(red: 1.0, green: 0.20, blue: 0.56, alpha: 0.75),
            CIColor(red: 0.22, green: 1.0, blue: 0.72, alpha: 0.68)
        ]
        var result = CIImage(color: .clear).cropped(to: extent)
        for i in 0..<3 {
            let t = evolution * (0.55 + Double(i) * 0.13) + Double(i) * 2.1
            let center = CIVector(
                x: extent.midX + cos(t) * extent.width * 0.28,
                y: extent.midY + sin(t * 1.27) * extent.height * 0.30
            )
            let gradient = try filter("CIRadialGradient", values: [
                "inputCenter": center,
                "inputRadius0": 0.0,
                "inputRadius1": radius,
                "inputColor0": colors[i],
                "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0)
            ]).cropped(to: extent)
            result = try addition(foreground: gradient, background: result)
        }
        return result.applyingFilter("CIHueAdjust", parameters: [kCIInputAngleKey: evolution * 0.12]).cropped(to: extent)
    }

    private func grid(extent: CGRect, spacing: Double, lineWidth: Double, angle: Double, opacity: Double) throws -> CIImage {
        let sharpness = min(1.0, max(0.02, 1.0 - lineWidth / max(spacing, 1)))
        let baseValues: [String: Any] = [
            "inputCenter": CIVector(x: extent.midX, y: extent.midY),
            "inputColor0": CIColor(red: 0.45, green: 0.72, blue: 1.0, alpha: opacity),
            "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0),
            "inputWidth": spacing,
            "inputSharpness": sharpness
        ]
        let vertical = try filter("CIStripesGenerator", values: baseValues)
        let horizontal = vertical.transformed(by: CGAffineTransform(translationX: extent.midX, y: extent.midY).rotated(by: .pi / 2).translatedBy(x: -extent.midX, y: -extent.midY))
        var combined = try addition(foreground: vertical, background: horizontal)
        combined = combined.transformed(by: CGAffineTransform(translationX: extent.midX, y: extent.midY).rotated(by: angle).translatedBy(x: -extent.midX, y: -extent.midY))
        return combined.cropped(to: extent)
    }

    private func filter(_ name: String, input: CIImage? = nil, values: [String: Any] = [:]) throws -> CIImage {
        guard let filter = CIFilter(name: name) else { throw CompositionError.graphCompilationFailed("Core Image filter is unavailable: \(name).") }
        if let input { filter.setValue(input, forKey: kCIInputImageKey) }
        for (key, value) in values { filter.setValue(value, forKey: key) }
        guard let output = filter.outputImage else { throw CompositionError.graphCompilationFailed("Core Image filter produced no output: \(name).") }
        return output
    }

    private func addition(foreground: CIImage, background: CIImage) throws -> CIImage {
        try filter("CIAdditionCompositing", input: foreground, values: [kCIInputBackgroundImageKey: background])
    }

    private func mix(_ a: CIImage, _ b: CIImage, amount: Double) -> CIImage {
        let alpha = min(max(amount, 0), 1)
        let matrix = b.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)])
        return matrix.composited(over: a).cropped(to: a.extent)
    }

    private func center(_ effect: ProjectEffect, _ extent: CGRect) throws -> CGPoint {
        CGPoint(x: extent.minX + extent.width * (try scalar(effect, V17EffectParameterID.centerX)), y: extent.minY + extent.height * (try scalar(effect, V17EffectParameterID.centerY)))
    }

    private func scalar(_ effect: ProjectEffect, _ id: String) throws -> Double {
        guard case .scalar(let value)? = effect.parameter(id: id)?.value else { throw CompositionError.graphCompilationFailed("Procedural parameter is missing or invalid: \(id).") }
        return value
    }

    private func integer(_ effect: ProjectEffect, _ id: String) throws -> Int {
        guard case .integer(let value)? = effect.parameter(id: id)?.value else { throw CompositionError.graphCompilationFailed("Procedural integer parameter is missing or invalid: \(id).") }
        return value
    }

    private func hashByte(_ x: Int, _ y: Int, _ seed: Int) -> UInt8 {
        var v = UInt64(bitPattern: Int64(x &* 73_856_093 ^ y &* 19_349_663 ^ seed &* 83_492_791))
        v ^= v >> 33; v &*= 0xff51afd7ed558ccd; v ^= v >> 33; v &*= 0xc4ceb9fe1a85ec53; v ^= v >> 33
        return UInt8(truncatingIfNeeded: v >> 24)
    }
}
