import Foundation

public struct WaveformAccumulator: Sendable {
    private let estimatedTotalFrames: Int
    private let channelCount: Int
    private let bucketCount: Int
    private var processedFrames = 0
    private var peaks: [Float]
    private var sumSquares: [Double]
    private var sampleCounts: [Int]

    public init(totalFrames: Int, channelCount: Int, bucketCount: Int) throws {
        guard totalFrames > 0, channelCount > 0, bucketCount > 0 else {
            throw MediaError.invalidRequest("Waveform dimensions must be positive.")
        }
        self.estimatedTotalFrames = totalFrames
        self.channelCount = channelCount
        self.bucketCount = bucketCount
        self.peaks = Array(repeating: 0, count: bucketCount)
        self.sumSquares = Array(repeating: 0, count: bucketCount)
        self.sampleCounts = Array(repeating: 0, count: bucketCount)
    }

    public mutating func append(interleavedSamples: [Float]) throws {
        guard interleavedSamples.count % channelCount == 0 else {
            throw MediaError.invalidRequest("Interleaved sample count must be divisible by channel count.")
        }
        let frameCount = interleavedSamples.count / channelCount

        for localFrame in 0..<frameCount {
            let globalFrame = processedFrames + localFrame
            let bucket: Int
            if globalFrame >= estimatedTotalFrames {
                bucket = bucketCount - 1
            } else {
                let position = Double(globalFrame) / Double(estimatedTotalFrames)
                bucket = min(bucketCount - 1, Int(position * Double(bucketCount)))
            }

            for channel in 0..<channelCount {
                let sample = max(-1, min(1, interleavedSamples[localFrame * channelCount + channel]))
                peaks[bucket] = max(peaks[bucket], abs(sample))
                sumSquares[bucket] += Double(sample * sample)
                sampleCounts[bucket] += 1
            }
        }
        processedFrames += frameCount
    }

    public func finalize() throws -> AudioWaveform {
        let rms = zip(sumSquares, sampleCounts).map { sum, count -> Float in
            guard count > 0 else { return 0 }
            return Float(sqrt(sum / Double(count)))
        }
        return try AudioWaveform(peaks: peaks, rms: rms)
    }
}
