import VertexCore
import VertexProject

public struct EvaluatedLayerState: Equatable, Sendable {
    public var transform: LayerTransform
    public var masks: [ProjectMask]

    public init(transform: LayerTransform, masks: [ProjectMask]) {
        self.transform = transform
        self.masks = masks
    }
}

public enum LayerAnimationEvaluator {
    public static func evaluate(
        layer: ProjectLayer,
        at time: RationalTime
    ) throws -> EvaluatedLayerState {
        var transform = layer.transform
        var masks = layer.masks
        let maskIndices = Dictionary(uniqueKeysWithValues: masks.enumerated().map { ($0.element.id, $0.offset) })

        for channel in layer.animationChannels {
            let value = try channel.evaluatedValue(at: time)
            switch (channel.property, value) {
            case (.layer(let property), .scalar(let scalar)):
                switch property {
                case .positionX: transform.positionX = scalar
                case .positionY: transform.positionY = scalar
                case .anchorX: transform.anchorX = scalar
                case .anchorY: transform.anchorY = scalar
                case .scaleX: transform.scaleX = scalar
                case .scaleY: transform.scaleY = scalar
                case .rotationDegrees: transform.rotationDegrees = scalar
                case .opacity: transform.opacity = scalar
                }

            case (.mask(let maskID, let property), .scalar(let scalar)):
                guard let index = maskIndices[maskID] else {
                    throw ProjectError.invalidValue("Mask animation references a missing mask.")
                }
                switch property {
                case .opacity: masks[index].opacity = scalar
                case .feather: masks[index].featherPixels = scalar
                case .expansion: masks[index].expansionPixels = scalar
                case .path:
                    throw ProjectError.invalidValue("Mask Path requires a Bezier-path animation value.")
                }

            case (.mask(let maskID, .path), .bezierPath(let path)):
                guard let index = maskIndices[maskID] else {
                    throw ProjectError.invalidValue("Mask Path animation references a missing mask.")
                }
                masks[index].path = path

            default:
                throw ProjectError.invalidValue("Animation channel value type does not match its property.")
            }
        }

        _ = try transform.validated()
        _ = try masks.validatedMasks()
        return EvaluatedLayerState(transform: transform, masks: masks)
    }
}
