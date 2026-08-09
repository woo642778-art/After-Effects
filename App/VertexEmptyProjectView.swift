import SwiftUI
import UniformTypeIdentifiers
import VertexCore
import VertexProject

struct VertexEmptyProjectView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var isNewCompositionPresented = false
    @State private var isMediaImporterPresented = false
    @State private var pendingCompositionID: VertexID?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HStack(spacing: 0) {
                projectPanel
                    .frame(width: 300)
                Rectangle().fill(AfterEffectsTheme.border).frame(width: 1)
                compositionPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Rectangle().fill(AfterEffectsTheme.border).frame(width: 1)
                effectControlsPlaceholder
                    .frame(width: 310)
            }
            .frame(maxHeight: .infinity)
            Rectangle().fill(AfterEffectsTheme.border).frame(height: 1)
            timelinePlaceholder
                .frame(height: 230)
        }
        .background(AfterEffectsTheme.background)
        .sheet(isPresented: $isNewCompositionPresented) {
            NewCompositionView { id in
                pendingCompositionID = id
            }
            .environmentObject(workspace)
        }
        .fileImporter(
            isPresented: $isMediaImporterPresented,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                workspace.registerImportedMedia(from: url)
            }
        }
        .onChange(of: workspace.project?.revision) { _, _ in
            selectPendingCompositionIfAvailable()
        }
        .onChange(of: workspace.project?.activeCompositionID) { _, activeID in
            if activeID == pendingCompositionID {
                pendingCompositionID = nil
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 9) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text("Vertex2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AfterEffectsTheme.primaryText)
            Divider().frame(height: 18).overlay(AfterEffectsTheme.border)
            Text(workspace.project?.metadata.name ?? "Untitled Project")
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
                .lineLimit(1)
            Spacer()
            Button("New Composition") {
                isNewCompositionPresented = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 9)
        .frame(height: 36)
        .background(AfterEffectsTheme.elevatedPanel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AfterEffectsTheme.border).frame(height: 1)
        }
    }

    private var projectPanel: some View {
        AEPanel(title: "Project", systemImage: "folder") {
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AfterEffectsTheme.tertiaryText)
                    Text("Project Items")
                        .font(.caption2)
                        .foregroundStyle(AfterEffectsTheme.tertiaryText)
                    Spacer()
                }
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(AfterEffectsTheme.surface)

                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(workspace.project?.compositionRegistry ?? []) { composition in
                            Button {
                                workspace.selectComposition(composition.id)
                            } label: {
                                projectItemRow(
                                    name: composition.name,
                                    icon: "rectangle.on.rectangle",
                                    detail: "\(composition.width) × \(composition.height)"
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(workspace.project?.mediaRegistry ?? []) { media in
                            Button {
                                workspace.selectMedia(media.id)
                            } label: {
                                projectItemRow(
                                    name: media.displayName,
                                    icon: media.kind == .audio ? "waveform" : "film",
                                    detail: media.kind.rawValue.capitalized
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                HStack(spacing: 8) {
                    Button {
                        isMediaImporterPresented = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Import File")
                    Button {
                        isNewCompositionPresented = true
                    } label: {
                        Image(systemName: "rectangle.stack.badge.plus")
                    }
                    .help("New Composition")
                    Spacer()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(AfterEffectsTheme.elevatedPanel)
                .overlay(alignment: .top) {
                    Rectangle().fill(AfterEffectsTheme.border).frame(height: 1)
                }
            }
        }
    }

    private var compositionPanel: some View {
        AEPanel(title: "Composition", systemImage: "rectangle.on.rectangle") {
            ZStack {
                AfterEffectsTheme.viewerBackground
                VStack(spacing: 14) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                    Text("Create a new composition")
                        .font(.headline)
                        .foregroundStyle(AfterEffectsTheme.primaryText)
                    HStack(spacing: 9) {
                        Button("New Composition") {
                            isNewCompositionPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AfterEffectsTheme.accent)

                        Button("Import Footage") {
                            isMediaImporterPresented = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var effectControlsPlaceholder: some View {
        AEPanel(title: "Effect Controls", systemImage: "slider.horizontal.3") {
            VStack(spacing: 9) {
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
                Text("No layer selected")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                Spacer()
            }
        }
    }

    private var timelinePlaceholder: some View {
        AEPanel(title: "Timeline", systemImage: "timeline.selection") {
            VStack(spacing: 7) {
                Spacer()
                Text("No active composition")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                Text("Create or select a composition to begin editing.")
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
                Spacer()
            }
        }
    }

    private func projectItemRow(name: String, icon: String, detail: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
                .frame(width: 18)
            Text(name)
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.primaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.tertiaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 27)
        .contentShape(Rectangle())
    }

    private func selectPendingCompositionIfAvailable() {
        guard let pendingCompositionID,
              workspace.project?.composition(id: pendingCompositionID) != nil,
              workspace.project?.activeCompositionID != pendingCompositionID else { return }
        workspace.selectComposition(pendingCompositionID)
    }
}
