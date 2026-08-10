import CoreGraphics
import Foundation
import UIKit
import VertexProject

@MainActor
enum GeneratedGraphicRenderer {
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
            case .rectangle, .ellipse, .star:
                renderVector(document, in: context.cgContext)
            }
        }
        guard let data = image.pngData() else {
            throw ProjectError.invalidOperation("Generated graphic could not be encoded as PNG.")
        }
        return data
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

        if abs(spec.pathArcDegrees) > 0.001, spec.text.count > 1 {
            renderTextOnArc(spec.text, font: font, attributes: attributes, arcDegrees: spec.pathArcDegrees, canvas: CGSize(width: document.canvasWidth, height: document.canvasHeight), context: context)
            return
        }

        let textRect = CGRect(x: document.canvasWidth / 20, y: document.canvasHeight / 10, width: document.canvasWidth * 9 / 10, height: document.canvasHeight * 4 / 5)
        (spec.text as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }

    private static func renderTextOnArc(
        _ text: String,
        font: UIFont,
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
        let canvas = CGRect(x: 0, y: 0, width: document.canvasWidth, height: document.canvasHeight)
        let baseRect = canvas.insetBy(dx: canvas.width * 0.18, dy: canvas.height * 0.18)
        for index in 0..<spec.repeaterCount {
            context.saveGState()
            let i = CGFloat(index)
            context.translateBy(x: i * spec.repeaterOffsetX, y: i * spec.repeaterOffsetY)
            context.translateBy(x: canvas.midX, y: canvas.midY)
            context.rotate(by: CGFloat(spec.repeaterRotationDegrees * Double(index) * .pi / 180))
            context.translateBy(x: -canvas.midX, y: -canvas.midY)
            let path = vectorPath(kind: document.kind, rect: baseRect, spec: spec)
            draw(path: path, fill: document.fill, stroke: document.stroke, trimStart: spec.trimStart, trimEnd: spec.trimEnd, context: context, canvas: canvas)
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
        case .text:
            return UIBezierPath()
        }
    }

    private static func draw(
        path: UIBezierPath,
        fill: ProjectGraphicFill,
        stroke: ProjectGraphicStroke,
        trimStart: Double,
        trimEnd: Double,
        context: CGContext,
        canvas: CGRect
    ) {
        context.saveGState()
        context.addPath(path.cgPath)
        switch fill {
        case .solid(let color):
            context.setFillColor(cgColor(for: color))
            context.fillPath()
        case .linearGradient(let start, let end, let angleDegrees):
            context.saveGState()
            context.addPath(path.cgPath)
            context.clip()
            let colors = [cgColor(for: start), cgColor(for: end)] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
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
            context.restoreGState()
        }
        context.restoreGState()

        guard stroke.width > 0, trimEnd > trimStart else { return }
        context.saveGState()
        context.addPath(path.cgPath)
        context.setStrokeColor(cgColor(for: stroke.color))
        context.setLineWidth(stroke.width)
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
        CGColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    private static func uiColor(for color: ProjectRGBAColor) -> UIColor {
        UIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
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
