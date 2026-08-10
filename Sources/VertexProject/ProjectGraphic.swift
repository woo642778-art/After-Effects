import Foundation
import VertexCore

public enum ProjectGraphicKind: String, Codable, CaseIterable, Sendable {
    case text
    case rectangle
    case ellipse
    case star
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

public struct ProjectTextGraphic: Codable, Equatable, Sendable {
    public var text: String
    public var fontPostScriptName: String?
    public var fontSize: Double
    public var tracking: Double
    public var lineSpacing: Double
    public var alignment: String
    public var pathArcDegrees: Double

    public init(
        text: String,
        fontPostScriptName: String? = nil,
        fontSize: Double = 120,
        tracking: Double = 0,
        lineSpacing: Double = 0,
        alignment: String = "center",
        pathArcDegrees: Double = 0
    ) {
        self.text = text
        self.fontPostScriptName = fontPostScriptName
        self.fontSize = fontSize
        self.tracking = tracking
        self.lineSpacing = lineSpacing
        self.alignment = alignment
        self.pathArcDegrees = pathArcDegrees
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
        return self
    }
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

    public init(
        cornerRadius: Double = 0,
        starPoints: Int = 5,
        innerRadius: Double = 0.45,
        trimStart: Double = 0,
        trimEnd: Double = 1,
        repeaterCount: Int = 1,
        repeaterRotationDegrees: Double = 0,
        repeaterOffsetX: Double = 0,
        repeaterOffsetY: Double = 0
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
    }

    public func validated() throws -> Self {
        let finite = [cornerRadius, innerRadius, trimStart, trimEnd, repeaterRotationDegrees, repeaterOffsetX, repeaterOffsetY]
        guard finite.allSatisfy(\.isFinite), cornerRadius >= 0,
              (3...64).contains(starPoints), (0.01...0.99).contains(innerRadius),
              (0...1).contains(trimStart), (0...1).contains(trimEnd), trimStart <= trimEnd,
              (1...128).contains(repeaterCount) else {
            throw ProjectError.invalidValue("Vector graphic parameters are outside supported ranges.")
        }
        return self
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
        }
        return self
    }
}
