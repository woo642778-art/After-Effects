import Foundation

public enum AIVideoChunkPlan {
    public static func make(frameCount: Int64, framesPerChunk: Int) throws -> [AIJobChunk] {
        guard frameCount > 0 else {
            throw AIError.invalidJobState("Video AI processing requires at least one decoded frame.")
        }
        guard framesPerChunk > 0 else {
            throw AIError.invalidJobState("AI video chunk size must be positive.")
        }
        var result: [AIJobChunk] = []
        var start: Int64 = 0
        var index = 0
        while start < frameCount {
            let end = min(frameCount, start + Int64(framesPerChunk))
            result.append(try AIJobChunk(
                index: index,
                startFrame: start,
                endFrameExclusive: end
            ))
            start = end
            index += 1
        }
        return result
    }
}
