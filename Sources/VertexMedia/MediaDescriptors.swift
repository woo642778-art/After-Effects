import Foundation
import VertexCore

public enum VariableFrameRateStatus: String, Codable, CaseIterable, Sendable {
    case constant
    case variable
    case unknown
}

public struct VideoStreamDescriptor: Codable, Equatable, Sendable {
    public let streamIndex: Int
    public let pixelSize: VertexSize
    public let nominalFrameRate: Double
    public let variableFrameRateStatus: VariableFrameRateStatus
    public let codec: String
    public let color: ColorDescriptor?
    public let isHDR: Bool
    public let hasAlpha: Bool
    public let rotationDegrees: Int

    public init(streamIndex: Int, pixelSize: VertexSize, nominalFrameRate: Double, variableFrameRateStatus: VariableFrameRateStatus, codec: String, color: ColorDescriptor?, isHDR: Bool, hasAlpha: Bool, rotationDegrees: Int) {
        self.streamIndex = streamIndex
        self.pixelSize = pixelSize
        self.nominalFrameRate = nominalFrameRate
        self.variableFrameRateStatus = variableFrameRateStatus
        self.codec = codec
        self.color = color
        self.isHDR = isHDR
        self.hasAlpha = hasAlpha
        self.rotationDegrees = rotationDegrees
    }

    public func validated() throws -> Self {
        guard streamIndex >= 0 else { throw MediaError.invalidRequest("Video stream index must be non-negative.") }
        guard pixelSize.width.isFinite, pixelSize.height.isFinite, pixelSize.width > 0, pixelSize.height > 0 else {
            throw MediaError.invalidRequest("Video dimensions must be finite and positive.")
        }
        guard nominalFrameRate.isFinite, nominalFrameRate >= 0 else {
            throw MediaError.invalidRequest("Nominal frame rate must be finite and non-negative.")
        }
        return self
    }
}

public struct AudioStreamDescriptor: Codable, Equatable, Sendable {
    public let streamIndex: Int
    public let sampleRate: Double
    public let channelCount: Int
    public let codec: String
    public let estimatedBitRate: Double?

    public init(streamIndex: Int, sampleRate: Double, channelCount: Int, codec: String, estimatedBitRate: Double?) {
        self.streamIndex = streamIndex
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.codec = codec
        self.estimatedBitRate = estimatedBitRate
    }

    public func validated() throws -> Self {
        guard streamIndex >= 0 else { throw MediaError.invalidRequest("Audio stream index must be non-negative.") }
        guard sampleRate.isFinite, sampleRate > 0 else { throw MediaError.invalidRequest("Audio sample rate must be finite and positive.") }
        guard channelCount > 0 else { throw MediaError.invalidRequest("Audio channel count must be positive.") }
        return self
    }
}

public struct MediaAssetDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: VertexID
    public let filename: String
    public let duration: RationalTime
    public let containerHint: String?
    public let videoStreams: [VideoStreamDescriptor]
    public let audioStreams: [AudioStreamDescriptor]

    public init(id: VertexID = VertexID(), filename: String, duration: RationalTime, containerHint: String?, videoStreams: [VideoStreamDescriptor], audioStreams: [AudioStreamDescriptor]) {
        self.id = id
        self.filename = filename
        self.duration = duration
        self.containerHint = containerHint
        self.videoStreams = videoStreams
        self.audioStreams = audioStreams
    }

    public func validated() throws -> Self {
        guard !filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MediaError.invalidRequest("Filename must not be empty.")
        }
        guard duration.value >= 0 else { throw MediaError.invalidRequest("Duration must not be negative.") }
        for stream in videoStreams { _ = try stream.validated() }
        for stream in audioStreams { _ = try stream.validated() }
        guard !videoStreams.isEmpty || !audioStreams.isEmpty else {
            throw MediaError.unsupportedAsset("No decodable audio or video streams were found.")
        }
        return self
    }
}
