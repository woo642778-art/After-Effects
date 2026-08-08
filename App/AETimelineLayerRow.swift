import SwiftUI
import VertexCore
import VertexProject
import VertexTimeline

struct AETimelineLayerRow: View {
    let layer: ProjectLayer
    let index: Int
    let composition: ProjectComposition
    @ObservedObject var editorState: EditorWorkspaceState
    @Binding var interactionError: String?
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var moveOffset: CGFloat = 0
    @State private var trimInOffset: CGFloat = 0
    @State private var trimOutOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            controls
                .frame(width: 420, alignment: .leading)
            Divider().overlay(Color.white.opacity(0.08))
            timelineBar
                .frame(width: CGFloat(max(480, composition.duration.seconds * editorState.pixelsPerSecond)), height: 34)
        }
        .frame(height: 36)
        .background(editorState.selectedLayerIDs.contains(layer.id) ? AfterEffectsTheme.accent.opacity(0.09) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            editorState.selectLayer(layer.id)
            workspace.selectLayer(layer.id)
        }
    }

    private var controls: some View {
        HStack(spacing: 5) {
            Text("\(index + 1)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Button {
                workspace.phase9SetLayerEnabled(layerID: layer.id, value: !layer.enabled)
            } label: {
                Image(systemName: layer.enabled ? "eye.fill" : "eye.slash")
            }
            Button {
                workspace.phase9SetLayerSolo(layerID: layer.id, value: !layer.solo)
            } label: {
                Text("S").font(.caption2.bold()).foregroundStyle(layer.solo ? .yellow : .secondary)
            }
            Button {
                workspace.phase9SetLayerLocked(layerID: layer.id, value: !layer.locked)
            } label: {
                Image(systemName: layer.locked ? "lock.fill" : "lock.open")
            }
            Text(layer.name)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button("None") { setParent(nil) }
                Divider()
                ForEach(workspace.orderedLayers.filter { $0.id != layer.id }) { candidate in
                    Button(candidate.name) { setParent(candidate.id) }
                }
            } label: {
                Label(layer.parentLayerID == nil ? "Parent" : "P", systemImage: "point.3.connected.trianglepath.dotted")
                    .labelStyle(.iconOnly)
            }

            Menu {
                Button("No Matte") { setMatte(nil) }
                Divider()
                ForEach(workspace.orderedLayers.filter { $0.id != layer.id }) { source in
                    Menu(source.name) {
                        ForEach(ProjectTrackMatteMode.allCases, id: \.self) { mode in
                            Button(matteLabel(mode)) {
                                setMatte(ProjectTrackMatte(sourceLayerID: source.id, mode: mode))
                            }
                        }
                    }
                }
            } label: {
                Label(layer.trackMatte == nil ? "Matte" : "M", systemImage: "circle.lefthalf.filled")
                    .labelStyle(.iconOnly)
            }

            Menu {
                ForEach(LayerBlendMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue.capitalized) {
                        workspace.phase9SetLayerBlendMode(layerID: layer.id, mode: mode)
                    }
                }
            } label: {
                Text(layer.blendMode.rawValue.prefix(3).uppercased())
                    .font(.caption2.monospaced())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .buttonStyle(.plain)
    }

    private var timelineBar: some View {
        GeometryReader { _ in
            let startX = CGFloat(layer.timing.inPoint.seconds * editorState.pixelsPerSecond)
            let width = CGFloat(max(4, (layer.timing.outPoint.seconds - layer.timing.inPoint.seconds) * editorState.pixelsPerSecond))
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.025))
                RoundedRectangle(cornerRadius: 3)
                    .fill(AfterEffectsTheme.accent.opacity(layer.enabled ? 0.45 : 0.16))
                    .overlay(alignment: .leading) {
                        Rectangle().fill(AfterEffectsTheme.accent).frame(width: 3)
                    }
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(AfterEffectsTheme.accent).frame(width: 3)
                    }
                    .frame(width: width)
                    .offset(x: startX + moveOffset)
                    .gesture(moveGesture)
                    .overlay(alignment: .leading) {
                        Color.clear
                            .frame(width: 12)
                            .contentShape(Rectangle())
                            .offset(x: trimInOffset)
                            .gesture(trimGesture(edge: .in))
                    }
                    .overlay(alignment: .trailing) {
                        Color.clear
                            .frame(width: 12)
                            .contentShape(Rectangle())
                            .offset(x: trimOutOffset)
                            .gesture(trimGesture(edge: .out))
                    }
                Rectangle()
                    .fill(AfterEffectsTheme.accent)
                    .frame(width: 1)
                    .offset(x: CGFloat(editorState.playhead.seconds * editorState.pixelsPerSecond))
            }
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { moveOffset = $0.translation.width }
            .onEnded { value in
                defer { moveOffset = 0 }
                guard !layer.locked else { return }
                do {
                    let delta = try AETimelineInteractionModel.exactDelta(
                        points: Double(value.translation.width),
                        pixelsPerSecond: editorState.pixelsPerSecond,
                        frameRate: composition.frameRate
                    )
                    let edit: TimelineEdit
                    switch editorState.activeTool {
                    case .selection:
                        let selection = editorState.selectedLayerIDs.contains(layer.id)
                            ? editorState.selectedLayerIDs.sorted(by: { $0.rawValue < $1.rawValue })
                            : [layer.id]
                        edit = .move(layerIDs: selection, delta: delta)
                    case .slip:
                        edit = .slip(layerID: layer.id, sourceDelta: delta)
                    case .slide:
                        let layers = workspace.orderedLayers
                        let previous = index > 0 ? layers[index - 1].id : nil
                        let next = index + 1 < layers.count ? layers[index + 1].id : nil
                        edit = .slide(layerID: layer.id, delta: delta, previousLayerID: previous, nextLayerID: next)
                    case .roll:
                        guard index > 0 else {
                            throw ProjectError.invalidOperation("Roll needs a layer immediately before the selected layer.")
                        }
                        edit = .roll(
                            leftLayerID: workspace.orderedLayers[index - 1].id,
                            rightLayerID: layer.id,
                            boundary: try layer.timing.inPoint.adding(delta)
                        )
                    case .ripple:
                        throw ProjectError.invalidOperation("Use a layer trim handle while Ripple is selected.")
                    }
                    try workspace.commitTimelineEdit(edit, compositionID: composition.id)
                    interactionError = nil
                } catch {
                    interactionError = error.localizedDescription
                }
            }
    }

    private func trimGesture(edge: TimelineEdge) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if edge == .in { trimInOffset = value.translation.width } else { trimOutOffset = value.translation.width }
            }
            .onEnded { value in
                defer { trimInOffset = 0; trimOutOffset = 0 }
                guard !layer.locked else { return }
                do {
                    let delta = try AETimelineInteractionModel.exactDelta(
                        points: Double(value.translation.width),
                        pixelsPerSecond: editorState.pixelsPerSecond,
                        frameRate: composition.frameRate
                    )
                    let proposed = edge == .in
                        ? try layer.timing.inPoint.adding(delta)
                        : try layer.timing.outPoint.adding(delta)
                    let edit: TimelineEdit
                    if editorState.activeTool == .ripple {
                        let affected = workspace.orderedLayers
                            .filter { $0.id != layer.id && $0.timing.inPoint >= (edge == .in ? layer.timing.inPoint : layer.timing.outPoint) }
                            .map(\.id)
                        edit = .ripple(layerID: layer.id, edge: edge, to: proposed, affectedLayerIDs: affected)
                    } else if edge == .in {
                        edit = .trimIn(layerID: layer.id, to: proposed)
                    } else {
                        edit = .trimOut(layerID: layer.id, to: proposed)
                    }
                    try workspace.commitTimelineEdit(edit, compositionID: composition.id)
                    interactionError = nil
                } catch {
                    interactionError = error.localizedDescription
                }
            }
    }

    private func setParent(_ parentID: VertexID?) {
        workspace.setLayerParent(layerID: layer.id, parentLayerID: parentID)
        interactionError = nil
    }

    private func setMatte(_ matte: ProjectTrackMatte?) {
        do {
            try workspace.phase9SetTrackMatte(layerID: layer.id, matte: matte)
            interactionError = nil
        } catch {
            interactionError = error.localizedDescription
        }
    }

    private func matteLabel(_ mode: ProjectTrackMatteMode) -> String {
        switch mode {
        case .alpha: "Alpha"
        case .alphaInverted: "Alpha Inverted"
        case .luma: "Luma"
        case .lumaInverted: "Luma Inverted"
        }
    }
}
