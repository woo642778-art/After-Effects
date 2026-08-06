import Foundation
import VertexCore

public enum FrameTolerance: String, Codable, CaseIterable, Sendable {
    case exact
    case nearest
}

public struct MediaTimeRange: Codable, Equatable, Sendable {
    public let start: RationalTime
    public let duration: RationalTime

    public init(start: RationalTime, duration: RationalTime) throws {
        guard start.value >= 0, duration.value > 0 else {
            throw MediaError.invalidRequest("Time range start must be non-negative and duration must be positive.")
        }
        self.start = start
        self.duration = duration
    }
}

public struct VideoFrameRequest: Codable, Equatable, Sendable {
    public let time: RationalTime
    public let targetSize: VertexSize
    public let tolerance: FrameTolerance

    public init(time: RationalTime, targetSize: VertexSize, tolerance: FrameTolerance) throws {
        guard time.value >= 0 else { throw MediaError.invalidRequest("Frame time must be non-negative.") }
        guard targetSize.width.isFinite, targetSize.height.isFinite, targetSize.width > 0, targetSize.height > 0 else {
            throw MediaError.invalidRequest("Target size must be finite and positive.")
        }
        self.time = time
        self.targetSize = targetSize
        self.tolerance = tolerance
    }
}

public struct AudioWaveformRequest: Codable, Equatable, Sendable {
    public let timeRange: MediaTimeRange
    public let bucketCount: Int

    public init(timeRange: MediaTimeRange, bucketCount: Int) throws {
        guard (16...4096).contains(bucketCount) else {
            throw MediaError.invalidRequest("Waveform bucket count must be between 16 and 4096.")
        }
        self.timeRange = timeRange
        self.bucketCount = bucketCount
    }
}

public enum PortableImageFormat: String, Codable, CaseIterable, Sendable {
    case png
    case jpeg
}

public struct PortableImage: Codable, Equatable, Sendable {
    public let data: Data
    public let format: PortableImageFormat
    public let pixelSize: VertexSize

    public init(data: Data, format: PortableImageFormat, pixelSize: VertexSize) throws {
        guard !data.isEmpty else { throw MediaError.decodeFailed("Decoded image data is empty.") }
        guard pixelSize.width > 0, pixelSize.height > 0 else {
            throw MediaError.decodeFailed("Decoded image dimensions are invalid.")
        }
        self.data = data
        self.format = format
        self.pixelSize = pixelSize
    }
}

public struct VideoFrame: Codable, Equatable, Sendable {
    public let requestedTime: RationalTime
    public let actualTime: RationalTime
    public let image: PortableImage

    public init(requestedTime: RationalTime, actualTime: RationalTime, image: PortableImage) {
        self.requestedTime = requestedTime
        self.actualTime = actualTime
        self.image = image
    }
}

public struct AudioWaveform: Codable, Equatable, Sendable {
    public let peaks: [Float]
    public let rms: [Float]

    public var bucketCount: Int { peaks.count }

    public init(peaks: [Float], rms: [Float]) throws {
        guard !peaks.isEmpty, peaks.count == rms.count else {
            throw MediaError.invalidRequest("Waveform peak and RMS arrays must be non-empty and have equal counts.")
        }
        guard peaks.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              rms.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw MediaError.invalidRequest("Waveform values must be finite and normalized to 0...1.")
        }
        self.peaks = peaks
        self.rms = rms
    }
}
