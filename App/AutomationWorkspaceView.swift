import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import VertexCore
import VertexProject
import VertexTimeline

struct AutomationWorkspaceView: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var renameText = ""
    @State private var commandError: String?
    @State private var isFileImporterPresented = false
    @State private var photoSelection: [PhotosPickerItem] = []

    var body: some View {
        HStack(spacing: 0) {
            commandPanel
                .frame(minWidth: 320, idealWidth: 390, maxWidth: 440)
            Rectangle().fill(AfterEffectsTheme.border).frame(width: 1)
            compatibilityPanel
        }
        .background(AfterEffectsTheme.background)
        .onAppear { synchronizeRename() }
        .onChange(of: workspace.project?.selectedLayerID) { _, _ in synchronizeRename() }
        .onChange(of: photoSelection) { _, items in
            importPhotoSelection(items)
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image, .movie, .video, .audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    workspace.registerImportedMedia(from: url)
                }
                commandError = nil
            case .failure(let error):
                commandError = error.localizedDescription
            }
        }
    }

    private var commandPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader("AUTOMATION / COMMANDS", systemImage: "command")
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    commandGroup("Media Intake") {
                        Button {
                            isFileImporterPresented = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.badge.plus").frame(width: 18)
                                Text("Import Files")
                                Spacer()
                                Text("Multi-select")
                                    .font(.caption2)
                                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                            }
                            .font(.caption)
                            .foregroundStyle(AfterEffectsTheme.primaryText)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(AfterEffectsTheme.elevatedPanel, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .disabled(workspace.project == nil)

                        PhotosPicker(
                            selection: $photoSelection,
                            maxSelectionCount: 50,
                            matching: .any(of: [.images, .videos])
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled").frame(width: 18)
                                Text("Import Photos / Videos")
                                Spacer()
                                Text("File-backed")
                                    .font(.caption2)
                                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                            }
                            .font(.caption)
                            .foregroundStyle(AfterEffectsTheme.primaryText)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(AfterEffectsTheme.elevatedPanel, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .disabled(workspace.project == nil)

                        Button {
                            workspace.addSelectedMediaLayer()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.rectangle.on.rectangle").frame(width: 18)
                                Text("Add Selected Media to Composition")
                                Spacer()
                            }
                            .font(.caption)
                            .foregroundStyle(AfterEffectsTheme.primaryText)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(AfterEffectsTheme.elevatedPanel, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .disabled(workspace.selectedMedia == nil || workspace.activeComposition == nil)
                    }

                    commandGroup("Layer") {
                        commandButton("Duplicate Selected", systemImage: "plus.square.on.square") {
                            workspace.duplicateSelectedLayer()
                        }
                        commandButton("Delete Selected", systemImage: "trash") {
                            workspace.removeSelectedLayer()
                        }
                        commandButton(workspace.selectedLayer?.locked == true ? "Unlock Selected" : "Lock Selected", systemImage: "lock") {
                            guard let layer = workspace.selectedLayer else { return }
                            workspace.setLayerLocked(!layer.locked)
                        }
                    }

                    commandGroup("Timeline") {
                        commandButton("Split at Current Time", systemImage: "scissors") {
                            splitAtCurrentTime()
                        }
                        commandButton("Ripple Delete", systemImage: "arrow.left.and.right") {
                            rippleDelete()
                        }
                    }

                    commandGroup("Rename") {
                        HStack(spacing: 8) {
                            TextField("Layer name", text: $renameText)
                                .textFieldStyle(.roundedBorder)
                            Button("Apply") {
                                workspace.renameSelectedLayer(renameText)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AfterEffectsTheme.accent)
                        }
                        .disabled(workspace.selectedLayer == nil)
                    }

                    commandGroup("Command Launcher") {
                        Text("These commands call the same project/timeline mutation APIs as the editor. They are not UI-only macros.")
                            .font(.caption2)
                            .foregroundStyle(AfterEffectsTheme.secondaryText)
                    }

                    if let commandError {
                        Text(commandError)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(12)
            }
        }
        .background(AfterEffectsTheme.panel)
    }

    private var compatibilityPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader("COMPATIBILITY AUDIT", systemImage: "checklist")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 18) {
                        metric("Indexed", value: EffectCompatibilityAudit.indexedEntryCount)
                        metric("Implemented", value: EffectCompatibilityAudit.implementedCount)
                        metric("Remaining", value: EffectCompatibilityAudit.remainingIndexedCount)
                    }

                    Text("Indexed is the reference-document catalog size, not an implementation claim. Commercial families remain clean-room plans unless a Vertex-native processor exists.")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Implemented in Vertex2 12")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AfterEffectsTheme.primaryText)
                        ForEach(EffectCompatibilityAudit.implementedEffects) { entry in
                            HStack {
                                Text(entry.displayName)
                                    .font(.caption)
                                    .foregroundStyle(AfterEffectsTheme.primaryText)
                                Spacer()
                                statusBadge(entry.status)
                            }
                            .padding(.vertical, 3)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reference families")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AfterEffectsTheme.primaryText)
                        ForEach(EffectCompatibilityAudit.families) { family in
                            HStack {
                                Text(familyName(family.family))
                                    .font(.caption)
                                    .foregroundStyle(AfterEffectsTheme.primaryText)
                                Spacer()
                                Text("\(family.indexedEntryCount)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                                    .frame(minWidth: 46, alignment: .trailing)
                                statusBadge(family.defaultStatus)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                .padding(14)
            }
        }
        .background(AfterEffectsTheme.background)
    }

    @ViewBuilder
    private func commandGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            content()
        }
    }

    private func commandButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).frame(width: 18)
                Text(title)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(AfterEffectsTheme.primaryText)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(AfterEffectsTheme.elevatedPanel, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(workspace.selectedLayer == nil)
    }

    private func panelHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
            Text(title)
                .font(.caption2.weight(.bold))
            Spacer()
        }
        .foregroundStyle(AfterEffectsTheme.secondaryText)
        .padding(.horizontal, 10)
        .frame(height: 31)
        .background(AfterEffectsTheme.elevatedPanel)
        .overlay(alignment: .bottom) { Rectangle().fill(AfterEffectsTheme.border).frame(height: 1) }
    }

    private func metric(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.formatted())
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(AfterEffectsTheme.primaryText)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        }
    }

    private func statusBadge(_ status: EffectCompatibilityStatus) -> some View {
        Text(statusName(status))
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(status == .nativeImplemented || status == .aiImplemented ? AfterEffectsTheme.primaryText : AfterEffectsTheme.secondaryText)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.06), in: Capsule())
    }

    private func splitAtCurrentTime() {
        guard let layer = workspace.selectedLayer, let composition = workspace.activeComposition else { return }
        do {
            try workspace.commitTimelineEdit(.split(layerID: layer.id, at: editorState.playhead), compositionID: composition.id)
            commandError = nil
        } catch {
            commandError = error.localizedDescription
        }
    }

    private func rippleDelete() {
        guard let layer = workspace.selectedLayer, let composition = workspace.activeComposition else { return }
        let affected = workspace.orderedLayers
            .filter { $0.id != layer.id && $0.timing.inPoint >= layer.timing.outPoint }
            .map(\.id)
        do {
            try workspace.commitTimelineEdit(.rippleDelete(layerID: layer.id, affectedLayerIDs: affected), compositionID: composition.id)
            commandError = nil
        } catch {
            commandError = error.localizedDescription
        }
    }

    private func importPhotoSelection(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task { @MainActor in
            do {
                for item in items {
                    guard let media = try await item.loadTransferable(type: PhotoLibraryMediaFile.self) else { continue }
                    workspace.registerImportedMedia(from: media.url)
                }
                photoSelection = []
                commandError = nil
            } catch {
                photoSelection = []
                commandError = error.localizedDescription
            }
        }
    }

    private func synchronizeRename() {
        renameText = workspace.selectedLayer?.name ?? ""
    }

    private func familyName(_ family: EffectCompatibilityFamily) -> String {
        switch family {
        case .adobeDefault: "Adobe Default"
        case .continuum: "Continuum"
        case .sapphire: "Sapphire"
        case .redGiantUniverse: "Red Giant / Universe"
        case .extensions: "Extensions"
        case .scripts: "Scripts"
        case .otherIndexed: "Other Indexed"
        }
    }

    private func statusName(_ status: EffectCompatibilityStatus) -> String {
        switch status {
        case .nativeImplemented: "Native"
        case .aiImplemented: "AI"
        case .cleanRoomPlanned: "Clean-room planned"
        case .workflowExtension: "Workflow"
        case .scriptCommand: "Script"
        case .legacyReference: "Reference"
        case .unsupportedExternal: "External"
        }
    }
}

private struct PhotoLibraryMediaFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .image) { media in
            SentTransferredFile(media.url)
        } importing: { received in
            PhotoLibraryMediaFile(url: try persistentCopy(of: received.file))
        }

        FileRepresentation(contentType: .movie) { media in
            SentTransferredFile(media.url)
        } importing: { received in
            PhotoLibraryMediaFile(url: try persistentCopy(of: received.file))
        }
    }

    private static func persistentCopy(of source: URL) throws -> URL {
        let fileManager = FileManager.default
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport
            .appendingPathComponent("Vertex2", isDirectory: true)
            .appendingPathComponent("PhotoImports", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let ext = source.pathExtension.isEmpty ? "media" : source.pathExtension
        let destination = directory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        try fileManager.copyItem(at: source, to: destination)
        return destination
    }
}
