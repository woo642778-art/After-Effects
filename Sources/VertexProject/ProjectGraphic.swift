import Foundation
import VertexCore

public enum ProjectGraphicKind: String, Codable, CaseIterable, Sendable {
    case text
    case rectangle
    case ellipse
    case star
    case bezier
}

public enum ProjectGraphicFill: Codable, Equatable, Sendable {
    case solid(ProjectRGBAColor)
    case linearGradient(start: ProjectRGBAColor, end: ProjectRGBAColor, angleDegrees: Double)

    public func validated() throws -> Self {
        switch self {
        case .solid(let color):
            _ = try color.validated()
        case .linearGradient(let start, let end, let angleDegrees):
            _ = try start.validated()
            _ = try end.validated()
            guard angleDegrees.isFinite else {
                throw ProjectError.invalidValue("Graphic gradient angle must be finite.")
            }
        }
        return self
    }
}

public struct ProjectGraphicStroke: Codable, Equatable, Sendable {
    public var color: ProjectRGBAColor
    public var width: Double

    public init(color: ProjectRGBAColor = .black, width: Double = 0) {
        self.color = color
        self.width = width
    }

    public func validated() throws -> Self {
        _ = try color.validated()
        guard width.isFinite, (0...256).contains(width) else {
            throw ProjectError.invalidValue("Graphic stroke width must be between 0 and 256 points.")
        }
        return self
    }
}

public struct ProjectTextRangeSelector: Codable, Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var offset: Double
    public var amount: Double

    public init(start: Double = 0, end: Double = 1, offset: Double = 0, amount: Double = 1) {
        self.start = start
        self.end = end
        self.offset = offset
        self.amount = amount
    }

    public func validated() throws -> Self {
        guard start.isFinite, end.isFinite, offset.isFinite, amount.isFinite,
              (0...1).contains(start), (0...1).contains(end), start <= end,
              (-1...1).contains(offset), (-1...1).contains(amount) else {
            throw ProjectError.invalidValue("Text selector values are outside supported normalized ranges.")
        }
        return self
    }

    public func weight(forCharacter index: Int, characterCount: Int) -> Double {
        guard characterCount > 0 else { return 0 }
        let denominator = Double(max(1, characterCount - 1))
        var position = Double(index) / denominator + offset
        position.formTruncatingRemainder(dividingBy: 1)
        if position < 0 { position += 1 }
        return position >= start && position <= end ? amount : 0
    }
}

public struct ProjectTextAnimator: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var selector: ProjectTextRangeSelector
    public var opacity: Double
    public var positionX: Double
    public var positionY: Double
    public var scale: Double
    public var rotationDegrees: Double
    public var tracking: Double

    public init(
        id: VertexID = VertexID(),
        selector: ProjectTextRangeSelector = .init(),
        opacity: Double = 1,
        positionX: Double = 0,
        positionY: Double = 0,
        scale: Double = 1,
        rotationDegrees: Double = 0,
        tracking: Double = 0
    ) {
        self.id = id
        self.selector = selector
        self.opacity = opacity
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.tracking = tracking
    }

    public func validated() throws -> Self {
        _ = try selector.validated()
        let values = [opacity, positionX, positionY, scale, rotationDegrees, tracking]
        guard values.allSatisfy(\.isFinite), (0...1).contains(opacity), scale > 0 else {
            throw ProjectError.invalidValue("Text animator values must be finite with positive scale and normalized opacity.")
        }
        return self
    }
}

public struct ProjectTextGraphic: Codable, Equatable, Sendable {
    public var text: String
    public var fontPostScriptName: String?
    public var fontSize: Double
    public var tracking: Double
    public var lineSpacing: Double
    public var alignment: String
    public var pathArcDegrees: Double
    public var animators: [ProjectTextAnimator]

