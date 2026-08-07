import Foundation
import VertexCore
import VertexProject

public enum EffectAnimationEvaluator {
    public static func evaluate(
        effect: ProjectEffect,
        channels: [ProjectAnimationChannel],
        at time: RationalTime
    ) throws -> ProjectEffect {
        _ = try effect.validated()
        var result = effect
        for channel in channels {
            guard case .effect(let effectID, let parameterID, let valueKind) = channel.property,
                  effectID == effect.id else { continue }
            guard let index = result.parameters.firstIndex(where: { $0.id == parameterID }),
                  let parameterKind = result.parameters[index].value.animatableKind,
                  parameterKind == valueKind else {
                throw ProjectError.invalidValue("Effect animation references a missing or incompatible parameter.")
            }
            let value = try channel.evaluatedValue(at: time)
            switch (valueKind, value) {
            case (.scalar, .scalar(let scalar)):
                result.parameters[index].value = .scalar(scalar)
            case (.boolean, .boolean(let boolean)):
                result.parameters[index].value = .boolean(boolean)
            default:
                throw ProjectError.invalidValue("Effect animation value type does not match its parameter.")
            }
        }
        return try result.validated()
    }
}
