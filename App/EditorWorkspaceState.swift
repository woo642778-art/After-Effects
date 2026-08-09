import Foundation
import VertexCore
import VertexProject

public enum TimelineTool: String, CaseIterable, Sendable {
    case selection
    case ripple
    case roll
    case slip
    case slide
}

public enum GraphEditorMode: String, CaseIterable, Sendable {
    case value
    case speed
}

public enum CompactEditorPanel: String, CaseIterable, Sendable {
    case timeline
    case effects
    case project
}

@MainActor
final class EditorWorkspaceState: ObservableObject {
    @Published var playhead: RationalTime = .zero
    @Published var selectedLayerIDs: Set<VertexID> = []
    @Published var selectedKeyframeIDs: Set<VertexID> = []
    @Published var activeTool: TimelineTool = .selection
    @Published var snappingEnabled = true
    @Published var pixelsPerSecond: Double = 120
    @Published var graphMode: GraphEditorMode? = nil
    @Published var compactPanel: CompactEditorPanel = .timeline
    @Published var activeWorkspace: AEWorkspacePreset
    @Published var leftDockTab: AELeftDockTab = .project
    @Published var isLeftDrawerPresented = false
    @Published var isRightDrawerPresented = false

    private(set) var activeCompositionID: VertexID?

    init(userDefaults: UserDefaults = .standard) {
        if let raw = userDefaults.string(forKey: "vertex2.workspace.preset"),
           let preset = AEWorkspacePreset(rawValue: raw) {
            activeWorkspace = preset
        } else {
            activeWorkspace = .standard
        }
    }

    func setWorkspace(_ preset: AEWorkspacePreset, userDefaults: UserDefaults = .standard) {
        activeWorkspace = preset
        userDefaults.set(preset.rawValue, forKey: "vertex2.workspace.preset")
        if preset == .minimal {
            isLeftDrawerPresented = false
            isRightDrawerPresented = false
        }
    }

    func synchronize(project: ProjectDocument?) {
        guard let project,
              let compositionID = project.activeCompositionID,
              let composition = project.composition(id: compositionID) else {
            activeCompositionID = nil
            playhead = .zero
            selectedLayerIDs.removeAll()
            selectedKeyframeIDs.removeAll()
            return
        }

        let compositionChanged = activeCompositionID != compositionID
        activeCompositionID = compositionID
        let validLayerIDs = Set(composition.layerIDs)
        selectedLayerIDs.formIntersection(validLayerIDs)
        if selectedLayerIDs.isEmpty,
           let selected = project.selectedLayerID,
           validLayerIDs.contains(selected) {
            selectedLayerIDs = [selected]
        }
        if compositionChanged || selectedLayerIDs.isEmpty {
            selectedKeyframeIDs.removeAll()
        } else {
            let validKeyframes = Set(
                project.layerRegistry
                    .filter { selectedLayerIDs.contains($0.id) }
                    .flatMap(\.animationChannels)
                    .flatMap(\.keyframes)
                    .map(\.id)
            )
            selectedKeyframeIDs.formIntersection(validKeyframes)
        }
        clampPlayhead(to: composition)
    }

    func setPlayhead(_ time: RationalTime, composition: ProjectComposition) {
        playhead = time
        clampPlayhead(to: composition)
    }

    func setPlayhead(frameIndex: Int64, composition: ProjectComposition) {
        guard composition.frameRate.value > 0,
              composition.frameRate.value <= Int64(Int32.max) else {
            playhead = .zero
            return
        }
        let index = max(0, frameIndex)
        let product = index.multipliedReportingOverflow(by: Int64(composition.frameRate.timescale))
        guard !product.overflow else {
            playhead = composition.duration
            return
        }
        playhead = RationalTime(
            value: product.partialValue,
            timescale: Int32(composition.frameRate.value)
        )
        clampPlayhead(to: composition)
    }

    func selectLayer(_ id: VertexID?, additive: Bool = false) {
        guard let id else {
            selectedLayerIDs.removeAll()
            selectedKeyframeIDs.removeAll()
            return
        }
        if additive {
            if selectedLayerIDs.remove(id) == nil { selectedLayerIDs.insert(id) }
        } else {
            selectedLayerIDs = [id]
        }
        selectedKeyframeIDs.removeAll()
    }

    private func clampPlayhead(to composition: ProjectComposition) {
        if playhead < .zero { playhead = .zero }
        if playhead > composition.duration { playhead = composition.duration }
    }
}
