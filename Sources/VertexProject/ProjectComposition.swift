import Foundation
import VertexCore

public enum ProjectCompositionPreviewResolution: String, Codable, CaseIterable, Sendable {
    case full
    case half
    case third
    case quarter

    public var scale: Double {
        switch self {
        case .full: 1
        case .half: 0.5
        case .third: 1.0 / 3.0
        case .quarter: 0.25
        }
    }
}

public enum ProjectCompositionRendererMode: String, Codable, CaseIterable, Sendable {
    case classic2D
}

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
    public var displayStartTime: RationalTime
    public var pixelAspectRatio: Double
    public var previewResolution: ProjectCompositionPreviewResolution
    public var bpm: Double?
    public var motionBlurShutterAngle: Double
    public var motionBlurShutterPhase: Double
    public var rendererMode: ProjectCompositionRendererMode

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case width
        case height
        case duration
        case frameRate
        case color
        case backgroundColor
        case layerIDs
        case workArea
        case markers
        case displayStartTime
        case pixelAspectRatio
        case previewResolution
        case bpm
        case motionBlurShutterAngle
        case motionBlurShutterPhase
        case rendererMode
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
        markers: [ProjectMarker] = [],
        displayStartTime: RationalTime = .zero,
        pixelAspectRatio: Double = 1,
        previewResolution: ProjectCompositionPreviewResolution = .full,
        bpm: Double? = nil,
        motionBlurShutterAngle: Double = 180,
        motionBlurShutterPhase: Double = -90,
        rendererMode: ProjectCompositionRendererMode = .classic2D
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
        self.displayStartTime = displayStartTime
        self.pixelAspectRatio = pixelAspectRatio
        self.previewResolution = previewResolution
        self.bpm = bpm
        self.motionBlurShutterAngle = motionBlurShutterAngle
        self.motionBlurShutterPhase = motionBlurShutterPhase
        self.rendererMode = rendererMode
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
        displayStartTime = try container.decodeIfPresent(RationalTime.self, forKey: .displayStartTime) ?? .zero
        pixelAspectRatio = try container.decodeIfPresent(Double.self, forKey: .pixelAspectRatio) ?? 1
        previewResolution = try container.decodeIfPresent(ProjectCompositionPreviewResolution.self, forKey: .previewResolution) ?? .full
        bpm = try container.decodeIfPresent(Double.self, forKey: .bpm)
        motionBlurShutterAngle = try container.decodeIfPresent(Double.self, forKey: .motionBlurShutterAngle) ?? 180
        motionBlurShutterPhase = try container.decodeIfPresent(Double.self, forKey: .motionBlurShutterPhase) ?? -90
        rendererMode = try container.decodeIfPresent(ProjectCompositionRendererMode.self, forKey: .rendererMode) ?? .classic2D
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
        try container.encode(displayStartTime, forKey: .displayStartTime)
        try container.encode(pixelAspectRatio, forKey: .pixelAspectRatio)
        try container.encode(previewResolution, forKey: .previewResolution)
        try container.encodeIfPresent(bpm, forKey: .bpm)
        try container.encode(motionBlurShutterAngle, forKey: .motionBlurShutterAngle)
        try container.encode(motionBlurShutterPhase, forKey: .motionBlurShutterPhase)
        try container.encode(rendererMode, forKey: .rendererMode)
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
        guard pixelAspectRatio.isFinite, pixelAspectRatio > 0, pixelAspectRatio <= 10 else {
            throw ProjectError.invalidValue("Composition pixel aspect ratio must be finite and within 0...10.")
        }
        if let bpm {
            guard bpm.isFinite, (1...999).contains(bpm) else {
                throw ProjectError.invalidValue("Composition BPM must be within 1...999.")
            }
        }
        guard motionBlurShutterAngle.isFinite, (0...720).contains(motionBlurShutterAngle) else {
            throw ProjectError.invalidValue("Motion-blur shutter angle must be within 0...720 degrees.")
        }
        guard motionBlurShutterPhase.isFinite, (-360...360).contains(motionBlurShutterPhase) else {
            throw ProjectError.invalidValue("Motion-blur shutter phase must be within -360...360 degrees.")
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
