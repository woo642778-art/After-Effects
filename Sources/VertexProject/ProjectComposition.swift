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
    public var workArea: ProjectWorkArea?
    public var markers: [ProjectMarker]

    private enum CodingKeys: String, CodingKey {
        case id, name, width, height, duration, frameRate, color, backgroundColor, layerIDs, workArea, markers
    }

    public init(
        id: VertexID = VertexID(),
        name: String,
        width: Int,
        height: Int,
        duration: RationalTime,
        frameRate: RationalTime,
        color: ColorDescriptor,
        backgroundColor: ProjectRGBAColor = .transparent,
        layerIDs: [VertexID] = [],
        workArea: ProjectWorkArea? = nil,
        markers: [ProjectMarker] = []
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
        self.workArea = workArea
        self.markers = markers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(VertexID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        duration = try container.decode(RationalTime.self, forKey: .duration)
        frameRate = try container.decode(RationalTime.self, forKey: .frameRate)
        color = try container.decode(ColorDescriptor.self, forKey: .color)
        backgroundColor = try container.decode(ProjectRGBAColor.self, forKey: .backgroundColor)
        layerIDs = try container.decode([VertexID].self, forKey: .layerIDs)
        workArea = try container.decodeIfPresent(ProjectWorkArea.self, forKey: .workArea)
        markers = try container.decodeIfPresent([ProjectMarker].self, forKey: .markers) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(duration, forKey: .duration)
        try container.encode(frameRate, forKey: .frameRate)
        try container.encode(color, forKey: .color)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(layerIDs, forKey: .layerIDs)
        try container.encodeIfPresent(workArea, forKey: .workArea)
        try container.encode(markers, forKey: .markers)
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
        if let workArea { _ = try workArea.validated(compositionDuration: duration) }
        guard Set(markers.map(\.id)).count == markers.count else {
            throw ProjectError.duplicateIdentity("composition marker")
        }
        for marker in markers { _ = try marker.validated(compositionDuration: duration) }
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