    public init(
        text: String,
        fontPostScriptName: String? = nil,
        fontSize: Double = 120,
        tracking: Double = 0,
        lineSpacing: Double = 0,
        alignment: String = "center",
        pathArcDegrees: Double = 0,
        animators: [ProjectTextAnimator] = []
    ) {
        self.text = text
        self.fontPostScriptName = fontPostScriptName
        self.fontSize = fontSize
        self.tracking = tracking
        self.lineSpacing = lineSpacing
        self.alignment = alignment
        self.pathArcDegrees = pathArcDegrees
        self.animators = animators
    }

    public func validated() throws -> Self {
        guard !text.isEmpty, text.utf8.count <= 16_384 else {
            throw ProjectError.invalidValue("Text graphics require 1...16384 UTF-8 bytes.")
        }
        guard fontSize.isFinite, (1...2048).contains(fontSize),
              tracking.isFinite, (-1000...1000).contains(tracking),
              lineSpacing.isFinite, (-500...2000).contains(lineSpacing),
              pathArcDegrees.isFinite, (-360...360).contains(pathArcDegrees) else {
            throw ProjectError.invalidValue("Text graphic typography values are outside supported ranges.")
        }
        guard ["left", "center", "right"].contains(alignment) else {
            throw ProjectError.invalidValue("Text graphic alignment must be left, center, or right.")
        }
        guard Set(animators.map(\.id)).count == animators.count else {
            throw ProjectError.duplicateIdentity("text animator")
        }
        for animator in animators { _ = try animator.validated() }
        return self
    }
}

public enum ProjectShapeBooleanOperation: String, Codable, CaseIterable, Sendable {
    case union
    case subtract
    case intersect
    case xor
}

public struct ProjectVectorGraphic: Codable, Equatable, Sendable {
    public var cornerRadius: Double
    public var starPoints: Int
    public var innerRadius: Double
    public var trimStart: Double
    public var trimEnd: Double
    public var repeaterCount: Int
    public var repeaterRotationDegrees: Double
    public var repeaterOffsetX: Double
    public var repeaterOffsetY: Double
    public var bezierPaths: [ProjectBezierPath]
    public var booleanOperation: ProjectShapeBooleanOperation
    public var morphTargets: [ProjectBezierPath]
    public var morphProgress: Double

    public init(
        cornerRadius: Double = 0,
        starPoints: Int = 5,
        innerRadius: Double = 0.45,
        trimStart: Double = 0,
        trimEnd: Double = 1,
        repeaterCount: Int = 1,
        repeaterRotationDegrees: Double = 0,
        repeaterOffsetX: Double = 0,
        repeaterOffsetY: Double = 0,
        bezierPaths: [ProjectBezierPath] = [],
        booleanOperation: ProjectShapeBooleanOperation = .union,
        morphTargets: [ProjectBezierPath] = [],
        morphProgress: Double = 0
    ) {
        self.cornerRadius = cornerRadius
        self.starPoints = starPoints
        self.innerRadius = innerRadius
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.repeaterCount = repeaterCount
        self.repeaterRotationDegrees = repeaterRotationDegrees
        self.repeaterOffsetX = repeaterOffsetX
        self.repeaterOffsetY = repeaterOffsetY
        self.bezierPaths = bezierPaths
        self.booleanOperation = booleanOperation
        self.morphTargets = morphTargets
        self.morphProgress = morphProgress
    }

