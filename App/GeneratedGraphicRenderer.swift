import CoreGraphics
import Foundation
import ImageIO
import UIKit
import VertexProject

@MainActor
enum GeneratedGraphicRenderer {
    private static let metadataKey = "com.vertex2.graphic.document.v1"

    static func pngData(for document: ProjectGraphicDocument) throws -> Data {
        let document = try document.validated()
        let size = CGSize(width: document.canvasWidth, height: document.canvasHeight)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            context.cgContext.clear(CGRect(origin: .zero, size: size))
            switch document.kind {
            case .text:
                renderText(document, in: context.cgContext)
            case .rectangle, .ellipse, .star, .bezier:
                renderVector(document, in: context.cgContext)
            }
        }
        guard let cgImage = image.cgImage else {
            throw ProjectError.invalidOperation("Generated graphic has no CGImage payload.")
        }
        return try encodePNG(cgImage: cgImage, document: document)
    }

    static func editableDocument(from pngData: Data) throws -> ProjectGraphicDocument? {
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let png = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any],
              let description = png[kCGImagePropertyPNGDescription] as? String,
              description.hasPrefix(metadataKey + ":") else {
            return nil
        }
        let encoded = String(description.dropFirst(metadataKey.count + 1))
        guard let data = Data(base64Encoded: encoded) else {
            throw ProjectError.invalidValue("Embedded Vertex graphic metadata is malformed.")
        }
        return try JSONDecoder().decode(ProjectGraphicDocument.self, from: data).validated()
    }

    private static func encodePNG(cgImage: CGImage, document: ProjectGraphicDocument) throws -> Data {
        let json = try JSONEncoder().encode(document)
        let description = metadataKey + ":" + json.base64EncodedString()
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else {
            throw ProjectError.invalidOperation("Generated graphic PNG destination could not be created.")
        }
        let properties: [CFString: Any] = [
            kCGImagePropertyPNGDictionary: [
                kCGImagePropertyPNGDescription: description
            ]
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ProjectError.invalidOperation("Generated graphic PNG metadata could not be finalized.")
        }
        return output as Data
    }

    private static func renderText(_ document: ProjectGraphicDocument, in context: CGContext) {
        guard let spec = document.text else { return }
        let font: UIFont = {
            if let postScriptName = spec.fontPostScriptName,
               let custom = UIFont(name: postScriptName, size: spec.fontSize) {
                return custom
            }
            return UIFont.systemFont(ofSize: spec.fontSize, weight: .regular)
        }()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = switch spec.alignment {
        case "left": .left
        case "right": .right
        default: .center
        }
        paragraph.lineSpacing = spec.lineSpacing
        let foreground = uiColor(for: document.fill.primaryColor)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: foreground,
            .kern: spec.tracking,
            .paragraphStyle: paragraph,
            .strokeColor: uiColor(for: document.stroke.color),
            .strokeWidth: document.stroke.width > 0 ? -(document.stroke.width / max(1, spec.fontSize) * 100) : 0
        ]

        if !spec.animators.isEmpty {
            renderAnimatedCharacters(spec, attributes: attributes, canvas: CGSize(width: document.canvasWidth, height: document.canvasHeight), context: context)
            return
        }
        if abs(spec.pathArcDegrees) > 0.001, spec.text.count > 1 {
            renderTextOnArc(spec.text, attributes: attributes, arcDegrees: spec.pathArcDegrees, canvas: CGSize(width: document.canvasWidth, height: document.canvasHeight), context: context)
            return
        }

        let textRect = CGRect(
            x: CGFloat(document.canvasWidth) / 20,
            y: CGFloat(document.canvasHeight) / 10,
            width: CGFloat(document.canvasWidth) * 9 / 10,
            height: CGFloat(document.canvasHeight) * 4 / 5
        )
        (spec.text as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }

    private static func renderAnimatedCharacters(
        _ spec: ProjectTextGraphic,
        attributes: [NSAttributedString.Key: Any],
        canvas: CGSize,
        context: CGContext
    ) {
        let graphemes = spec.text.map(String.init)
        let sizes = graphemes.map { ($0 as NSString).size(withAttributes: attributes) }
        let totalWidth = sizes.reduce(0) { $0 + $1.width } + CGFloat(max(0, graphemes.count - 1)) * CGFloat(spec.tracking)
        var cursor = (canvas.width - totalWidth) / 2
        let baselineY = canvas.height / 2
        for (index, grapheme) in graphemes.enumerated() {
            let size = sizes[index]
            var opacity = 1.0
            var dx = 0.0
            var dy = 0.0
            var scale = 1.0
            var rotation = 0.0
            var extraTracking = 0.0
            for animator in spec.animators {
                let weight = animator.selector.weight(forCharacter: index, characterCount: graphemes.count)
                opacity *= 1 + (animator.opacity - 1) * weight
                dx += animator.positionX * weight
                dy += animator.positionY * weight
                scale *= 1 + (animator.scale - 1) * weight
                rotation += animator.rotationDegrees * weight
                extraTracking += animator.tracking * weight
            }
            context.saveGState()
            context.setAlpha(CGFloat(min(max(opacity, 0), 1)))
            let centerX = cursor + size.width / 2 + CGFloat(dx)
            context.translateBy(x: centerX, y: baselineY + CGFloat(dy))
            context.rotate(by: CGFloat(rotation * .pi / 180))
            context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
            (grapheme as NSString).draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attributes)
            context.restoreGState()
            cursor += size.width + CGFloat(spec.tracking + extraTracking)
        }
    }

    private static func renderTextOnArc(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        arcDegrees: Double,
        canvas: CGSize,
        context: CGContext
    ) {
        let graphemes = text.map(String.init)
        guard !graphemes.isEmpty else { return }
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let radius = min(canvas.width, canvas.height) * 0.34
        let arc = CGFloat(arcDegrees * .pi / 180)
        let start = -CGFloat.pi / 2 - arc / 2
        for (index, grapheme) in graphemes.enumerated() {
            let fraction = graphemes.count == 1 ? 0.5 : CGFloat(index) / CGFloat(graphemes.count - 1)
            let angle = start + arc * fraction
            let glyph = grapheme as NSString
            let glyphSize = glyph.size(withAttributes: attributes)
            context.saveGState()
            context.translateBy(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            context.rotate(by: angle + CGFloat.pi / 2)
            glyph.draw(at: CGPoint(x: -glyphSize.width / 2, y: -glyphSize.height / 2), withAttributes: attributes)
            context.restoreGState()
        }
    }

    private static func renderVector(_ document: ProjectGraphicDocument, in context: CGContext) {
        guard let spec = document.vector else { return }
        let canvas = CGRect(x: 0, y: 0, width: CGFloat(document.canvasWidth), height: CGFloat(document.canvasHeight))
        let baseRect = canvas.insetBy(dx: canvas.width * 0.18, dy: canvas.height * 0.18)
        for index in 0..<spec.repeaterCount {
            context.saveGState()
            let i = CGFloat(index)
            context.translateBy(x: i * CGFloat(spec.repeaterOffsetX), y: i * CGFloat(spec.repeaterOffsetY))
            context.translateBy(x: canvas.midX, y: canvas.midY)
            context.rotate(by: CGFloat(spec.repeaterRotationDegrees * Double(index) * .pi / 180))
            context.translateBy(x: -canvas.midX, y: -canvas.midY)
            if document.kind == .bezier {
                let paths = (try? spec.resolvedBezierPaths())?.map { uiBezierPath(from: $0, canvas: canvas) } ?? []
                drawBezierSet(paths, operation: spec.booleanOperation, fill: document.fill, stroke: document.stroke, trimStart: spec.trimStart, trimEnd: spec.trimEnd, context: context, canvas: canvas)
            } else {
                let path = vectorPath(kind: document.kind, rect: baseRect, spec: spec)
                draw(path: path, fill: document.fill, stroke: document.stroke, trimStart: spec.trimStart, trimEnd: spec.trimEnd, context: context, canvas: canvas)
            }
            context.restoreGState()
        }
    }

    private static func vectorPath(kind: ProjectGraphicKind, rect: CGRect, spec: ProjectVectorGraphic) -> UIBezierPath {
        switch kind {
        case .rectangle:
            return UIBezierPath(roundedRect: rect, cornerRadius: min(CGFloat(spec.cornerRadius), min(rect.width, rect.height) / 2))
        case .ellipse:
            return UIBezierPath(ovalIn: rect)
        case .star:
            let path = UIBezierPath()
            let points = max(3, spec.starPoints)
            let outer = min(rect.width, rect.height) / 2
            let inner = outer * CGFloat(spec.innerRadius)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            for index in 0..<(points * 2) {
                let radius = index.isMultiple(of: 2) ? outer : inner
                let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / CGFloat(points)
                let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.close()
            return path
        case .text, .bezier:
            return UIBezierPath()
        }
    }

    private static func uiBezierPath(from path: ProjectBezierPath, canvas: CGRect) -> UIBezierPath {
        let output = UIBezierPath()
        guard let first = path.vertices.first else { return output }
        func point(_ vector: ProjectVector2) -> CGPoint {
            CGPoint(x: canvas.minX + CGFloat(vector.x) * canvas.width, y: canvas.minY + CGFloat(vector.y) * canvas.height)
        }
        output.move(to: point(first.anchor))
        var previous = first
        for vertex in path.vertices.dropFirst() {
            let previousAnchor = point(previous.anchor)
            let nextAnchor = point(vertex.anchor)
            let control1 = CGPoint(
                x: previousAnchor.x + CGFloat(previous.outgoingTangent.x) * canvas.width,
                y: previousAnchor.y + CGFloat(previous.outgoingTangent.y) * canvas.height
            )
            let control2 = CGPoint(
                x: nextAnchor.x + CGFloat(vertex.incomingTangent.x) * canvas.width,
                y: nextAnchor.y + CGFloat(vertex.incomingTangent.y) * canvas.height
            )
            output.addCurve(to: nextAnchor, controlPoint1: control1, controlPoint2: control2)
            previous = vertex
        }
        if path.closed {
            let previousAnchor = point(previous.anchor)
            let firstAnchor = point(first.anchor)
            output.addCurve(
                to: firstAnchor,
                controlPoint1: CGPoint(
                    x: previousAnchor.x + CGFloat(previous.outgoingTangent.x) * canvas.width,
                    y: previousAnchor.y + CGFloat(previous.outgoingTangent.y) * canvas.height
                ),
                controlPoint2: CGPoint(
                    x: firstAnchor.x + CGFloat(first.incomingTangent.x) * canvas.width,
                    y: firstAnchor.y + CGFloat(first.incomingTangent.y) * canvas.height
                )
            )
            output.close()
        }
        return output
    }

    private static func drawBezierSet(
        _ paths: [UIBezierPath],
        operation: ProjectShapeBooleanOperation,
        fill: ProjectGraphicFill,
        stroke: ProjectGraphicStroke,
        trimStart: Double,
        trimEnd: Double,
        context: CGContext,
        canvas: CGRect
    ) {
        guard let first = paths.first else { return }
        switch operation {
        case .union:
            let combined = UIBezierPath()
            paths.forEach { combined.append($0) }
            draw(path: combined, fill: fill, stroke: stroke, trimStart: trimStart, trimEnd: trimEnd, context: context, canvas: canvas)
        case .xor:
            let combined = UIBezierPath()
            combined.usesEvenOddFillRule = true
            paths.forEach { combined.append($0) }
            draw(path: combined, fill: fill, stroke: stroke, trimStart: trimStart, trimEnd: trimEnd, context: context, canvas: canvas, evenOdd: true)
        case .subtract:
            draw(path: first, fill: fill, stroke: stroke, trimStart: trimStart, trimEnd: trimEnd, context: context, canvas: canvas)
            for path in paths.dropFirst() {
                context.saveGState()
                context.setBlendMode(.clear)
                context.addPath(path.cgPath)
                context.fillPath()
                context.restoreGState()
            }
        case .intersect:
            context.saveGState()
            for path in paths {
                context.addPath(path.cgPath)
                context.clip()
            }
            fillCanvas(fill, context: context, canvas: canvas)
            context.restoreGState()
            if stroke.width > 0 {
                for path in paths {
                    strokePath(path, stroke: stroke, trimStart: trimStart, trimEnd: trimEnd, context: context, canvas: canvas)
                }
            }
        }
    }

    private static func draw(
        path: UIBezierPath,
        fill: ProjectGraphicFill,
        stroke: ProjectGraphicStroke,
        trimStart: Double,
        trimEnd: Double,
        context: CGContext,
        canvas: CGRect,
        evenOdd: Bool = false
    ) {
        context.saveGState()
        context.addPath(path.cgPath)
        context.clip(using: evenOdd ? .evenOdd : .winding)
        fillCanvas(fill, context: context, canvas: canvas)
        context.restoreGState()
        if stroke.width > 0, trimEnd > trimStart {
            strokePath(path, stroke: stroke, trimStart: trimStart, trimEnd: trimEnd, context: context, canvas: canvas)
        }
    }

    private static func fillCanvas(_ fill: ProjectGraphicFill, context: CGContext, canvas: CGRect) {
        switch fill {
        case .solid(let color):
            context.setFillColor(cgColor(for: color))
            context.fill(canvas)
        case .linearGradient(let start, let end, let angleDegrees):
            let colors = [cgColor(for: start), cgColor(for: end)] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            let angle = CGFloat(angleDegrees * .pi / 180)
            let vector = CGVector(dx: cos(angle) * canvas.width / 2, dy: sin(angle) * canvas.height / 2)
            let center = CGPoint(x: canvas.midX, y: canvas.midY)
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: center.x - vector.dx, y: center.y - vector.dy),
                end: CGPoint(x: center.x + vector.dx, y: center.y + vector.dy),
                options: []
            )
        }
    }

    private static func strokePath(
        _ path: UIBezierPath,
        stroke: ProjectGraphicStroke,
        trimStart: Double,
        trimEnd: Double,
        context: CGContext,
        canvas: CGRect
    ) {
        context.saveGState()
        context.addPath(path.cgPath)
        context.setStrokeColor(cgColor(for: stroke.color))
        context.setLineWidth(CGFloat(stroke.width))
        context.setLineCap(.round)
        if trimStart > 0 || trimEnd < 1 {
            let approximateLength = max(1, (canvas.width + canvas.height) * 2)
            let visible = approximateLength * CGFloat(trimEnd - trimStart)
            let hidden = approximateLength - visible
            context.setLineDash(phase: approximateLength * CGFloat(trimStart), lengths: [visible, hidden])
        }
        context.strokePath()
        context.restoreGState()
    }

    private static func cgColor(for color: ProjectRGBAColor) -> CGColor {
        CGColor(red: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: CGFloat(color.alpha))
    }

    private static func uiColor(for color: ProjectRGBAColor) -> UIColor {
        UIColor(red: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: CGFloat(color.alpha))
    }
}

private extension ProjectGraphicFill {
    var primaryColor: ProjectRGBAColor {
        switch self {
        case .solid(let color): color
        case .linearGradient(let start, _, _): start
        }
    }
}
