import SwiftUI
import VertexProject

enum AELeftDockTab: String, CaseIterable, Identifiable {
    case project
    case effects

    var id: String { rawValue }
    var title: String { self == .project ? "Project" : "Effects & Presets" }
}

struct AEPanel<Content: View>: View {
    let title: String
    let systemImage: String?
    let content: Content

    init(title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AfterEffectsTheme.primaryText)
                Spacer(minLength: 8)
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(AfterEffectsTheme.elevatedPanel)

            Rectangle().fill(AfterEffectsTheme.border).frame(height: 1)
            content.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
        }
        .background(AfterEffectsTheme.panel)
        .overlay { Rectangle().stroke(AfterEffectsTheme.border, lineWidth: 1) }
    }
}

struct AEWorkspaceToolbar: View {
    @EnvironmentObject private var focusMusic: FocusMusicPlayer
    @ObservedObject var editorState: EditorWorkspaceState
    @State private var isFocusMusicPresented = false
    let widthBand: AEWorkspaceWidthBand
    let onToggleLeftDrawer: () -> Void
    let onToggleRightDrawer: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Vertex2")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AfterEffectsTheme.primaryText)
                .padding(.trailing, 6)
            Divider().frame(height: 20).overlay(AfterEffectsTheme.border)
            toolButton(.selection, icon: "arrow.up.left")
            toolButton(.ripple, icon: "arrow.left.and.right")
            toolButton(.roll, icon: "arrow.left.arrow.right")
            toolButton(.slip, icon: "rectangle.and.hand.point.up.left")
            toolButton(.slide, icon: "rectangle.3.group")
            Divider().frame(height: 20).overlay(AfterEffectsTheme.border)

            Button { editorState.snappingEnabled.toggle() } label: {
                Image(systemName: editorState.snappingEnabled ? "magnet.fill" : "magnet")
            }
            .buttonStyle(AEToolButtonStyle(isActive: editorState.snappingEnabled))
            .help("Snapping")

            Spacer(minLength: 8)

            if widthBand == .narrow {
                Button(action: onToggleLeftDrawer) { Image(systemName: "sidebar.left") }
                    .buttonStyle(AEToolButtonStyle(isActive: editorState.isLeftDrawerPresented))
                    .help("Project and Effects")
            }

            Button { isFocusMusicPresented.toggle() } label: {
                Image(systemName: focusMusic.isPlaying ? "music.note.list" : "music.note")
            }
            .buttonStyle(AEToolButtonStyle(isActive: focusMusic.isPlaying))
            .help("Focus Music")
            .popover(isPresented: $isFocusMusicPresented, arrowEdge: .top) {
                FocusMusicView()
            }

            Menu {
                ForEach(AEWorkspacePreset.allCases) { preset in
                    Button { editorState.setWorkspace(preset) } label: {
                        Label(preset.title, systemImage: preset.systemImage)
                    }
                    .disabled(preset == .threeD || preset == .export)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: editorState.activeWorkspace.systemImage)
                    Text(editorState.activeWorkspace.title).lineLimit(1)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AfterEffectsTheme.primaryText)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(AfterEffectsTheme.surface, in: RoundedRectangle(cornerRadius: 5))
            }
            .help("Workspace")

            if widthBand == .narrow {
                Button(action: onToggleRightDrawer) { Image(systemName: "sidebar.right") }
                    .buttonStyle(AEToolButtonStyle(isActive: editorState.isRightDrawerPresented))
                    .help("Effect Controls")
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 38)
        .background(AfterEffectsTheme.elevatedPanel)
        .overlay(alignment: .bottom) { Rectangle().fill(AfterEffectsTheme.border).frame(height: 1) }
    }

    @ViewBuilder
    private func toolButton(_ tool: TimelineTool, icon: String) -> some View {
        Button { editorState.activeTool = tool } label: { Image(systemName: icon) }
            .buttonStyle(AEToolButtonStyle(isActive: editorState.activeTool == tool))
            .help(tool.rawValue.capitalized)
    }
}

private struct AEToolButtonStyle: ButtonStyle {
    let isActive: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isActive ? AfterEffectsTheme.accent : AfterEffectsTheme.secondaryText)
            .frame(width: 28, height: 28)
            .background(
                isActive ? AfterEffectsTheme.selection : (configuration.isPressed ? AfterEffectsTheme.surface : Color.clear),
                in: RoundedRectangle(cornerRadius: 5)
            )
    }
}

struct AEProjectPanelContent: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
                TextField("Search Project", text: $query)
                    .textFieldStyle(.plain)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(AfterEffectsTheme.surface)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCompositions) { composition in
                        Button { workspace.selectComposition(composition.id) } label: {
                            projectRow(
                                icon: "rectangle.on.rectangle",
                                name: composition.name,
                                detail: "\(composition.width) × \(composition.height)"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(filteredMedia) { media in
                        Button { workspace.selectMedia(media.id) } label: {
                            projectRow(
                                icon: media.kind == .audio ? "waveform" : "film",
                                name: media.displayName,
                                detail: media.kind.rawValue.capitalized
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 3)
            }

            HStack(spacing: 12) {
                Button(action: workspace.undo) { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!workspace.canUndo)
                Button(action: workspace.redo) { Image(systemName: "arrow.uturn.forward") }
                    .disabled(!workspace.canRedo)
                Spacer()
                Text(workspace.revisionText)
                    .font(.system(size: 8).monospaced())
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AfterEffectsTheme.secondaryText)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(AfterEffectsTheme.elevatedPanel)
            .overlay(alignment: .top) { Rectangle().fill(AfterEffectsTheme.border).frame(height: 1) }
        }
    }

    private var filteredCompositions: [ProjectComposition] {
        let items = workspace.project?.compositionRegistry ?? []
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? items : items.filter { $0.name.lowercased().contains(normalized) }
    }

    private var filteredMedia: [MediaReference] {
        let items = workspace.project?.mediaRegistry ?? []
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? items : items.filter { $0.displayName.lowercased().contains(normalized) }
    }

    private func projectRow(icon: String, name: String, detail: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
                .frame(width: 16)
            Text(name)
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.primaryText)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(detail)
                .font(.system(size: 8))
                .foregroundStyle(AfterEffectsTheme.tertiaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .frame(height: 25)
        .contentShape(Rectangle())
    }
}

struct AEEffectsPanelContent: View {
    var body: some View { EffectsAndPresetsView() }
}

struct AEEffectControlsPanelContent: View {
    var body: some View {
        ScrollView {
            EffectControlsView().padding(5)
        }
    }
}
