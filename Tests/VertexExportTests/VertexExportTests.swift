import Foundation
import Testing
import VertexCore
@testable import VertexExport

@Test("Export validation enforces container codec rules")
func codecValidation() throws {
    let base = URL(fileURLWithPath: "/tmp/out.mp4")
    let good = ExportJob(format: .mp4, codec: .hevc, width: 1920, height: 1080, frameRate: RationalTime(value: 60, timescale: 1), outputURL: base)
    _ = try good.validated()
    let bad = ExportJob(format: .mp4, codec: .proRes422, width: 1920, height: 1080, frameRate: RationalTime(value: 60, timescale: 1), outputURL: base)
    #expect(throws: ExportValidationError.codecNotAllowed(.proRes422, .mp4)) { try bad.validated() }
}

@Test("Alpha contract requires MOV ProRes 4444")
func alphaValidation() throws {
    let rate = RationalTime(value: 30, timescale: 1)
    let good = ExportJob(format: .mov, codec: .proRes4444, width: 1080, height: 1080, frameRate: rate, outputURL: URL(fileURLWithPath: "/tmp/a.mov"), includeAlpha: true)
    _ = try good.validated()
    let bad = ExportJob(format: .mov, codec: .hevc, width: 1080, height: 1080, frameRate: rate, outputURL: URL(fileURLWithPath: "/tmp/a.mov"), includeAlpha: true)
    #expect(throws: ExportValidationError.alphaRequiresProRes4444) { try bad.validated() }
}

@Test("Export exact frame time uses rational composition timing")
func exactFrameTiming() throws {
    let job = ExportJob(format: .mov, codec: .h264, width: 1920, height: 1080, frameRate: RationalTime(value: 24_000, timescale: 1_001), outputURL: URL(fileURLWithPath: "/tmp/a.mov"))
    let time = try job.exactPresentationTime(frameIndex: 24)
    #expect(time == RationalTime(value: 24_024, timescale: 24_000))
}

@Test("Quality bitrate mapping is deterministic and monotonic")
func bitrateMapping() {
    let values = ExportQualityPreset.allCases.map { $0.targetBitRate(width: 1920, height: 1080, fps: 60) }
    #expect(values == values.sorted())
    #expect(values == ExportQualityPreset.allCases.map { $0.targetBitRate(width: 1920, height: 1080, fps: 60) })
}

@Test("RGBA frame validates exact byte count")
func rgbaValidation() throws {
    _ = try ExportRGBAFrame(width: 2, height: 2, rgba8: Data(repeating: 0, count: 16))
    #expect(throws: ExportValidationError.frameSizeMismatch(expected: 16, actual: 15)) {
        try ExportRGBAFrame(width: 2, height: 2, rgba8: Data(repeating: 0, count: 15))
    }
}

@Test("Export queue preserves FIFO and cancellation")
func queueFIFO() async throws {
    let queue = ExportJobQueue()
    let rate = RationalTime(value: 30, timescale: 1)
    let a = ExportJob(format: .mov, codec: .h264, width: 640, height: 360, frameRate: rate, outputURL: URL(fileURLWithPath: "/tmp/a.mov"))
    let b = ExportJob(format: .mov, codec: .h264, width: 640, height: 360, frameRate: rate, outputURL: URL(fileURLWithPath: "/tmp/b.mov"))
    try await queue.enqueue(a)
    try await queue.enqueue(b)
    #expect(await queue.nextQueued()?.id == a.id)
    await queue.cancel(a.id)
    #expect(await queue.nextQueued()?.id == b.id)
}
