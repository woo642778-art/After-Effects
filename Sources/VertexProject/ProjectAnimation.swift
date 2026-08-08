import Foundation
import VertexCore

public enum ProjectLayerAnimatableProperty: String, Codable, CaseIterable, Sendable {
    case positionX
    case positionY
    case anchorX
    case anchorY
    case scaleX
    case scaleY
    case rotationDegrees
    case opacity
}

public enum ProjectMaskAnimatableProperty: String, Codable, CaseIterable, Sendable {
    case opacity
    case feather
    case expansion
    case path
}

public enum ProjectAnimatableValueKind: String, Codable, Sendable {
    case scalar
    case vector2
    case color
    case boolean
    case bezierPath
}

public enum ProjectPropertyAddress: Codable, Equatable, Sendable {
    case layer(ProjectLayerAnimatableProperty)
    case mask(maskID: VertexID, property: ProjectMaskAnimatableProperty)
    case effect(effectID: VertexID, parameterID: String, valueKind: ProjectAnimatableValueKind)

    public var expectedValueKind: ProjectAnimatableValueKind {
        switch self {
        case .layer:
            return .scalar
        case .mask(_, let property):
            return property == .path ? .bezierPath : .scalar
        case .effect(_, _, let valueKind):
            return valueKind
        }
    }

    public var stableSortKey: String {
        switch self {
        case .layer(let property):
            return "layer.\(property.rawValue)"
        case .mask(let maskID, let property):
            return "mask.\(maskID.rawValue).\(property.rawValue)"
        case .effect(let effectID, let parameterID, let valueKind):
            return "effect.\(effectID.rawValue).\(parameterID).\(valueKind.rawValue)"
        }
    }
}

public struct ProjectVector2: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func validated() throws -> Self {
        guard x.isFinite, y.isFinite else {
            throw ProjectError.invalidValue("Vector animation values must be finite.")
        }
        return self
    }

    fileprivate func interpolated(to other: Self, progress: Double) -> Self {
        Self(
            x: x + (other.x - x) * progress,
            y: y + (other.y - y) * progress
        )
    }
}

public struct ProjectBezierVertex: Codable, Equatable, Sendable {
    public var anchor: ProjectVector2
    public var incomingTangent: ProjectVector2
    public var outgoingTangent: ProjectVector2

    public init(
        anchor: ProjectVector2,
        incomingTangent: ProjectVector2 = ProjectVector2(x: 0, y: 0),
        outgoingTangent: ProjectVector2 = ProjectVector2(x: 0, y: 0)
    ) {
        self.anchor = anchor
        self.incomingTangent = incomingTangent
        self.outgoingTangent = outgoingTangent
    }

    public func validated() throws -> Self {
        _ = try anchor.validated()
        _ = try incomingTangent.validated()
        _ = try outgoingTangent.validated()
        return self
    }

    fileprivate func interpolated(to other: Self, progress: Double) -> Self {
        Self(
            anchor: anchor.interpolated(to: other.anchor, progress: progress),
            incomingTangent: incomingTangent.interpolated(to: other.incomingTangent, progress: progress),
            outgoingTangent: outgoingTangent.interpolated(to: other.outgoingTangent, progress: progress)
        )
    }
}

public struct ProjectBezierPath: Codable, Equatable, Sendable {
    public var vertices: [ProjectBezierVertex]
    public var closed: Bool

    public init(vertices: [ProjectBezierVertex], closed: Bool) {
        self.vertices = vertices
        self.closed = closed
    }

    public static func rectangle(x: Double, y: Double, width: Double, height: Double) -> Self {
        Self(
            vertices: [
                .init(anchor: .init(x: x, y: y)),
                .init(anchor: .init(x: x + width, y: y)),
                .init(anchor: .init(x: x + width, y: y + height)),
                .init(anchor: .init(x: x, y: y + height))
            ],
            closed: true
        )
    }

