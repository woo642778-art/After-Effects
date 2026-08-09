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

@Test("Phase 11 export resolution presets include UHD and DCI 8K")
func phase11EightKPresets() {
    #expect(ExportResolutionPreset.uhd8K.dimensions == ExportDimensions(width: 7680, height: 4320))
    #expect(ExportResolutionPreset.dci8K.dimensions == ExportDimensions(width: 8192, height: 4320))
    #expect(ExportResolutionPreset.uhd4K.dimensions == ExportDimensions(width: 3840, height: 2160))
}

@Test("Phase 11 export accepts arbitrary custom dimensions through the 8K render envelope")
func phase11CustomResolutionValidation() throws {
    let job = ExportJob(
        format: .mov,
        codec: .hevc,
        quality: .master,
        width: 7312,
        height: 4096,
        frameRate: RationalTime(value: 60_000, timescale: 1_001),
        outputURL: URL(fileURLWithPath: "/tmp/custom-8k.mov")
    )
    _ = try job.validated()
}

@Test("Phase 11 8K bitrate scales above the old 160 Mbps ceiling")
func phase11EightKBitrate() {
    let bitrate = ExportQualityPreset.master.targetBitRate(width: 7680, height: 4320, fps: 60)
    #expect(bitrate > 160_000_000)
}

@Test("Phase 11 export frame count follows the output frame rate exactly")
func phase11ExactOutputFrameCount() throws {
    let job = ExportJob(
        format: .mov,
        codec: .hevc,
        width: 3840,
        height: 2160,
        frameRate: RationalTime(value: 60_000, timescale: 1_001),
        outputURL: URL(fileURLWithPath: "/tmp/fps-override.mov")
    )
    #expect(try job.frameCount(for: RationalTime(value: 10, timescale: 1)) == 600)
    #expect(try job.frameCount(for: RationalTime(value: 1, timescale: 2)) == 30)
}

@Test("Phase 11 export output settings resolve presets and exact frame-rate overrides")
func phase11OutputSettingsResolution() throws {
    let fixed = ExportOutputSettings(
        resolution: .uhd8K,
        customDimensions: ExportDimensions(width: 1111, height: 777),
        frameRate: .fps5994,
        customFrameRate: nil
    )
    let fixedResolved = try fixed.resolved(
        compositionDimensions: ExportDimensions(width: 1920, height: 1080),
        compositionFrameRate: RationalTime(value: 24, timescale: 1)
    )
    #expect(fixedResolved.dimensions == ExportDimensions(width: 7680, height: 4320))
    #expect(fixedResolved.frameRate == RationalTime(value: 60_000, timescale: 1_001))

    let custom = ExportOutputSettings(
        resolution: .custom,
        customDimensions: ExportDimensions(width: 7312, height: 4096),
        frameRate: .custom,
        customFrameRate: RationalTime(value: 120, timescale: 1)
    )
    let customResolved = try custom.resolved(
        compositionDimensions: ExportDimensions(width: 1920, height: 1080),
        compositionFrameRate: RationalTime(value: 30, timescale: 1)
    )
    #expect(customResolved.dimensions == ExportDimensions(width: 7312, height: 4096))
    #expect(customResolved.frameRate == RationalTime(value: 120, timescale: 1))
}
