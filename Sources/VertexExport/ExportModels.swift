import Foundation
import VertexCore

public enum ExportFormat: String, Codable, Sendable, CaseIterable {
    case mov
    case mp4
    case gif
    case pngSequence
    case jpegSequence

    public var fileExtension: String {
        switch self {
        case .mov: "mov"
        case .mp4: "mp4"
        case .gif: "gif"
        case .pngSequence: "png"
        case .jpegSequence: "jpg"
        }
    }

    public var isVideoContainer: Bool { self == .mov || self == .mp4 }
    public var isImageSequence: Bool { self == .pngSequence || self == .jpegSequence }
}

public enum ExportVideoCodec: String, Codable, Sendable, CaseIterable {
    case h264
    case hevc
    case proRes422
    case proRes4444
}

public struct ExportDimensions: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public enum ExportResolutionPreset: String, Codable, Sendable, CaseIterable {
    case matchComposition
    case hd720
    case hd1080
    case qhd1440
    case uhd4K
    case dci4K
    case uhd5K
    case uhd6K
    case uhd8K
    case dci8K
    case custom

    public var dimensions: ExportDimensions? {
        switch self {
        case .matchComposition, .custom:
            nil
        case .hd720:
            ExportDimensions(width: 1280, height: 720)
        case .hd1080:
            ExportDimensions(width: 1920, height: 1080)
        case .qhd1440:
            ExportDimensions(width: 2560, height: 1440)
        case .uhd4K:
            ExportDimensions(width: 3840, height: 2160)
        case .dci4K:
            ExportDimensions(width: 4096, height: 2160)
        case .uhd5K:
            ExportDimensions(width: 5120, height: 2880)
        case .uhd6K:
            ExportDimensions(width: 6144, height: 3456)
        case .uhd8K:
            ExportDimensions(width: 7680, height: 4320)
        case .dci8K:
            ExportDimensions(width: 8192, height: 4320)
        }
    }
}

public enum ExportQualityPreset: String, Codable, Sendable, CaseIterable {
    case compact
    case balanced
    case high
    case master

    public func targetBitRate(width: Int, height: Int, fps: Double) -> Int {
        let pixelsPerSecond = Double(max(1, width)) * Double(max(1, height)) * max(1, fps)
        let bitsPerPixel: Double
        switch self {
        case .compact: bitsPerPixel = 0.055
        case .balanced: bitsPerPixel = 0.09
        case .high: bitsPerPixel = 0.145
        case .master: bitsPerPixel = 0.22
        }
        let raw = pixelsPerSecond * bitsPerPixel
        return Int(min(max(raw.rounded(), 500_000), 800_000_000))
    }

    public var jpegQuality: Double {
        switch self {
        case .compact: 0.72
        case .balanced: 0.84
        case .high: 0.93
        case .master: 1.0
        }
    }
}

public enum ExportValidationError: Error, Sendable, Equatable {
    case invalidDimensions
    case invalidFrameRate
    case invalidDuration
    case invalidOutputURL
    case codecRequired
    case codecNotAllowed(ExportVideoCodec, ExportFormat)
    case alphaRequiresMOV
    case alphaRequiresProRes4444
    case frameSizeMismatch(expected: Int, actual: Int)
    case duplicateJobID
}