    public static func ellipse(centerX: Double, centerY: Double, radiusX: Double, radiusY: Double) -> Self {
        // Cubic approximation of a quarter circle. Tangents are stored as offsets.
        let kappa = 0.552_284_749_830_793_6
        return Self(
            vertices: [
                .init(
                    anchor: .init(x: centerX, y: centerY - radiusY),
                    incomingTangent: .init(x: -kappa * radiusX, y: 0),
                    outgoingTangent: .init(x: kappa * radiusX, y: 0)
                ),
                .init(
                    anchor: .init(x: centerX + radiusX, y: centerY),
                    incomingTangent: .init(x: 0, y: -kappa * radiusY),
                    outgoingTangent: .init(x: 0, y: kappa * radiusY)
                ),
                .init(
                    anchor: .init(x: centerX, y: centerY + radiusY),
                    incomingTangent: .init(x: kappa * radiusX, y: 0),
                    outgoingTangent: .init(x: -kappa * radiusX, y: 0)
                ),
                .init(
                    anchor: .init(x: centerX - radiusX, y: centerY),
                    incomingTangent: .init(x: 0, y: kappa * radiusY),
                    outgoingTangent: .init(x: 0, y: -kappa * radiusY)
                )
            ],
            closed: true
        )
    }

    public func validated(maximumVertices: Int = 64) throws -> Self {
        let minimum = closed ? 3 : 2
        guard vertices.count >= minimum, vertices.count <= maximumVertices else {
            throw ProjectError.invalidValue("Bezier paths must contain \(minimum)...\(maximumVertices) vertices.")
        }
        for vertex in vertices {
            _ = try vertex.validated()
        }
        return self
    }

    fileprivate func interpolated(to other: Self, progress: Double) throws -> Self {
        guard closed == other.closed, vertices.count == other.vertices.count else {
            throw ProjectError.invalidValue("Animated Bezier paths require matching topology.")
        }
        return Self(
            vertices: zip(vertices, other.vertices).map { lhs, rhs in
                lhs.interpolated(to: rhs, progress: progress)
            },
            closed: closed
        )
    }
}

public enum ProjectAnimatableValue: Codable, Equatable, Sendable {
    case scalar(Double)
    case vector2(ProjectVector2)
    case color(ProjectRGBAColor)
    case boolean(Bool)
    case bezierPath(ProjectBezierPath)

    public var kind: ProjectAnimatableValueKind {
        switch self {
        case .scalar: .scalar
        case .vector2: .vector2
        case .color: .color
        case .boolean: .boolean
        case .bezierPath: .bezierPath
        }
    }

    public func validated() throws -> Self {
        switch self {
        case .scalar(let value):
            guard value.isFinite else {
                throw ProjectError.invalidValue("Scalar animation values must be finite.")
            }
        case .vector2(let value):
            _ = try value.validated()
        case .color(let value):
            _ = try value.validated()
        case .boolean:
            break
        case .bezierPath(let path):
            _ = try path.validated()
        }
        return self
    }

    fileprivate func interpolated(to other: Self, progress: Double) throws -> Self {
        guard kind == other.kind else {
            throw ProjectError.invalidValue("Animation value types must match inside a channel.")
        }
        let p = min(max(progress, 0), 1)
        switch (self, other) {
        case (.scalar(let lhs), .scalar(let rhs)):
            return .scalar(lhs + (rhs - lhs) * p)
        case (.vector2(let lhs), .vector2(let rhs)):
            return .vector2(lhs.interpolated(to: rhs, progress: p))
        case (.color(let lhs), .color(let rhs)):
            return .color(ProjectRGBAColor(
                red: lhs.red + (rhs.red - lhs.red) * p,
                green: lhs.green + (rhs.green - lhs.green) * p,
                blue: lhs.blue + (rhs.blue - lhs.blue) * p,
                alpha: lhs.alpha + (rhs.alpha - lhs.alpha) * p
            ))
        case (.boolean(let lhs), .boolean):
            return .boolean(lhs)
        case (.bezierPath(let lhs), .bezierPath(let rhs)):
            return .bezierPath(try lhs.interpolated(to: rhs, progress: p))
        default:
            throw ProjectError.invalidValue("Unsupported animation interpolation pair.")
        }
    }
}

