import Foundation
import VertexCore
import VertexMedia

public enum RenderOperation: Codable, Equatable, Sendable {
    case transform(scale: Double, translationX: Double, translationY: Double)
    case transform2D(RenderTransform2D)
    case exposure(stops: Double)
    case saturation(Double)
    case invert(Bool)
    case opacity(Double)

    public func validated() throws -> Self {
        switch self {
        case .transform(let scale, let x, let y):
            guard scale.isFinite, scale > 0, x.isFinite, y.isFinite else {
                throw RenderError.invalidRequest("Transform values must be finite and scale must be positive.")
            }
        case .transform2D(let transform):
            _ = try transform.validated()
        case .exposure(let stops):
            guard stops.isFinite else { throw RenderError.invalidRequest("Exposure must be finite.") }
        case .saturation(let value):
            guard value.isFinite, value >= 0 else {
                throw RenderError.invalidRequest("Saturation must be finite and nonnegative.")
            }
        case .invert:
            break
        case .opacity(let value):
            guard value.isFinite, (0...1).contains(value) else {
                throw RenderError.invalidRequest("Opacity must be finite and within 0...1.")
            }
        }
        return self
    }
}

public struct RenderOutputSpecification: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let color: ColorDescriptor

    public init(
        width: Int,
        height: Int,
        color: ColorDescriptor = .rec709SDR(alphaMode: .straight)
    ) throws {
        guard (1...8192).contains(width), (1...8192).contains(height) else {
            throw RenderError.invalidRequest("Output dimensions must be between 1 and 8192 pixels.")
        }
        self.width = width
        self.height = height
        self.color = color
    }
}

public struct RenderMetrics: Codable, Equatable, Sendable {
    public let cpuEncodingMilliseconds: Double
    public let gpuExecutionMilliseconds: Double?
    public let totalMilliseconds: Double
    public let inputPixelCount: Int
    public let outputPixelCount: Int
    public let expandedNodeCount: Int
    public let renderedLayerCount: Int
    public let estimatedPeakTextureBytes: Int

    public var estimatedTextureBytes: Int { estimatedPeakTextureBytes }

    public init(
        cpuEncodingMilliseconds: Double,
        gpuExecutionMilliseconds: Double?,
        totalMilliseconds: Double,
        inputPixelCount: Int,
        outputPixelCount: Int,
        estimatedTextureBytes: Int,
        expandedNodeCount: Int = 0,
        renderedLayerCount: Int = 0
    ) {
        self.cpuEncodingMilliseconds = cpuEncodingMilliseconds
        self.gpuExecutionMilliseconds = gpuExecutionMilliseconds
        self.totalMilliseconds = totalMilliseconds
        self.inputPixelCount = inputPixelCount
        self.outputPixelCount = outputPixelCount
        self.expandedNodeCount = expandedNodeCount
        self.renderedLayerCount = renderedLayerCount
        self.estimatedPeakTextureBytes = estimatedTextureBytes
    }

    public init(
        cpuEncodingMilliseconds: Double,
        gpuExecutionMilliseconds: Double?,
        totalMilliseconds: Double,
        inputPixelCount: Int,
        outputPixelCount: Int,
        expandedNodeCount: Int,
        renderedLayerCount: Int,
        estimatedPeakTextureBytes: Int
    ) {
        self.cpuEncodingMilliseconds = cpuEncodingMilliseconds
        self.gpuExecutionMilliseconds = gpuExecutionMilliseconds
        self.totalMilliseconds = totalMilliseconds
        self.inputPixelCount = inputPixelCount
        self.outputPixelCount = outputPixelCount
        self.expandedNodeCount = expandedNodeCount
        self.renderedLayerCount = renderedLayerCount
        self.estimatedPeakTextureBytes = estimatedPeakTextureBytes
    }
}

public struct RenderCacheKey: RawRepresentable, Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

public struct RenderRequest: Codable, Equatable, Sendable {
    public let graph: RenderGraph
    public let time: RationalTime
    public let output: RenderOutputSpecification
    public let context: RenderCacheContext?

    public init(
        graph: RenderGraph,
        time: RationalTime,
        output: RenderOutputSpecification,
        context: RenderCacheContext? = nil
    ) throws {
        guard time.value >= 0 else { throw RenderError.invalidRequest("Render time must be non-negative.") }
        self.graph = graph
        self.time = time
        self.output = output
        self.context = context
        _ = try graph.evaluationPlan()
    }

    public var cacheKey: RenderCacheKey {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(self)) ?? Data()
        return RenderCacheKey(rawValue: StableSHA256.hexDigest(data))
    }
}

public struct RenderResult: Codable, Equatable, Sendable {
    public let image: PortableImage
    public let metrics: RenderMetrics
    public let cacheKey: RenderCacheKey

    public init(image: PortableImage, metrics: RenderMetrics, cacheKey: RenderCacheKey) {
        self.image = image
        self.metrics = metrics
        self.cacheKey = cacheKey
    }
}

public struct RenderExportPayload: Equatable, Sendable {
    public let data: Data

    public init(result: RenderResult) {
        self.data = result.image.data
    }
}
