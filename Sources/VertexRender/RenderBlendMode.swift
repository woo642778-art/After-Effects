import Foundation
import VertexCore

public struct RenderRGBAColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let transparent = RenderRGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let black = RenderRGBAColor(red: 0, green: 0, blue: 0, alpha: 1)

    public func validated() throws -> Self {
        guard [red, green, blue, alpha].allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw RenderError.invalidRequest("Render RGBA values must be finite and within 0...1.")
        }
        return self
    }
}

public enum RenderBlendMode: String, Codable, CaseIterable, Sendable {
    case normal
    case add
    case multiply
    case screen
}

public struct RenderTransform2D: Codable, Equatable, Sendable {
    public var positionX: Double
    public var positionY: Double
    public var anchorX: Double
    public var anchorY: Double
    public var scaleX: Double
    public var scaleY: Double
    public var rotationDegrees: Double

    public init(
        positionX: Double,
        positionY: Double,
        anchorX: Double,
        anchorY: Double,
        scaleX: Double,
        scaleY: Double,
        rotationDegrees: Double
    ) {
        self.positionX = positionX
        self.positionY = positionY
        self.anchorX = anchorX
        self.anchorY = anchorY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotationDegrees = rotationDegrees
    }

    public static let identity = RenderTransform2D(
        positionX: 0.5,
        positionY: 0.5,
        anchorX: 0.5,
        anchorY: 0.5,
        scaleX: 1,
        scaleY: 1,
        rotationDegrees: 0
    )

    public func validated() throws -> Self {
        let values = [positionX, positionY, anchorX, anchorY, scaleX, scaleY, rotationDegrees]
        guard values.allSatisfy(\.isFinite), scaleX > 0, scaleY > 0 else {
            throw RenderError.invalidRequest("2D transform values must be finite and scales positive.")
        }
        return self
    }
}

public struct RenderCacheContext: Codable, Equatable, Sendable {
    public var compositionID: VertexID
    public var projectRevision: UInt64
    public var compilerVersion: Int

    public init(compositionID: VertexID, projectRevision: UInt64, compilerVersion: Int) {
        self.compositionID = compositionID
        self.projectRevision = projectRevision
        self.compilerVersion = compilerVersion
    }
}
