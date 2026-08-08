import SwiftUI
import UIKit
import VertexCore
import VertexProject

struct VertexEditorWorkspaceView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var editorState = EditorWorkspaceState()
    @StateObject private var preview = CompositionPreviewController()

    var body: some View {
        Group {
            if workspace.project == nil {
                projectBootstrap
            } else if horizontalSizeClass == .regular {
                IPadEditorWorkspaceView(editorState: editorState, preview: preview)
            } else {
                IPhoneEditorWorkspaceView(editorState: editorState, preview: preview)
            }
        }
        .onAppear {
            synchronizeAndRender()
        }
        .onChange(of: workspace.project?.activeCompositionID) { _, _ in
            synchronizeAndRender()
        }
        .onChange(of: workspace.project?.revision) { _, _ in
            synchronizeAndRender()
        }
        .onChange(of: editorState.playhead) { _, _ in
            renderCurrentFrame()
        }
        .onChange(of: preview.aiResultGeneration) { _, _ in
            renderCurrentFrame()
        }
    }

    private var projectBootstrap: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                editorHeader
                ProjectWorkspaceView()
                MediaImportView()
            }
            .padding(18)
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 12) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Vertex2")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text("Professional Timeline Workspace")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            Spacer()
        }
    }

    private func synchronizeAndRender() {
        editorState.synchronize(project: workspace.project)
        if let selected = editorState.selectedLayerIDs.sorted(by: { $0.rawValue < $1.rawValue }).first {
            workspace.selectLayer(selected)
        }
        renderCurrentFrame()
    }

    private func renderCurrentFrame() {
        guard let project = workspace.project else {
            preview.cancel()
            return
        }
        preview.render(project: project, packageURL: workspace.packageURL, at: editorState.playhead)
    }
}

struct EditorPreviewSurface: View {
    @ObservedObject var preview: CompositionPreviewController
    @ObservedObject var editorState: EditorWorkspaceState
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("COMPOSITION")
                    .font(.caption.bold())
                    .foregroundStyle(AfterEffectsTheme.accent)
                Spacer()
                Text(editorState.playhead.description)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            ZStack {
                Color.black
                if let result = preview.result, let image = UIImage(data: result.image.data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else if preview.isRendering {
                    ProgressView("Rendering")
                        .tint(AfterEffectsTheme.accent)
                } else {
                    Text("No rendered frame")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
            }
            .aspectRatio(previewAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            if let error = preview.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private var previewAspectRatio: CGFloat {
        guard let composition = workspace.activeComposition, composition.height > 0 else { return 16 / 9 }
        return CGFloat(composition.width) / CGFloat(composition.height)
    }
}

struct WorkspaceTimelineOverview: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TIMELINE")
                    .font(.caption.bold())
                    .foregroundStyle(AfterEffectsTheme.accent)
                Spacer()
                Toggle("Snap", isOn: $editorState.snappingEnabled)
                    .labelsHidden()
                Text("Snap")
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            if let composition = workspace.activeComposition {
                Slider(
                    value: Binding(
                        get: { Double(currentFrame(composition)) },
                        set: { editorState.setPlayhead(frameIndex: Int64($0.rounded()), composition: composition) }
                    ),
                    in: 0...Double(max(1, lastFrame(composition))),
                    step: 1
                )
                .tint(AfterEffectsTheme.accent)
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(workspace.orderedLayers) { layer in
                            Button {
                                editorState.selectLayer(layer.id)
                                workspace.selectLayer(layer.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: layer.enabled ? "eye.fill" : "eye.slash")
                                        .frame(width: 18)
                                    Text(layer.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(String(format: "%.2fs", layer.timing.startTime.seconds))
                                        .font(.caption2.monospacedDigit())
                                }
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    editorState.selectedLayerIDs.contains(layer.id)
                                        ? AfterEffectsTheme.accent.opacity(0.18)
                                        : Color.white.opacity(0.035),
                                    in: RoundedRectangle(cornerRadius: 7)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text("Select a composition")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
    }

    private func currentFrame(_ composition: ProjectComposition) -> Int64 {
        guard composition.frameRate.seconds > 0 else { return 0 }
        return max(0, Int64((editorState.playhead.seconds * composition.frameRate.seconds).rounded()))
    }

    private func lastFrame(_ composition: ProjectComposition) -> Int64 {
        guard composition.frameRate.seconds > 0 else { return 0 }
        return max(0, Int64(floor(composition.duration.seconds * composition.frameRate.seconds + 0.0000001)) - 1)
    }
}
