import Foundation

public struct ProjectRGBAColor: Codable, Equatable, Sendable {
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

    public static let transparent = ProjectRGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let black = ProjectRGBAColor(red: 0, green: 0, blue: 0, alpha: 1)

    public func validated() throws -> Self {
        let components = [red, green, blue, alpha]
        guard components.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw ProjectError.invalidValue("Project RGBA components must be finite and within 0...1.")
        }
        return self
    }
}
