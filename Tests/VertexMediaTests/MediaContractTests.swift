import Foundation
import Testing
@testable import VertexMedia
import VertexCore

@Test("Video frame requests reject non-positive target sizes")
func invalidFrameSize() {
    #expect(throws: MediaError.self) {
        _ = try VideoFrameRequest(
            time: RationalTime(value: 1, timescale: 24),
            targetSize: VertexSize(width: 0, height: 720),
            tolerance: .exact
        )
    }
}

@Test("Waveform values are normalized and paired")
func waveformValidation() throws {
    let waveform = try AudioWaveform(peaks: [0, 1], rms: [0.25, 0.5])
    #expect(waveform.bucketCount == 2)
    #expect(throws: MediaError.self) {
        _ = try AudioWaveform(peaks: [1.2], rms: [0.2])
    }
    #expect(throws: MediaError.self) {
        _ = try AudioWaveform(peaks: [0.2], rms: [])
    }
}

@Test("Cancellation token throws after cancellation")
func cancellation() async throws {
    let token = MediaCancellationToken()
    try await token.throwIfCancelled()
    await token.cancel()
    await #expect(throws: MediaError.self) {
        try await token.throwIfCancelled()
    }
}

@Test("Waveform accumulator handles stereo full-scale and silence")
func accumulator() throws {
    var accumulator = try WaveformAccumulator(totalFrames: 4, channelCount: 2, bucketCount: 2)
    try accumulator.append(interleavedSamples: [1, -1, 0, 0, 0.5, -0.5, 0, 0])
    let waveform = try accumulator.finalize()

    #expect(waveform.peaks == [1, 0.5])
    #expect(abs(waveform.rms[0] - 0.70710677) < 0.0001)
    #expect(abs(waveform.rms[1] - 0.35355338) < 0.0001)
}

private struct FakeInspector: MediaAssetInspecting {
    let descriptor: MediaAssetDescriptor

    func inspect(url: URL, cancellationToken: MediaCancellationToken) async throws -> MediaAssetDescriptor {
        try await cancellationToken.throwIfCancelled()
        return descriptor
    }
}

@Test("Portable inspector protocols support deterministic fake providers")
func fakeProvider() async throws {
    let descriptor = try MediaAssetDescriptor(
        filename: "fixture.mov",
        duration: RationalTime(value: 240, timescale: 24),
        containerHint: "mov",
        videoStreams: [
            VideoStreamDescriptor(
                streamIndex: 0,
                pixelSize: VertexSize(width: 1920, height: 1080),
                nominalFrameRate: 24,
                variableFrameRateStatus: .constant,
                codec: "h264",
                color: nil,
                isHDR: false,
                hasAlpha: false,
                rotationDegrees: 0
            )
        ],
        audioStreams: []
    ).validated()
    let inspector = FakeInspector(descriptor: descriptor)
    let result = try await inspector.inspect(
        url: URL(fileURLWithPath: "/tmp/fixture.mov"),
        cancellationToken: MediaCancellationToken()
    )

    #expect(result.filename == "fixture.mov")
    #expect(result.videoStreams.first?.pixelSize == VertexSize(width: 1920, height: 1080))
}
