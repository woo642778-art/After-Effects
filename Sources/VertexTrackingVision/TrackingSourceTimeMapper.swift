import VertexCore
import VertexProject
import VertexTimeline

public enum TrackingSourceTimeMapper {
    public static func sourceTimes(
        for layer: ProjectLayer,
        compositionTimes: [RationalTime]
    ) throws -> [RationalTime] {
        let sourceStartTime: RationalTime
        switch layer.source {
        case .media(_, let value):
            sourceStartTime = value
        default:
            throw ProjectError.invalidOperation("Vision tracking source-time mapping requires a media layer.")
        }

        return try compositionTimes.map { compositionTime in
            let layerLocalTime = try compositionTime.subtracting(layer.timing.startTime)
            let sourceTime: RationalTime
            if let mapping = layer.timing.timeRemap {
                sourceTime = try TimeRemapEvaluator().sourceTime(
                    mapping: mapping,
                    compositionTime: layerLocalTime
                )
            } else {
                sourceTime = try layerLocalTime
                    .adding(sourceStartTime)
                    .adding(layer.timing.sourceOffset)
            }
            guard sourceTime >= .zero else {
                throw ProjectError.invalidValue("Tracking resolved a negative media source time.")
            }
            return sourceTime
        }
    }
}
