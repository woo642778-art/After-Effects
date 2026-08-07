import Foundation
import VertexCore
import VertexMedia
import VertexProject
import VertexRender

public enum CompositionFrameResolution: Equatable, Sendable {
    case frame(PortableImage)
    case transparent
}

public protocol CompositionFrameResolver: Sendable {
    func resolve(
        mediaID: VertexID,
        exactSourceTime: RationalTime,
        targetSize: VertexSize
    ) async throws -> CompositionFrameResolution
}

public struct CompositionRenderLimits: Codable, Equatable, Sendable {
    public var maximumDimension: Int
    public var maximumLayersPerComposition: Int
    public var maximumNestedDepth: Int
    public var maximumExpandedNodes: Int

    public init(
        maximumDimension: Int = 8192,
        maximumLayersPerComposition: Int = 256,
        maximumNestedDepth: Int = 16,
        maximumExpandedNodes: Int = 4096
    ) {
        self.maximumDimension = maximumDimension
        self.maximumLayersPerComposition = maximumLayersPerComposition
        self.maximumNestedDepth = maximumNestedDepth
        self.maximumExpandedNodes = maximumExpandedNodes
    }

    public func validated() throws -> Self {
        guard maximumDimension > 0,
              maximumLayersPerComposition > 0,
              maximumNestedDepth > 0,
              maximumExpandedNodes > 0 else {
            throw CompositionError.graphCompilationFailed("Render limits must be positive.")
        }
        return self
    }
}

public struct CompositionRenderRequest: Sendable {
    public var project: ProjectDocument
    public var compositionID: VertexID
    public var time: RationalTime
    public var output: RenderOutputSpecification
    public var limits: CompositionRenderLimits

    public init(
        project: ProjectDocument,
        compositionID: VertexID,
        time: RationalTime,
        output: RenderOutputSpecification,
        limits: CompositionRenderLimits = CompositionRenderLimits()
    ) {
        self.project = project
        self.compositionID = compositionID
        self.time = time
        self.output = output
        self.limits = limits
    }
}

struct CompositionFrameCacheKey: Hashable, Sendable {
    var mediaID: VertexID
    var time: RationalTime
    var width: Int
    var height: Int
}
