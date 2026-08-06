import Foundation
import SwiftUI
import VertexCore
import VertexMedia
import VertexProject
import VertexProjectFoundation

private enum ProjectMediaIdentityReader {
    static func makeReference(for url: URL) throws -> MediaReference {
        let hasScope = url.startAccessingSecurityScopedResource()
        defer { if hasScope { url.stopAccessingSecurityScopedResource() } }

        let store = ProjectMediaStore()
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let modificationDate = attributes[.modificationDate] as? Date
        let fingerprint = try store.fingerprint(of: url)
        let bookmark = try? store.createSecurityScopedBookmark(for: url)
        return MediaReference(
            displayName: url.lastPathComponent,
            originalFilename: url.lastPathComponent,
            fileSize: fileSize,
            modificationDate: modificationDate,
            contentFingerprint: fingerprint,
            locator: MediaLocator(relativeHint: url.lastPathComponent, bookmarkData: bookmark),
            kind: .video,
            availabilityStatus: .external
        )
    }
}

@MainActor
final class ProjectWorkspaceViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case ready(String)
        case saving
        case autosaved
        case recoveryRequired
        case failed(String)
    }

    @Published var projectNameInput = "Untitled Project"
    @Published private(set) var project: ProjectDocument?
    @Published private(set) var packageURL: URL?
    @Published private(set) var status: Status = .idle
    @Published private(set) var lastSavedAt: Date?
    @Published private(set) var missingMediaIDs: Set<VertexID> = []
    @Published private(set) var recoveryInspection: ProjectRecoveryInspection?
    @Published var exportDocument: ProjectPackageFileDocument?

    private var historyController: ProjectHistoryController?
    private var journalSequence: UInt64 = 0
    private var uncommittedCommandCount = 0
    private var autosaveTask: Task<Void, Never>?
    private let packageStore = ProjectPackageStore()
    private let autosaveStore = ProjectAutosaveStore()
    private let mediaStore = ProjectMediaStore()

    var canUndo: Bool { historyController?.canUndo == true }
    var canRedo: Bool { historyController?.canRedo == true }
    var renderSettings: ProjectRenderSettings { project?.renderSettings ?? ProjectRenderSettings() }
    var revisionText: String { project.map { "Revision \($0.revision) · Schema \($0.schemaVersion)" } ?? "No project" }

    var selectedMedia: MediaReference? {
        guard let project, let selectedID = project.selectedMediaID else { return nil }
        return project.mediaRegistry.first { $0.id == selectedID }
    }

    func createProject(named name: String? = nil) {
        do {
            let requested = (name ?? projectNameInput).trimmingCharacters(in: .whitespacesAndNewlines)
            let document = try ProjectDocument.makeNew(name: requested.isEmpty ? "Untitled Project" : requested)
            let url = try localPackageURL(for: document.projectID)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            let loaded = try packageStore.create(at: url, document: document)
            try install(loaded, packageURL: url)
            status = .ready("New recoverable project created")
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func renameProject() {
        guard let current = project?.metadata.name else { return }
        let next = projectNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.isEmpty, next != current else { return }
        performDurable(.renameProject(before: current, after: next))
    }

    func openProject(from externalURL: URL) {
        do {
            let hasScope = externalURL.startAccessingSecurityScopedResource()
            defer { if hasScope { externalURL.stopAccessingSecurityScopedResource() } }

            let destination = try projectsRootURL()
                .appendingPathComponent("Imported-\(UUID().uuidString.lowercased())")
                .appendingPathExtension("aeproject")
            try FileManager.default.copyItem(at: externalURL, to: destination)

            do {
                let loaded = try packageStore.load(from: destination)
                try install(loaded, packageURL: destination)
                status = .ready("Project package opened")
            } catch {
                recoveryInspection = try ProjectRecoveryEngine().inspect(packageURL: destination)
                packageURL = destination
                status = .recoveryRequired
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func recover(using candidate: ProjectRecoveryCandidate) {
        guard let inspection = recoveryInspection else { return }
        do {
            let recoveredURL = try ProjectRecoveryEngine().recover(candidate, from: inspection)
            let loaded = try packageStore.load(from: recoveredURL)
            try install(loaded, packageURL: recoveredURL)
            status = .ready("Recovered project opened as a new package")
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func registerImportedMedia(from url: URL) {
        if project == nil { createProject() }
        guard project != nil else { return }
        status = .ready("Analyzing media identity")

        Task { [weak self] in
            guard let self else { return }
            do {
                let reference = try await Task.detached(priority: .utility) {
                    try ProjectMediaIdentityReader.makeReference(for: url)
                }.value
                self.performDurable(.registerMedia(reference))
                if self.project?.mediaRegistry.contains(where: { $0.id == reference.id }) == true {
                    self.performDurable(.selectMedia(before: self.project?.selectedMediaID, after: reference.id))
                }
                self.refreshMediaAvailability()
            } catch {
                self.status = .failed(error.localizedDescription)
            }
        }
    }

    func setRenderParameter(_ parameter: ProjectRenderParameter, to value: Double) {
        guard let old = project?.renderSettings.value(for: parameter), old != value else { return }
        performDurable(
            .setRenderParameter(parameter, before: old, after: value),
            mergeKey: "render.\(parameter.rawValue)"
        )
    }

    func setInverted(_ value: Bool) {
        guard let old = project?.renderSettings.inverted, old != value else { return }
        performDurable(
            .setRenderBoolean(.inverted, before: old, after: value),
            mergeKey: "render.inverted"
        )
    }

    func setOutputDimensions(width: Int, height: Int) {
        guard let settings = project?.renderSettings,
              settings.outputWidth != width || settings.outputHeight != height else { return }
        performDurable(
            .setOutputDimensions(
                beforeWidth: settings.outputWidth,
                beforeHeight: settings.outputHeight,
                afterWidth: width,
                afterHeight: height
            ),
            mergeKey: "render.output"
        )
    }

    func undo() {
        guard let controller = historyController, let packageURL else { return }
        do {
            let transition = try controller.undo()
            let sequence = journalSequence + 1
            try packageStore.appendJournal(
                try ProjectJournalRecord(sequence: sequence, command: transition),
                to: packageURL
            )
            journalSequence = sequence
            publishControllerProject()
            scheduleAutosave()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func redo() {
        guard let controller = historyController, let packageURL else { return }
        do {
            let transition = try controller.redo()
            let sequence = journalSequence + 1
            try packageStore.appendJournal(
                try ProjectJournalRecord(sequence: sequence, command: transition),
                to: packageURL
            )
            journalSequence = sequence
            publishControllerProject()
            scheduleAutosave()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func saveNow() {
        guard let controller = historyController, let packageURL else { return }
        status = .saving
        do {
            let loaded = try packageStore.save(
                controller.project,
                history: controller.snapshot,
                to: packageURL,
                committedJournalSequence: journalSequence
            )
            try install(loaded, packageURL: packageURL)
            status = .ready("Project saved atomically")
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func prepareExport() {
        saveNow()
        guard case .ready = status, let packageURL else { return }
        do {
            exportDocument = try ProjectPackageFileDocument(packageURL: packageURL)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func embedSelectedMedia() {
        guard let reference = selectedMedia, let packageURL else { return }
        do {
            guard let sourceURL = try resolveExternal(reference) else {
                throw ProjectError.missingMedia("The external media must be relinked before embedding.")
            }
            let hasScope = sourceURL.startAccessingSecurityScopedResource()
            defer { if hasScope { sourceURL.stopAccessingSecurityScopedResource() } }
            let embedded = try mediaStore.embed(
                reference: reference,
                sourceURL: sourceURL,
                packageURL: packageURL
            )
            performDurable(.setEmbeddedPath(
                mediaID: reference.id,
                before: reference.locator.embeddedPath,
                after: embedded.locator.embeddedPath
            ))
            refreshMediaAvailability()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func relinkSelectedMedia(to url: URL) {
        guard let reference = selectedMedia else { return }
        do {
            let hasScope = url.startAccessingSecurityScopedResource()
            defer { if hasScope { url.stopAccessingSecurityScopedResource() } }
            let fingerprint = try mediaStore.fingerprint(of: url)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let candidate = MediaRelinkCandidate(
                displayName: url.lastPathComponent,
                fileSize: (attributes[.size] as? NSNumber)?.int64Value ?? 0,
                modificationDate: attributes[.modificationDate] as? Date,
                fingerprint: fingerprint,
                locatorToken: url.lastPathComponent
            )
            guard MediaRelinker().decide(reference: reference, candidates: [candidate]) == .automatic(candidate) else {
                throw ProjectError.relinkMismatch("The selected file does not strongly match the missing media fingerprint.")
            }
            let bookmark = try mediaStore.createSecurityScopedBookmark(for: url)
            let nextLocator = MediaLocator(
                relativeHint: url.lastPathComponent,
                bookmarkData: bookmark,
                embeddedPath: reference.locator.embeddedPath
            )
            performDurable(.relinkMedia(mediaID: reference.id, before: reference.locator, after: nextLocator))
            refreshMediaAvailability()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func flushAutosave() {
        autosaveTask?.cancel()
        performAutosave()
    }

    private func performDurable(_ operation: ProjectOperation, mergeKey: String? = nil) {
        guard let controller = historyController, let packageURL else { return }
        do {
            let record = ProjectCommandRecord(
                project: controller.project,
                operation: operation,
                mergeKey: mergeKey
            )
            _ = try ProjectCommandEngine().apply(record, to: controller.project)
            let sequence = journalSequence + 1
            try packageStore.appendJournal(
                try ProjectJournalRecord(sequence: sequence, command: record),
                to: packageURL
            )
            try controller.perform(record)
            journalSequence = sequence
            uncommittedCommandCount += 1
            publishControllerProject()
            if uncommittedCommandCount >= 20 {
                performAutosave()
            } else {
                scheduleAutosave()
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func publishControllerProject() {
        project = historyController?.project
        if let project { projectNameInput = project.metadata.name }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.performAutosave()
        }
    }

    private func performAutosave() {
        guard let controller = historyController, let packageURL else { return }
        do {
            try autosaveStore.rotate(
                document: controller.project,
                history: controller.snapshot,
                in: packageURL
            )
            uncommittedCommandCount = 0
            status = .autosaved
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func install(_ loaded: ProjectPackageLoadResult, packageURL: URL) throws {
        let pending = loaded.journalAnalysis.validRecords.filter {
            $0.sequence > loaded.manifest.committedJournalSequence
        }
        let replay = try ProjectJournalReplayer().replay(
            pending,
            onto: loaded.document,
            startingAfter: loaded.manifest.committedJournalSequence
        )
        historyController = try ProjectHistoryController(
            project: replay.project,
            snapshot: loaded.history
        )
        project = replay.project
        self.packageURL = packageURL
        journalSequence = replay.lastSequence
        lastSavedAt = loaded.manifest.lastSuccessfulSave
        projectNameInput = replay.project.metadata.name
        uncommittedCommandCount = replay.appliedCount
        recoveryInspection = nil
        refreshMediaAvailability()
    }

    private func refreshMediaAvailability() {
        guard let project, let packageURL else {
            missingMediaIDs = []
            return
        }
        var missing = Set<VertexID>()
        for reference in project.mediaRegistry {
            if (try? mediaStore.resolveEmbedded(reference: reference, packageURL: packageURL)) != nil {
                continue
            }
            do {
                if let external = try resolveExternal(reference),
                   FileManager.default.fileExists(atPath: external.path) {
                    continue
                }
            } catch {
                // A failed bookmark is treated as unavailable and exposed through the relink flow.
            }
            missing.insert(reference.id)
        }
        missingMediaIDs = missing
    }

    private func resolveExternal(_ reference: MediaReference) throws -> URL? {
        guard let bookmark = reference.locator.bookmarkData else { return nil }
        return try mediaStore.resolveSecurityScopedBookmark(bookmark).url
    }

    private func projectsRootURL() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ProjectError.packageCorruption("Application Support directory is unavailable.")
        }
        let root = applicationSupport.appendingPathComponent("After Effects/Projects", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func localPackageURL(for projectID: VertexID) throws -> URL {
        try projectsRootURL()
            .appendingPathComponent(projectID.rawValue)
            .appendingPathExtension("aeproject")
    }
}