public struct ExportJob: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var format: ExportFormat
    public var codec: ExportVideoCodec?
    public var quality: ExportQualityPreset
    public var width: Int
    public var height: Int
    public var frameRate: RationalTime
    public var outputURL: URL
    public var includeAlpha: Bool
    public var includeAudio: Bool

    public init(
        id: UUID = UUID(),
        format: ExportFormat,
        codec: ExportVideoCodec?,
        quality: ExportQualityPreset = .high,
        width: Int,
        height: Int,
        frameRate: RationalTime,
        outputURL: URL,
        includeAlpha: Bool = false,
        includeAudio: Bool = true
    ) {
        self.id = id
        self.format = format
        self.codec = codec
        self.quality = quality
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.outputURL = outputURL
        self.includeAlpha = includeAlpha
        self.includeAudio = includeAudio
    }

    public var fps: Double { frameRate.seconds }

    public func validated() throws -> Self {
        guard (1...8192).contains(width), (1...8192).contains(height) else { throw ExportValidationError.invalidDimensions }
        guard frameRate > .zero, fps.isFinite, fps > 0, fps <= 240 else { throw ExportValidationError.invalidFrameRate }
        guard outputURL.isFileURL else { throw ExportValidationError.invalidOutputURL }
        if format.isVideoContainer {
            guard let codec else { throw ExportValidationError.codecRequired }
            switch format {
            case .mp4:
                guard codec == .h264 || codec == .hevc else { throw ExportValidationError.codecNotAllowed(codec, format) }
            case .mov:
                break
            default:
                break
            }
        }
        if includeAlpha {
            guard format == .mov else { throw ExportValidationError.alphaRequiresMOV }
            guard codec == .proRes4444 else { throw ExportValidationError.alphaRequiresProRes4444 }
        }
        return self
    }

    public func exactPresentationTime(frameIndex: Int64) throws -> RationalTime {
        guard frameIndex >= 0 else { throw ExportValidationError.invalidFrameRate }
        guard frameRate.value > 0, frameRate.value <= Int64(Int32.max) else { throw ExportValidationError.invalidFrameRate }
        let numerator = frameIndex.multipliedReportingOverflow(by: Int64(frameRate.timescale))
        guard !numerator.overflow else { throw ExportValidationError.invalidFrameRate }
        return RationalTime(value: numerator.partialValue, timescale: Int32(frameRate.value))
    }

    /// Number of output samples whose presentation times cover `duration`.
    /// The computation is fully rational and rounds up, so fractional rates such as
    /// 30000/1001 and 60000/1001 cannot lose the final partial frame through Double conversion.
    public func frameCount(for duration: RationalTime) throws -> Int64 {
        guard duration > .zero, frameRate > .zero else { throw ExportValidationError.invalidDuration }

        var durationNumerator = duration.value.magnitude
        var rateNumerator = frameRate.value.magnitude
        var durationDenominator = UInt64(duration.timescale)
        var rateDenominator = UInt64(frameRate.timescale)

        var factor = Self.gcd(durationNumerator, rateDenominator)
        durationNumerator /= factor
        rateDenominator /= factor
        factor = Self.gcd(rateNumerator, durationDenominator)
        rateNumerator /= factor
        durationDenominator /= factor

        let numeratorProduct = durationNumerator.multipliedReportingOverflow(by: rateNumerator)
        guard !numeratorProduct.overflow else { throw ExportValidationError.invalidDuration }
        let denominatorProduct = durationDenominator.multipliedReportingOverflow(by: rateDenominator)
        guard !denominatorProduct.overflow, denominatorProduct.partialValue > 0 else {
            throw ExportValidationError.invalidDuration
        }

        let numerator = numeratorProduct.partialValue
        let denominator = denominatorProduct.partialValue
        let quotient = numerator / denominator
        let remainder = numerator % denominator
        let rounded = remainder == 0 ? quotient : quotient.addingReportingOverflow(1).partialValue
        guard rounded > 0, rounded <= UInt64(Int64.max) else { throw ExportValidationError.invalidDuration }
        return Int64(rounded)
    }

    private static func gcd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        var a = lhs
        var b = rhs
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return max(a, 1)
    }
}

public struct ExportRGBAFrame: Sendable, Equatable {
    public var width: Int
    public var height: Int
    public var rgba8: Data

    public init(width: Int, height: Int, rgba8: Data) throws {
        guard width > 0, height > 0 else { throw ExportValidationError.invalidDimensions }
        let product = width.multipliedReportingOverflow(by: height)
        guard !product.overflow else { throw ExportValidationError.invalidDimensions }
        let bytes = product.partialValue.multipliedReportingOverflow(by: 4)
        guard !bytes.overflow else { throw ExportValidationError.invalidDimensions }
        guard rgba8.count == bytes.partialValue else {
            throw ExportValidationError.frameSizeMismatch(expected: bytes.partialValue, actual: rgba8.count)
        }
        self.width = width
        self.height = height
        self.rgba8 = rgba8
    }
}
