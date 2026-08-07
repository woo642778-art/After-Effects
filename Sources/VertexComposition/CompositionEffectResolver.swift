import Foundation
import VertexCore
import VertexMedia
import VertexProject

public enum CompositionRenderPurpose: String, Codable, Sendable {
    case interactivePreview
    case export
}

public struct CompositionEffectRequest: Sendable {
    public var projectID: VertexID
    public var projectRevision: UInt64
    public var compositionID: VertexID
    public var layerID: VertexID
    public var effect: ProjectEffect
    public var exactCompositionTime: RationalTime
    public var exactSourceTime: RationalTime
    public var input: PortableImage
    public var targetSize: VertexSize
    public var purpose: CompositionRenderPurpose

    public init(
        projectID: VertexID,
        projectRevision: UInt64,
        compositionID: VertexID,
        layerID: VertexID,
        effect: ProjectEffect,
        exactCompositionTime: RationalTime,
        exactSourceTime: RationalTime,
        input: PortableImage,
        targetSize: VertexSize,
        purpose: CompositionRenderPurpose
    ) {
        self.projectID = projectID
        self.projectRevision = projectRevision
        self.compositionID = compositionID
        self.layerID = layerID
        self.effect = effect
        self.exactCompositionTime = exactCompositionTime
        self.exactSourceTime = exactSourceTime
        self.input = input
        self.targetSize = targetSize
        self.purpose = purpose
    }
}

public protocol CompositionEffectResolver: Sendable {
    func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage
}

public struct RejectingCompositionEffectResolver: CompositionEffectResolver {
    public init() {}
    public func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage {
        throw CompositionError.graphCompilationFailed(
            "Layer \(request.layerID.rawValue) requires effect \(request.effect.type.rawValue), but no effect resolver was provided."
        )
    }
}
