import SwiftUI
import UniformTypeIdentifiers
import VertexProject

struct ProjectWorkspaceView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var isProjectImporterPresented = false
    @State private var isProjectExporterPresented = false
    @State private var isRelinkImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROJECT PERSISTENCE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AfterEffectsTheme.accent)
                        .tracking(0.8)
                    Text("Atomic saves · journal · recovery")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("SCHEMA 1")
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }

            HStack(spacing: 8) {
                TextField("Project name", text: $workspace.projectNameInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { workspace.renameProject() }

                Button(workspace.project == nil ? "Create" : "Rename") {
                    if workspace.project == nil {
                        workspace.createProject()
                    } else {
                        workspace.renameProject()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AfterEffectsTheme.accent)
            }

            HStack(spacing: 8) {
                Button {
                    isProjectImporterPresented = true
                } label: {
                    Label("Open", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    workspace.saveNow()
                } label: {
                    Label("Save", systemImage: "externaldrive")
                }
                .buttonStyle(.bordered)
                .disabled(workspace.project == nil)

                Button {
                    workspace.prepareExport()
                    isProjectExporterPresented = workspace.exportDocument != nil
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(workspace.project == nil)
            }
            .tint(AfterEffectsTheme.accent)

            HStack(spacing: 8) {
                Button {
                    workspace.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!workspace.canUndo)

                Button {
                    workspace.redo()
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .disabled(!workspace.canRedo)

                Spacer()

                Text(workspace.revisionText)
                    .font(.caption.monospaced())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            .buttonStyle(.bordered)
            .tint(AfterEffectsTheme.accent)

            if let media = workspace.selectedMedia {
                Divider().overlay(Color.white.opacity(0.10))
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(media.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(media.availabilityStatus.rawValue.uppercased())
                            .font(.caption2.monospaced().weight(.bold))
                            .foregroundStyle(
                                workspace.missingMediaIDs.contains(media.id)
                                    ? Color.orange
                                    : AfterEffectsTheme.accent
                            )
                    }
                    Spacer()
                    Button("Embed") { workspace.embedSelectedMedia() }
                        .buttonStyle(.bordered)
                    if workspace.missingMediaIDs.contains(media.id) {
                        Button("Relink") { isRelinkImporterPresented = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                    }
                }
            }

            statusView

            if let inspection = workspace.recoveryInspection {
                recoveryChoices(inspection)
            }
        }
        .afterEffectsCard()
        .fileImporter(
            isPresented: $isProjectImporterPresented,
            allowedContentTypes: [.afterEffectsProject, .package],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { workspace.openProject(from: url) }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError {
                    workspace.projectNameInput = workspace.projectNameInput
                }
            }
        }
        .fileImporter(
            isPresented: $isRelinkImporterPresented,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                workspace.relinkSelectedMedia(to: url)
            }
        }
        .fileExporter(
            isPresented: $isProjectExporterPresented,
            document: workspace.exportDocument,
            contentType: .afterEffectsProject,
            defaultFilename: workspace.project?.metadata.name ?? "After-Effects-Project"
        ) { _ in
            workspace.exportDocument = nil
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch workspace.status {
        case .idle:
            Text("Create or open a project package before editing persistent settings.")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        case .ready(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        case .saving:
            Label("Writing temporary files and verifying checksums", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        case .autosaved:
            Label("Recovery snapshot updated", systemImage: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        case .recoveryRequired:
            Label("The current project is damaged. Select a verified recovery candidate.", systemImage: "exclamationmark.shield.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private func recoveryChoices(_ inspection: ProjectRecoveryInspection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECOVERY CANDIDATES")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.orange)
            ForEach(Array(inspection.candidates.enumerated()), id: \.offset) { _, candidate in
                Button {
                    workspace.recover(using: candidate)
                } label: {
                    HStack {
                        Image(systemName: candidate.isValid ? "checkmark.shield" : "xmark.shield")
                        Text(candidate.source.rawValue)
                        Spacer()
                        Text(candidate.document.map { "r\($0.revision)" } ?? "invalid")
                            .font(.caption.monospaced())
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!candidate.isValid)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
