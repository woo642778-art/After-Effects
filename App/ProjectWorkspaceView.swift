import SwiftUI
import UniformTypeIdentifiers
import VertexProject
import VertexProjectPersistence

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
                    Text(".vertexproject · atomic snapshot · session Undo")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("SCHEMA \(workspace.project?.schemaVersion ?? ProjectDocument.currentSchemaVersion)")
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
                    Label("Open / Import", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    workspace.saveNow()
                } label: {
                    Label("Save", systemImage: "externaldrive")
                }
                .buttonStyle(.bordered)
                .disabled(workspace.project == nil || !workspace.hasUnsavedChanges)

                Button {
                    workspace.prepareExport()
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
                        .disabled(workspace.missingMediaIDs.contains(media.id))
                    if workspace.missingMediaIDs.contains(media.id) {
                        Button("Relink") { isRelinkImporterPresented = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                    }
                }
            }

            statusView

            if let inspection = workspace.legacyInspection {
                LegacyProjectImportView(
                    inspection: inspection,
                    confirm: workspace.confirmLegacyImport,
                    cancel: workspace.cancelLegacyImport
                )
            }

            if let pending = workspace.pendingDecision {
                pendingDecisionView(pending)
            }
        }
        .afterEffectsCard()
        .fileImporter(
            isPresented: $isProjectImporterPresented,
            allowedContentTypes: [.vertexProject, .legacyAEProject],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { workspace.openProject(from: url) }
            case .failure(let error):
                workspace.cancelLegacyImport()
                _ = error
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
            isPresented: Binding(
                get: { workspace.exportDocument != nil || isProjectExporterPresented },
                set: { isPresented in
                    isProjectExporterPresented = isPresented
                    if !isPresented { workspace.exportDocument = nil }
                }
            ),
            document: workspace.exportDocument,
            contentType: .vertexProject,
            defaultFilename: workspace.project?.metadata.name ?? "Vertex-Project"
        ) { _ in
            workspace.exportDocument = nil
            isProjectExporterPresented = false
        }
        .onChange(of: workspace.exportDocument != nil) { _, isReady in
            isProjectExporterPresented = isReady
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch workspace.status {
        case .idle:
            Text("Create a .vertexproject or import an existing package.")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        case .ready(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        case .saving:
            Label("Writing and verifying a full pending snapshot", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        case .autosaved:
            Label("Immutable recovery snapshot created", systemImage: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        case .legacyImportReady:
            Label("Review the non-destructive legacy conversion below.", systemImage: "doc.badge.arrow.up")
                .font(.caption)
                .foregroundStyle(.orange)
        case .pendingSaveDecision:
            Label("A pending save needs an explicit recovery decision.", systemImage: "exclamationmark.shield.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private func pendingDecisionView(_ context: PendingSnapshotDecisionContext) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PENDING SAVE DECISION")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.orange)
            Text(context.reason.localizedDescription)
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            if let revision = context.pendingRevision {
                Text("Pending revision \(revision)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
            }
            HStack {
                Button("Discard Pending") {
                    workspace.discardPendingSnapshot()
                }
                .buttonStyle(.bordered)

                Button("Apply Pending") {
                    workspace.applyPendingSnapshot()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(context.pendingRevision == nil)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
