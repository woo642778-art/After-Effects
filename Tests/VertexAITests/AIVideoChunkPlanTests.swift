import Testing
@testable import VertexAI

@Test("Video chunks cover every frame exactly once")
func chunkCoverage() throws {
    let chunks = try AIVideoChunkPlan.make(frameCount: 305, framesPerChunk: 120)
    #expect(chunks.count == 3)
    #expect(chunks[0].startFrame == 0)
    #expect(chunks[0].endFrameExclusive == 120)
    #expect(chunks[1].startFrame == 120)
    #expect(chunks[1].endFrameExclusive == 240)
    #expect(chunks[2].startFrame == 240)
    #expect(chunks[2].endFrameExclusive == 305)
    #expect(chunks.reduce(0) { $0 + Int($1.endFrameExclusive - $1.startFrame) } == 305)
}

@Test("Short clips still produce one resumable chunk")
func shortClipChunk() throws {
    let chunks = try AIVideoChunkPlan.make(frameCount: 1, framesPerChunk: 120)
    #expect(chunks.count == 1)
    #expect(chunks[0].index == 0)
    #expect(chunks[0].startFrame == 0)
    #expect(chunks[0].endFrameExclusive == 1)
}

@Test("Invalid frame or chunk counts fail closed")
func invalidChunkPlanRejected() {
    #expect(throws: AIError.self) { _ = try AIVideoChunkPlan.make(frameCount: 0, framesPerChunk: 120) }
    #expect(throws: AIError.self) { _ = try AIVideoChunkPlan.make(frameCount: 10, framesPerChunk: 0) }
}
