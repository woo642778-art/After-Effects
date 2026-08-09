import SwiftUI
import VertexCore
import VertexProject

enum AERightPanelTab: String, CaseIterable, Identifiable {
    case effectControls = "Effect Controls"
    case preview = "Preview"
    case info = "Info"
    case audio = "Audio"
    case align = "Align"
    case character = "Character"
    case paragraph = "Paragraph"
    var id: String { rawValue }
}

struct AERightPanelStack: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var selectedTab: AERightPanelTab = .effectControls

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(AERightPanelTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 9, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundStyle(selectedTab == tab ? AfterEffectsTheme.primaryText : AfterEffectsTheme.secondaryText)
                                .padding(.horizontal, 8)
                                .frame(height: 28)
                                .background(selectedTab == tab ? AfterEffectsTheme.selection : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(AfterEffectsTheme.elevatedPanel)
            Rectangle().fill(AfterEffectsTheme.border).frame(height: 1)

            Group {
                switch selectedTab {
                case .effectControls:
                    ScrollView { EffectControlsView().padding(5) }
                case .preview:
                    AEPreviewPanel(editorState: editorState)
                case .info:
                    AEInfoPanel(editorState: editorState)
                case .audio:
                    AEAudioPanel()
                case .align:
                    AEAlignPanel()
                case .character:
                    AECapabilityPanel(title: "Character", message: "Character controls require a canonical text layer. Vertex2 does not expose non-functional text controls before that renderer path is implemented.")
                case .paragraph:
                    AECapabilityPanel(title: "Paragraph", message: "Paragraph controls require a canonical text layer. No placeholder paragraph state is stored outside the project model.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AfterEffectsTheme.panel)
    }
}

struct AEPreviewPanel: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var playbackTask: Task<Void, Never>?
    @State private var isPlaying = false
    @State private var loops = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Button { step(-1) } label: { Image(systemName: "backward.frame") }
                Button { togglePlayback() } label: { Image(systemName: isPlaying ? "stop.fill" : "play.fill") }
                Button { step(1) } label: { Image(systemName: "forward.frame") }
                Divider().frame(height: 20)
                Toggle("Loop", isOn: $loops).toggleStyle(.button)
                Spacer()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if let composition = workspace.activeComposition {
                Text("\(editorState.playhead.description)  •  \(composition.frameRate.value)/\(composition.frameRate.timescale) fps")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            Spacer()
        }
        .padding(10)
        .onDisappear { stopPlayback() }
    }

    private func step(_ frames: Int64) {
        guard let composition = workspace.activeComposition else { return }
        let frameRate = composition.frameRate
        guard frameRate.value > 0, frameRate.value <= Int64(Int32.max) else { return }
        let frameDuration = RationalTime(value: Int64(frameRate.timescale), timescale: Int32(frameRate.value))
        do {
            let delta = RationalTime(value: frameDuration.value * frames, timescale: frameDuration.timescale)
            let next = try editorState.playhead.adding(delta)
            editorState.setPlayhead(next, composition: composition)
        } catch { }
    }

    private func togglePlayback() {
        if isPlaying { stopPlayback(); return }
        guard let composition = workspace.activeComposition else { return }
        isPlaying = true
        playbackTask = Task { @MainActor in
            let fps = max(1, composition.frameRate.seconds)
            let interval = Duration.seconds(1 / fps)
            while !Task.isCancelled, isPlaying {
                let before = editorState.playhead
                step(1)
                if editorState.playhead == before || editorState.playhead >= composition.duration {
                    if loops { editorState.setPlayhead(.zero, composition: composition) }
                    else { stopPlayback(); break }
                }
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }
}

struct AEInfoPanel: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            info("Time", editorState.playhead.description)
            if let composition = workspace.activeComposition {
                info("Composition", composition.name)
                info("Size", "\(composition.width) × \(composition.height)")
            }
            if let layer = workspace.selectedLayer {
                Divider().overlay(AfterEffectsTheme.border)
                info("Layer", layer.name)
                info("In / Out", "\(layer.timing.inPoint.description) / \(layer.timing.outPoint.description)")
                info("Opacity", String(format: "%.1f%%", layer.transform.opacity * 100))
                info("Effects", "\(layer.effects.count)")
            }
            Spacer()
        }
        .padding(10)
    }

    private func info(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(AfterEffectsTheme.tertiaryText).frame(width: 74, alignment: .leading)
            Text(value).foregroundStyle(AfterEffectsTheme.primaryText).textSelection(.enabled)
            Spacer()
        }
        .font(.caption2)
    }
}

struct AEAudioPanel: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let media = workspace.selectedMedia, media.kind == .audio {
                Label(media.displayName, systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.primaryText)
                Text("Audio media is registered in the project. Full level-meter and retimed playback output are enabled only after the Phase 11 audio provider is active.")
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            } else {
                Text("Select an audio media item or an audio-backed layer.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            Spacer()
        }
        .padding(10)
    }
}

struct AEAlignPanel: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Align Layers To: Composition")
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            HStack(spacing: 7) {
                alignButton("align.horizontal.left", x: 0, y: nil, help: "Align Left")
                alignButton("align.horizontal.center", x: 0.5, y: nil, help: "Align Horizontal Center")
                alignButton("align.horizontal.right", x: 1, y: nil, help: "Align Right")
            }
            HStack(spacing: 7) {
                alignButton("align.vertical.top", x: nil, y: 0, help: "Align Top")
                alignButton("align.vertical.center", x: nil, y: 0.5, help: "Align Vertical Center")
                alignButton("align.vertical.bottom", x: nil, y: 1, help: "Align Bottom")
            }
            Spacer()
        }
        .padding(10)
    }

    private func alignButton(_ image: String, x: Double?, y: Double?, help: String) -> some View {
        Button {
            guard var transform = workspace.selectedLayer?.transform else { return }
            if let x { transform.positionX = x }
            if let y { transform.positionY = y }
            workspace.setLayerTransform(transform, mergeKey: "align")
        } label: {
            Image(systemName: image).frame(width: 24, height: 24)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(workspace.selectedLayer == nil)
        .help(help)
    }
}

struct AECapabilityPanel: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "info.circle")
                .font(.title3)
                .foregroundStyle(AfterEffectsTheme.tertiaryText)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(AfterEffectsTheme.primaryText)
            Text(message)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
                .padding(.horizontal, 12)
            Spacer()
        }
    }
}