public enum ProjectKeyframeInterpolation: String, Codable, CaseIterable, Sendable {
    case hold
    case linear
    case cubicBezier
}

public struct ProjectBezierHandle: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func validated() throws -> Self {
        guard x.isFinite, y.isFinite, (0...1).contains(x) else {
            throw ProjectError.invalidValue("Temporal Bezier handle X must be within 0...1 and all handle values must be finite.")
        }
        return self
    }
}

public struct ProjectKeyframe: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var time: RationalTime
    public var value: ProjectAnimatableValue
    public var interpolation: ProjectKeyframeInterpolation
    public var incomingTemporalHandle: ProjectBezierHandle?
    public var outgoingTemporalHandle: ProjectBezierHandle?

    public init(
        id: VertexID = VertexID(),
        time: RationalTime,
        value: ProjectAnimatableValue,
        interpolation: ProjectKeyframeInterpolation,
        incomingTemporalHandle: ProjectBezierHandle? = nil,
        outgoingTemporalHandle: ProjectBezierHandle? = nil
    ) {
        self.id = id
        self.time = time
        self.value = value
        self.interpolation = interpolation
        self.incomingTemporalHandle = incomingTemporalHandle
        self.outgoingTemporalHandle = outgoingTemporalHandle
    }

    public func validated(expectedKind: ProjectAnimatableValueKind) throws -> Self {
        guard time >= .zero else {
            throw ProjectError.invalidValue("Keyframe time must be nonnegative.")
        }
        guard value.kind == expectedKind else {
            throw ProjectError.invalidValue("Keyframe value type does not match its property address.")
        }
        _ = try value.validated()
        if let incomingTemporalHandle { _ = try incomingTemporalHandle.validated() }
        if let outgoingTemporalHandle { _ = try outgoingTemporalHandle.validated() }
        if case .boolean = value, interpolation != .hold {
            throw ProjectError.invalidValue("Boolean animation supports Hold interpolation only.")
        }
        return self
    }
}

