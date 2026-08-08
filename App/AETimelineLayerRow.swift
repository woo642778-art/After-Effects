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
                .frame(width: 280, alignment: .leading)
            Divider().overlay(Color.white.opacity(0.08))
            timelineBar
                .frame(width: max(480, composition.duration.seconds * editorState.pixelsPerSecond), height: 34)
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
            .buttonStyle(.plain)
            Text(layer.name)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
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
            .menuStyle(.button)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .buttonStyle(.plain)
    }

    private var timelineBar: some View {
        GeometryReader { _ in
            let startX = layer.timing.inPoint.seconds * editorState.pixelsPerSecond
            let width = max(4, (layer.timing.outPoint.seconds - layer.timing.inPoint.seconds) * editorState.pixelsPerSecond)
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
                    .offset(x: startX + Double(moveOffset))
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
                    .offset(x: editorState.playhead.seconds * editorState.pixelsPerSecond)
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
                    let selection = editorState.selectedLayerIDs.contains(layer.id)
                        ? editorState.selectedLayerIDs.sorted(by: { $0.rawValue < $1.rawValue })
                        : [layer.id]
                    let edit = try AETimelineInteractionModel.moveEdit(
                        layerIDs: selection,
                        dragPoints: Double(value.translation.width),
                        pixelsPerSecond: editorState.pixelsPerSecond,
                        frameRate: composition.frameRate
                    )
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
                    let edit: TimelineEdit
                    if edge == .in {
                        edit = .trimIn(layerID: layer.id, to: try layer.timing.inPoint.adding(delta))
                    } else {
                        edit = .trimOut(layerID: layer.id, to: try layer.timing.outPoint.adding(delta))
                    }
                    try workspace.commitTimelineEdit(edit, compositionID: composition.id)
                    interactionError = nil
                } catch {
                    interactionError = error.localizedDescription
                }
            }
    }
}
