import Foundation
import VertexCore

public struct ProjectComposition: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var name: String
    public var width: Int
    public var height: Int
    public var duration: RationalTime
    public var frameRate: RationalTime
    public var color: ColorDescriptor
    public var backgroundColor: ProjectRGBAColor
    public var layerIDs: [VertexID]

    public init(
        id: VertexID = VertexID(),
        name: String,
        width: Int,
        height: Int,
        duration: RationalTime,
        frameRate: RationalTime,
        color: ColorDescriptor,
        backgroundColor: ProjectRGBAColor = .transparent,
        layerIDs: [VertexID] = []
    ) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.duration = duration
        self.frameRate = frameRate
        self.color = color
        self.backgroundColor = backgroundColor
        self.layerIDs = layerIDs
    }

    public func validated(layerByID: [VertexID: ProjectLayer]) throws -> Self {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.invalidValue("Composition name must not be empty.")
        }
        guard (1...8192).contains(width), (1...8192).contains(height) else {
            throw ProjectError.invalidValue("Composition dimensions must be between 1 and 8192 pixels.")
        }
        guard duration > .zero else {
            throw ProjectError.invalidValue("Composition duration must be positive.")
        }
        guard frameRate > .zero else {
            throw ProjectError.invalidValue("Composition frame rate must be positive.")
        }
        guard layerIDs.count <= 256 else {
            throw ProjectError.invalidValue("A composition may contain at most 256 layers.")
        }
        guard Set(layerIDs).count == layerIDs.count else {
            throw ProjectError.duplicateIdentity("composition layer order")
        }
        _ = try backgroundColor.validated()
        for layerID in layerIDs {
            guard let layer = layerByID[layerID] else {
                throw ProjectError.invalidValue("Composition layer order references a missing layer: \(layerID.rawValue).")
            }
            guard layer.compositionID == id else {
                throw ProjectError.invalidValue("Layer ownership does not match its composition order.")
            }
        }
        return self
    }
}
