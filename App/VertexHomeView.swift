import SwiftUI
import UniformTypeIdentifiers

struct VertexHomeView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @StateObject private var recentProjects = RecentProjectsStore()
    @State private var isProjectImporterPresented = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle()
                .fill(AfterEffectsTheme.border)
                .frame(width: 1)
            recentContent
        }
        .background(AfterEffectsTheme.background)
        .fileImporter(
            isPresented: $isProjectImporterPresented,
            allowedContentTypes: [.vertexProject, .legacyAEProject],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    workspace.openProject(from: url)
                }
            case .failure:
                break
            }
        }
        .onChange(of: workspace.packageURL) { _, _ in
            recordCurrentProjectIfPossible()
        }
        .onChange(of: workspace.project?.metadata.name) { _, _ in
            recordCurrentProjectIfPossible()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Vertex Studio")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AfterEffectsTheme.primaryText)
                    Text("Vertex2 11.0")
                        .font(.caption2)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 26)

            homeSelection

            VStack(spacing: 8) {
                Button {
                    workspace.createProject(named: "Untitled Project")
                } label: {
                    Label("New Project", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button {
                    isProjectImporterPresented = true
                } label: {
                    Label("Open Project", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            .buttonStyle(HomeActionButtonStyle())
            .padding(.horizontal, 12)
            .padding(.top, 18)

            Spacer()

            Text("Vertex Studio")
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.tertiaryText)
                .padding(18)
        }
        .frame(width: 238)
        .background(AfterEffectsTheme.elevatedPanel)
    }

    private var homeSelection: some View {
        HStack(spacing: 10) {
            Image(systemName: "house.fill")
                .frame(width: 18)
            Text("Home")
            Spacer()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(AfterEffectsTheme.primaryText)
        .padding(.horizontal, 18)
        .frame(height: 38)
        .background(AfterEffectsTheme.selection)
    }

    private var recentContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Home")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AfterEffectsTheme.primaryText)
                    Text("Recent Projects")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 18)

            Divider().overlay(AfterEffectsTheme.border)

            Group {
                if recentProjects.records.isEmpty {
                    emptyRecentState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(recentProjects.records) { record in
                                recentRow(record)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            homeStatus
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyRecentState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            Text("No recent projects")
                .font(.headline)
                .foregroundStyle(AfterEffectsTheme.primaryText)
            Text("Create a new project or open an existing .vertexproject package.")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func recentRow(_ record: RecentProjectRecord) -> some View {
        let exists = FileManager.default.fileExists(atPath: record.packageURL.path)
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(AfterEffectsTheme.surface)
                .frame(width: 68, height: 42)
                .overlay {
                    Image(systemName: "rectangle.stack")
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(record.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AfterEffectsTheme.primaryText)
                    .lineLimit(1)
                Text(exists ? record.packageURL.deletingLastPathComponent().path : "Project Not Found")
                    .font(.caption2)
                    .foregroundStyle(exists ? AfterEffectsTheme.secondaryText : Color.orange)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(record.lastOpenedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.tertiaryText)

            if exists {
                Button("Open") {
                    workspace.openProject(from: record.packageURL)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("Remove") {
                    recentProjects.remove(projectID: record.projectID)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
        .background(AfterEffectsTheme.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AfterEffectsTheme.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private var homeStatus: some View {
        switch workspace.status {
        case .idle:
            EmptyView()
        case .running(let operation):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(statusLabel(for: operation))
            }
            .homeStatusStyle()
        case .succeeded(let message):
            Label(message, systemImage: "checkmark.circle")
                .homeStatusStyle()
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .homeStatusStyle()
        case .cancelled:
            Label("Operation cancelled", systemImage: "xmark.circle")
                .homeStatusStyle()
        }
    }

    private func statusLabel(for operation: ProjectWorkspaceViewModel.OperationKind) -> String {
        switch operation {
        case .createProject: "Creating project..."
        case .openProject: "Opening project..."
        case .save: "Saving project..."
        case .autosave: "Creating recovery snapshot..."
        case .legacyInspection: "Inspecting legacy project..."
        case .legacyImport: "Importing legacy project..."
        case .pendingRecovery: "Recovering project..."
        case .mediaImport: "Importing media..."
        case .relink: "Relinking media..."
        case .embed: "Embedding media..."
        case .export: "Preparing project package..."
        case .edit: "Applying edit..."
        case .undo: "Undoing..."
        case .redo: "Redoing..."
        }
    }

    private func recordCurrentProjectIfPossible() {
        guard let project = workspace.project, let packageURL = workspace.packageURL else { return }
        recentProjects.record(
            projectID: project.projectID.rawValue,
            name: project.metadata.name,
            packageURL: packageURL
        )
    }
}

private struct HomeActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundStyle(AfterEffectsTheme.primaryText)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                configuration.isPressed ? AfterEffectsTheme.selection : AfterEffectsTheme.surface,
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
    }
}

private extension View {
    func homeStatusStyle() -> some View {
        self
            .font(.caption2)
            .foregroundStyle(AfterEffectsTheme.secondaryText)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .background(AfterEffectsTheme.elevatedPanel)
            .overlay(alignment: .top) {
                Rectangle().fill(AfterEffectsTheme.border).frame(height: 1)
            }
    }
}