    public func validated() throws -> Self {
        let finite = [cornerRadius, innerRadius, trimStart, trimEnd, repeaterRotationDegrees, repeaterOffsetX, repeaterOffsetY, morphProgress]
        guard finite.allSatisfy(\.isFinite), cornerRadius >= 0,
              (3...64).contains(starPoints), (0.01...0.99).contains(innerRadius),
              (0...1).contains(trimStart), (0...1).contains(trimEnd), trimStart <= trimEnd,
              (1...128).contains(repeaterCount), (0...1).contains(morphProgress) else {
            throw ProjectError.invalidValue("Vector graphic parameters are outside supported ranges.")
        }
        guard bezierPaths.count <= 32, morphTargets.count <= 32 else {
            throw ProjectError.invalidValue("A vector graphic supports at most 32 source and morph paths.")
        }
        for path in bezierPaths { _ = try path.validated(maximumVertices: 256) }
        for path in morphTargets { _ = try path.validated(maximumVertices: 256) }
        if !morphTargets.isEmpty {
            guard morphTargets.count == bezierPaths.count else {
                throw ProjectError.invalidValue("Bezier morphing requires one target for each source path.")
            }
            for (source, target) in zip(bezierPaths, morphTargets) {
                guard source.closed == target.closed, source.vertices.count == target.vertices.count else {
                    throw ProjectError.invalidValue("Bezier morphing requires matching source/target topology.")
                }
            }
        }
        return self
    }

    public func resolvedBezierPaths() throws -> [ProjectBezierPath] {
        _ = try validated()
        guard !morphTargets.isEmpty else { return bezierPaths }
        return try zip(bezierPaths, morphTargets).map { source, target in
            let vertices = zip(source.vertices, target.vertices).map { lhs, rhs in
                ProjectBezierVertex(
                    anchor: ProjectVector2(
                        x: lhs.anchor.x + (rhs.anchor.x - lhs.anchor.x) * morphProgress,
                        y: lhs.anchor.y + (rhs.anchor.y - lhs.anchor.y) * morphProgress
                    ),
                    incomingTangent: ProjectVector2(
                        x: lhs.incomingTangent.x + (rhs.incomingTangent.x - lhs.incomingTangent.x) * morphProgress,
                        y: lhs.incomingTangent.y + (rhs.incomingTangent.y - lhs.incomingTangent.y) * morphProgress
                    ),
                    outgoingTangent: ProjectVector2(
                        x: lhs.outgoingTangent.x + (rhs.outgoingTangent.x - lhs.outgoingTangent.x) * morphProgress,
                        y: lhs.outgoingTangent.y + (rhs.outgoingTangent.y - lhs.outgoingTangent.y) * morphProgress
                    )
                )
            }
            return ProjectBezierPath(vertices: vertices, closed: source.closed)
        }
    }
}

public struct ProjectGraphicDocument: Codable, Equatable, Sendable {
    public var kind: ProjectGraphicKind
    public var canvasWidth: Int
    public var canvasHeight: Int
    public var fill: ProjectGraphicFill
    public var stroke: ProjectGraphicStroke
    public var text: ProjectTextGraphic?
    public var vector: ProjectVectorGraphic?

    public init(
        kind: ProjectGraphicKind,
        canvasWidth: Int,
        canvasHeight: Int,
        fill: ProjectGraphicFill,
        stroke: ProjectGraphicStroke = .init(),
        text: ProjectTextGraphic? = nil,
        vector: ProjectVectorGraphic? = nil
    ) {
        self.kind = kind
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.fill = fill
        self.stroke = stroke
        self.text = text
        self.vector = vector
    }

    public func validated() throws -> Self {
        guard (1...16_384).contains(canvasWidth), (1...16_384).contains(canvasHeight) else {
            throw ProjectError.invalidValue("Graphic canvas dimensions must be between 1 and 16384 pixels.")
        }
        _ = try fill.validated()
        _ = try stroke.validated()
        switch kind {
        case .text:
            guard let text else { throw ProjectError.invalidValue("Text graphic payload is missing.") }
            _ = try text.validated()
        case .rectangle, .ellipse, .star:
            guard let vector else { throw ProjectError.invalidValue("Vector graphic payload is missing.") }
            _ = try vector.validated()
        case .bezier:
            guard let vector, !vector.bezierPaths.isEmpty else {
                throw ProjectError.invalidValue("Bezier graphics require at least one path.")
            }
            _ = try vector.validated()
        }
        return self
    }
}