public struct ProjectAnimationChannel: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var property: ProjectPropertyAddress
    public var keyframes: [ProjectKeyframe]

    public init(id: VertexID = VertexID(), property: ProjectPropertyAddress, keyframes: [ProjectKeyframe]) {
        self.id = id
        self.property = property
        self.keyframes = keyframes
    }

    public func validated() throws -> Self {
        guard !keyframes.isEmpty else {
            throw ProjectError.invalidValue("Animation channels must contain at least one keyframe.")
        }
        guard Set(keyframes.map(\.id)).count == keyframes.count else {
            throw ProjectError.duplicateIdentity("keyframe")
        }
        for keyframe in keyframes {
            _ = try keyframe.validated(expectedKind: property.expectedValueKind)
        }
        for pair in zip(keyframes, keyframes.dropFirst()) {
            guard pair.0.time < pair.1.time else {
                throw ProjectError.invalidValue("Animation keyframe times must be strictly increasing.")
            }
            if property.expectedValueKind == .bezierPath,
               case .bezierPath(let lhs) = pair.0.value,
               case .bezierPath(let rhs) = pair.1.value {
                guard lhs.closed == rhs.closed, lhs.vertices.count == rhs.vertices.count else {
                    throw ProjectError.invalidValue("Animated Bezier paths require matching topology.")
                }
            }
        }
        return self
    }

    public func evaluatedValue(at time: RationalTime) throws -> ProjectAnimatableValue {
        _ = try validated()
        guard let first = keyframes.first, let last = keyframes.last else {
            throw ProjectError.invalidOperation("Animation channel has no keyframes.")
        }
        if time <= first.time { return first.value }
        if time >= last.time { return last.value }

        var low = 0
        var high = keyframes.count - 1
        while low + 1 < high {
            let middle = (low + high) / 2
            if keyframes[middle].time <= time {
                low = middle
            } else {
                high = middle
            }
        }

        let left = keyframes[low]
        let right = keyframes[high]
        if time == left.time { return left.value }
        if time == right.time { return right.value }
        if left.interpolation == .hold { return left.value }

        let elapsed = try time.subtracting(left.time).seconds
        let duration = try right.time.subtracting(left.time).seconds
        guard duration.isFinite, duration > 0, elapsed.isFinite else {
            throw ProjectError.invalidValue("Animation segment duration is invalid.")
        }
        let linearProgress = min(max(elapsed / duration, 0), 1)
        let progress: Double
        switch left.interpolation {
        case .hold:
            progress = 0
        case .linear:
            progress = linearProgress
        case .cubicBezier:
            progress = Self.temporalBezierProgress(
                linearProgress,
                outgoing: left.outgoingTemporalHandle ?? ProjectBezierHandle(x: 1.0 / 3.0, y: 1.0 / 3.0),
                incoming: right.incomingTemporalHandle ?? ProjectBezierHandle(x: 2.0 / 3.0, y: 2.0 / 3.0)
            )
        }
        return try left.value.interpolated(to: right.value, progress: progress)
    }

    private static func temporalBezierProgress(
        _ x: Double,
        outgoing: ProjectBezierHandle,
        incoming: ProjectBezierHandle
    ) -> Double {
        let target = min(max(x, 0), 1)
        var t = target
        for _ in 0..<8 {
            let currentX = cubic(t, p1: outgoing.x, p2: incoming.x)
            let derivative = cubicDerivative(t, p1: outgoing.x, p2: incoming.x)
            if abs(currentX - target) < 1e-7 { break }
            if abs(derivative) < 1e-8 { break }
            let next = t - (currentX - target) / derivative
            if !(0...1).contains(next) { break }
            t = next
        }
        if abs(cubic(t, p1: outgoing.x, p2: incoming.x) - target) > 1e-5 {
            var lower = 0.0
            var upper = 1.0
            for _ in 0..<20 {
                t = (lower + upper) * 0.5
                if cubic(t, p1: outgoing.x, p2: incoming.x) < target {
                    lower = t
                } else {
                    upper = t
                }
            }
        }
        return min(max(cubic(t, p1: outgoing.y, p2: incoming.y), 0), 1)
    }

    private static func cubic(_ t: Double, p1: Double, p2: Double) -> Double {
        let oneMinus = 1 - t
        return 3 * oneMinus * oneMinus * t * p1
            + 3 * oneMinus * t * t * p2
            + t * t * t
    }

    private static func cubicDerivative(_ t: Double, p1: Double, p2: Double) -> Double {
        let oneMinus = 1 - t
        return 3 * oneMinus * oneMinus * p1
            + 6 * oneMinus * t * (p2 - p1)
            + 3 * t * t * (1 - p2)
    }
}

public extension Array where Element == ProjectAnimationChannel {
    func validatedAnimationChannels(for masks: [ProjectMask] = [], effects: [ProjectEffect] = []) throws -> [ProjectAnimationChannel] {
        guard Set(map(\.id)).count == count else {
            throw ProjectError.duplicateIdentity("animation channel")
        }
        let propertyKeys = map { $0.property.stableSortKey }
        guard Set(propertyKeys).count == propertyKeys.count else {
            throw ProjectError.invalidValue("A property may have only one active animation channel.")
        }
        let maskIDs = Set(masks.map(\.id))
        for channel in self {
            _ = try channel.validated()
            if case .mask(let maskID, _) = channel.property, !maskIDs.contains(maskID) {
                throw ProjectError.invalidValue("Mask animation channel references a missing mask.")
            }
            if case .effect(let effectID, let parameterID, let valueKind) = channel.property {
                guard let effect = effects.first(where: { $0.id == effectID }),
                      let parameter = effect.parameter(id: parameterID),
                      let animatableKind = parameter.value.animatableKind,
                      animatableKind == valueKind else {
                    throw ProjectError.invalidValue("Effect animation channel references a missing or non-animatable parameter.")
                }
            }
        }
        return self
    }

    func channel(for property: ProjectPropertyAddress) -> ProjectAnimationChannel? {
        first { $0.property == property }
    }
}
