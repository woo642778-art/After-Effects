import AVFoundation
import Foundation
import Testing
import VertexCore
import VertexExport
@testable import VertexExportAVFoundation

@Test("H264 writer produces a reopenable exact-duration movie")
func writesH264Movie() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let output = root.appendingPathComponent("fixture.mov")
    let frameRate = RationalTime(value: 30, timescale: 1)
    let job = ExportJob(
        format: .mov,
        codec: .h264,
        quality: .compact,
        width: 64,
        height: 64,
        frameRate: frameRate,
        outputURL: output,
        includeAudio: false
    )
    let rgba = Data((0..<(64 * 64)).flatMap { _ in [UInt8(220), 20, 40, 255] })
    let writer = AppleExportWriter()
    let url = try await writer.export(job: job, frameCount: 10) { _ in
        try ExportRGBAFrame(width: 64, height: 64, rgba8: rgba)
    }
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect((try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0 > 0)

    let asset = AVURLAsset(url: url)
    let tracks = try await asset.loadTracks(withMediaType: .video)
    #expect(tracks.count == 1)
    let duration = try await asset.load(.duration)
    #expect(abs(duration.seconds - (10.0 / 30.0)) < (1.0 / 30.0))
    let size = try await tracks[0].load(.naturalSize)
    #expect(abs(size.width) == 64)
    #expect(abs(size.height) == 64)
}

@Test("Cancellation never publishes the requested final file")
func cancellationIsTransactional() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let output = root.appendingPathComponent("cancel.mov")
    let job = ExportJob(format: .mov, codec: .h264, quality: .compact, width: 32, height: 32, frameRate: RationalTime(value: 30, timescale: 1), outputURL: output, includeAudio: false)
    let cancellation = ExportCancellationToken()
    let writer = AppleExportWriter()
    do {
        _ = try await writer.export(job: job, frameCount: 8, frameProvider: { index in
            if index == 3 { await cancellation.cancel() }
            return try ExportRGBAFrame(width: 32, height: 32, rgba8: Data(repeating: 127, count: 32 * 32 * 4))
        }, cancellation: cancellation)
        Issue.record("Expected cancellation")
    } catch is CancellationError {}
    #expect(!FileManager.default.fileExists(atPath: output.path))
}
