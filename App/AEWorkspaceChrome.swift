import SwiftUI

enum AELeftDockTab: String, CaseIterable, Identifiable {
    case project
    case effects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .project: "Project"
        case .effects: "Effects & Presets"
        }
    }
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

            Rectangle()
                .fill(AfterEffectsTheme.border)
                .frame(height: 1)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .background(AfterEffectsTheme.panel)
        .overlay {
            Rectangle()
                .stroke(AfterEffectsTheme.border, lineWidth: 1)
        }
    }
}

struct AEWorkspaceToolbar: View {
    @ObservedObject var editorState: EditorWorkspaceState
    let widthBand: AEWorkspaceWidthBand
    let onToggleLeftDrawer: () -> Void
    let onToggleRightDrawer: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Vertex2")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AfterEffectsTheme.primaryText)
                .padding(.trailing, 6)

            Divider()
                .frame(height: 20)
                .overlay(AfterEffectsTheme.border)

            toolButton(.selection, icon: "arrow.up.left")
            toolButton(.ripple, icon: "arrow.left.and.right")
            toolButton(.roll, icon: "arrow.left.arrow.right")
            toolButton(.slip, icon: "rectangle.and.hand.point.up.left")
            toolButton(.slide, icon: "rectangle.3.group")

            Divider()
                .frame(height: 20)
                .overlay(AfterEffectsTheme.border)

            Button {
                editorState.snappingEnabled.toggle()
            } label: {
                Image(systemName: editorState.snappingEnabled ? "magnet.fill" : "magnet")
            }
            .buttonStyle(AEToolButtonStyle(isActive: editorState.snappingEnabled))
            .help("Snapping")

            Spacer(minLength: 8)

            if widthBand == .narrow {
                Button(action: onToggleLeftDrawer) {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(AEToolButtonStyle(isActive: editorState.isLeftDrawerPresented))
                .help("Project and Effects")
            }

            Menu {
                ForEach(AEWorkspacePreset.allCases) { preset in
                    Button {
                        editorState.setWorkspace(preset)
                    } label: {
                        Label(preset.title, systemImage: preset.systemImage)
                    }
                    .disabled(preset == .threeD || preset == .export)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: editorState.activeWorkspace.systemImage)
                    Text(editorState.activeWorkspace.title)
                        .lineLimit(1)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AfterEffectsTheme.primaryText)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(AfterEffectsTheme.surface, in: RoundedRectangle(cornerRadius: 5))
            }
            .help("Workspace")

            if widthBand == .narrow {
                Button(action: onToggleRightDrawer) {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(AEToolButtonStyle(isActive: editorState.isRightDrawerPresented))
                .help("Effect Controls")
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 38)
        .background(AfterEffectsTheme.elevatedPanel)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AfterEffectsTheme.border)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func toolButton(_ tool: TimelineTool, icon: String) -> some View {
        Button {
            editorState.activeTool = tool
        } label: {
            Image(systemName: icon)
        }
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
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ProjectWorkspaceView()
                MediaImportView()
            }
            .padding(7)
        }
    }
}

struct AEEffectsPanelContent: View {
    var body: some View {
        ScrollView {
            AIWorkspaceView()
                .padding(7)
        }
    }
}

struct AEEffectControlsPanelContent: View {
    var body: some View {
        ScrollView {
            EffectControlsView()
                .padding(7)
        }
    }
}
