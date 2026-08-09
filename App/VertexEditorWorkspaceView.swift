import SwiftUI
import UIKit
import VertexCore
import VertexProject

enum VertexWorkspaceMode: String, CaseIterable, Identifiable {
    case composition = "Composition"
    case automation = "Tools"
    case threeD = "3D"
    case export = "Export"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .composition: "rectangle.on.rectangle"
        case .automation: "command"
        case .threeD: "cube"
        case .export: "square.and.arrow.up"
        }
    }
}

struct VertexEditorWorkspaceView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @StateObject private var editorState = EditorWorkspaceState()
    @StateObject private var preview = CompositionPreviewController()
    @State private var workspaceMode: VertexWorkspaceMode = .composition

    var body: some View {
        Group {
            if workspace.project == nil {
                projectBootstrap
            } else {
                VStack(spacing: 0) {
                    workspaceModeBar
                    switch workspaceMode {
                    case .composition:
                        IPadEditorWorkspaceView(editorState: editorState, preview: preview)
                    case .automation:
                        AutomationWorkspaceView(editorState: editorState)
                    case .threeD:
                        ThreeDWorkspaceView()
                    case .export:
                        ExportWorkspaceView()
                    }
                }
                .background(AfterEffectsTheme.background)
            }
        }
        .onAppear { synchronizeAndRender() }
        .onChange(of: workspace.project?.activeCompositionID) { _, _ in synchronizeAndRender() }
        .onChange(of: workspace.project?.revision) { _, _ in synchronizeAndRender() }
        .onChange(of: editorState.playhead) { _, _ in renderCurrentFrame() }
        .onChange(of: preview.aiResultGeneration) { _, _ in renderCurrentFrame() }
        .onChange(of: workspaceMode) { _, mode in
            if mode == .composition { renderCurrentFrame() }
            else { preview.cancel() }
        }
    }

    private var workspaceModeBar: some View {
        HStack(spacing: 4) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text("Vertex2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AfterEffectsTheme.primaryText)
                .padding(.trailing, 8)
            ForEach(VertexWorkspaceMode.allCases) { mode in
                Button {
                    workspaceMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: mode.systemImage)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 9)
                        .frame(height: 27)
                        .foregroundStyle(workspaceMode == mode ? AfterEffectsTheme.primaryText : AfterEffectsTheme.secondaryText)
                        .background(workspaceMode == mode ? AfterEffectsTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if let composition = workspace.activeComposition {
                Text(composition.name)
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 34)
        .background(AfterEffectsTheme.elevatedPanel)
        .overlay(alignment: .bottom) { Rectangle().fill(AfterEffectsTheme.border).frame(height: 1) }
    }

    private var projectBootstrap: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Vertex2")
                            .font(.subheadline.bold())
                            .foregroundStyle(AfterEffectsTheme.primaryText)
                        Text("Create or open a project")
                            .font(.caption2)
                            .foregroundStyle(AfterEffectsTheme.secondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(AfterEffectsTheme.elevatedPanel)

                HStack(spacing: 0) {
                    AEPanel(title: "Project", systemImage: "folder") {
                        AEProjectPanelContent()
                    }
                    .frame(width: min(390, max(300, proxy.size.width * 0.30)))

                    Rectangle()
                        .fill(AfterEffectsTheme.border)
                        .frame(width: 1)

                    ZStack {
                        AfterEffectsTheme.background
                        VStack(spacing: 12) {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .font(.system(size: 34, weight: .light))
                                .foregroundStyle(AfterEffectsTheme.secondaryText)
                            Text("Start in the Project panel")
                                .font(.headline)
                                .foregroundStyle(AfterEffectsTheme.primaryText)
                            Text("Create a project, import media, then build a composition in the adaptive iPad workspace.")
                                .font(.caption)
                                .foregroundStyle(AfterEffectsTheme.secondaryText)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 420)
                        }
                        .padding(30)
                    }
                }
            }
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
        guard workspaceMode == .composition else { return }
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
    @State private var zoom: Double = 0.55

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Menu {
                    Button("Fit") { zoom = 0.55 }
                    Button("25%") { zoom = 0.25 }
                    Button("50%") { zoom = 0.50 }
                    Button("100%") { zoom = 1.0 }
                } label: {
                    Text(zoom == 0.55 ? "Fit" : "\(Int(zoom * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }

                Text(workspace.activeComposition?.name ?? "Composition")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                    .lineLimit(1)

                Spacer()

                Text(editorState.playhead.description)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(AfterEffectsTheme.elevatedPanel)

            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        AfterEffectsTheme.viewerBackground
                        if let result = preview.result, let image = UIImage(data: result.image.data) {
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(
                                    width: fittedSize(in: proxy.size).width * zoomScale(in: proxy.size),
                                    height: fittedSize(in: proxy.size).height * zoomScale(in: proxy.size)
                                )
                        } else if preview.isRendering {
                            ProgressView("Rendering")
                                .font(.caption)
                                .tint(AfterEffectsTheme.accent)
                                .foregroundStyle(AfterEffectsTheme.secondaryText)
                        } else {
                            Text("No rendered frame")
                                .font(.caption)
                                .foregroundStyle(AfterEffectsTheme.secondaryText)
                        }
                    }
                    .frame(
                        minWidth: proxy.size.width,
                        minHeight: proxy.size.height,
                        alignment: .center
                    )
                }
                .background(AfterEffectsTheme.viewerBackground)
            }

            if let error = preview.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AfterEffectsTheme.elevatedPanel)
            }
        }
        .background(AfterEffectsTheme.viewerBackground)
    }

    private var previewAspectRatio: CGFloat {
        guard let composition = workspace.activeComposition, composition.height > 0 else { return 16 / 9 }
        return CGFloat(composition.width) / CGFloat(composition.height)
    }

    private func fittedSize(in available: CGSize) -> CGSize {
        let width = max(1, available.width - 28)
        let height = max(1, available.height - 28)
        let availableRatio = width / height
        if availableRatio > previewAspectRatio {
            return CGSize(width: height * previewAspectRatio, height: height)
        }
        return CGSize(width: width, height: width / previewAspectRatio)
    }

    private func zoomScale(in available: CGSize) -> CGFloat {
        if zoom == 0.55 { return 1 }
        return CGFloat(max(0.1, zoom / 0.55))
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
