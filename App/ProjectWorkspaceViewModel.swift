import Foundation
import SwiftUI
import VertexCore
import VertexProject
import VertexProjectPersistence

@MainActor
final class ProjectWorkspaceViewModel: ObservableObject {
    enum OperationKind: String, Equatable, Sendable {
        case createProject
        case openProject
        case save
        case autosave
        case legacyInspection
        case legacyImport
        case pendingRecovery
        case mediaImport
        case relink
        case embed
        case export
        case edit
        case undo
        case redo
    }

    enum OperationState: Equatable {
        case idle
        case running(OperationKind)
        case succeeded(String)
        case failed(String)
        case cancelled
    }

    @Published var projectNameInput = "Untitled Project"
    @Published private(set) var project: ProjectDocument?
    @Published private(set) var packageURL: URL?
    @Published private(set) var status: OperationState = .idle
    @Published private(set) var lastSavedAt: Date?
    @Published private(set) var missingMediaIDs: Set<VertexID> = []
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var hasUnsavedChanges = false
    @Published private(set) var legacyInspection: LegacyImportInspection?
    @Published private(set) var pendingDecision: PendingSnapshotDecisionContext?
    @Published var exportDocument: ProjectPackageFileDocument?

    private let sessionActor = ProjectSessionActor()
    private var legacySourceURL: URL?
    private var autosaveTask: Task<Void, Never>?
    private var commandCountSinceAutosave = 0
    private var publicationGate = PublicationGate()

    var renderSettings: ProjectRenderSettings {
        project?.renderSettings ?? ProjectRenderSettings()
    }

    var revisionText: String {
        guard let project else { return "No project" }
        return "Revision \(project.revision) · Schema \(project.schemaVersion)"
    }

    var selectedMedia: MediaReference? {
        guard let project, let selectedID = project.selectedMediaID else { return nil }
        return project.mediaRegistry.first { $0.id == selectedID }
    }

    func createProject(named name: String? = nil) {
        let token = beginPublishedOperation(.createProject)
        let requested = (name ?? projectNameInput)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        Task { [weak self] in
            guard let self else { return }
            do {
                let projectID = VertexID()
                let url = try self.localPackageURL(for: projectID)
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                let snapshot = try await self.sessionActor.create(
                    name: requested.isEmpty ? "Untitled Project" : requested,
                    packageURL: url
                )
                self.publish(snapshot, token: token, message: "New .vertexproject created")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func renameProject() {
        guard let current = project?.metadata.name else { return }
        let next = projectNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.isEmpty, next != current else { return }
        perform(.renameProject(to: next), mergeKey: nil)
    }

    func openProject(from externalURL: URL) {
        switch externalURL.pathExtension.lowercased() {
        case ProjectDocumentTypes.canonicalExtension:
            openCanonicalProject(from: externalURL)
        case ProjectDocumentTypes.legacyExtension:
            inspectLegacyProject(from: externalURL)
        default:
            status = .failed("Only .vertexproject packages and import-only .aeproject packages are supported.")
        }
    }

    func confirmLegacyImport() {
        guard let sourceURL = legacySourceURL else { return }
        let token = beginPublishedOperation(.legacyImport)

        Task { [weak self] in
            guard let self else { return }
            let hasScope = sourceURL.startAccessingSecurityScopedResource()
            defer { if hasScope { sourceURL.stopAccessingSecurityScopedResource() } }
            do {
                let destination = try self.uniqueImportedPackageURL(
                    baseName: sourceURL.deletingPathExtension().lastPathComponent
                )
                let snapshot = try await self.sessionActor.importLegacy(
                    sourceURL: sourceURL,
                    destinationURL: destination
                )
                self.legacySourceURL = nil
                self.legacyInspection = nil
                self.publish(snapshot, token: token, message: "Legacy project converted non-destructively")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func cancelLegacyImport() {
        _ = publicationGate.begin()
        legacySourceURL = nil
        legacyInspection = nil
        status = .cancelled
    }

    func applyPendingSnapshot() {
        guard let context = pendingDecision else { return }
        let token = beginPublishedOperation(.pendingRecovery)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.applyPendingAndOpen(
                    packageURL: context.packageURL
                )
                self.pendingDecision = nil
                self.publish(snapshot, token: token, message: "Pending snapshot applied")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func discardPendingSnapshot() {
        guard let context = pendingDecision else { return }
        let token = beginPublishedOperation(.pendingRecovery)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.discardPendingAndOpen(
                    packageURL: context.packageURL
                )
                self.pendingDecision = nil
                self.publish(snapshot, token: token, message: "Pending snapshot discarded")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func registerImportedMedia(from url: URL) {
        if project == nil {
            status = .failed("Create or open a project before importing media.")
            return
        }
        let token = beginPublishedOperation(.mediaImport)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.registerExternalMedia(from: url)
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "External media registered")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func setRenderParameter(_ parameter: ProjectRenderParameter, to value: Double) {
        guard project?.renderSettings.value(for: parameter) != value else { return }
        perform(
            .setRenderParameter(parameter, value: value),
            mergeKey: "render.\(parameter.rawValue)"
        )
    }

    func setInverted(_ value: Bool) {
        guard project?.renderSettings.inverted != value else { return }
        perform(
            .setRenderBoolean(.inverted, value: value),
            mergeKey: "render.inverted"
        )
    }

    func setOutputDimensions(width: Int, height: Int) {
        guard let settings = project?.renderSettings,
              settings.outputWidth != width || settings.outputHeight != height else { return }
        perform(
            .setOutputDimensions(width: width, height: height),
            mergeKey: "render.output"
        )
    }

    func undo() {
        let token = beginPublishedOperation(.undo)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.undo()
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "Undo applied")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func redo() {
        let token = beginPublishedOperation(.redo)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.redo()
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "Redo applied")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func saveNow() {
        let token = beginPublishedOperation(.save)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.save()
                self.commandCountSinceAutosave = 0
                self.publish(snapshot, token: token, message: "Project saved atomically")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func prepareExport() {
        let token = beginPublishedOperation(.export)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.save()
                let document = try ProjectPackageFileDocument(packageURL: snapshot.packageURL)
                guard self.publicationGate.accepts(token) else { return }
                self.commandCountSinceAutosave = 0
                self.apply(snapshot)
                self.exportDocument = document
                self.status = .succeeded("Verified project package ready to export")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func embedSelectedMedia() {
        guard let mediaID = selectedMedia?.id else { return }
        let token = beginPublishedOperation(.embed)
        Task { [weak self] in
            guard let self else { return }
            do {
                guard let sourceURL = try await self.sessionActor.resolveExternalMedia(mediaID) else {
                    throw ProjectError.missingMedia("Relink the media before embedding it.")
                }
                let snapshot = try await self.sessionActor.embed(mediaID: mediaID, from: sourceURL)
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "Media embedded and verified")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func relinkSelectedMedia(to url: URL) {
        guard let mediaID = selectedMedia?.id else { return }
        let token = beginPublishedOperation(.relink)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.relink(mediaID: mediaID, to: url)
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "Media bookmark sidecar replaced")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func flushAutosave() {
        autosaveTask?.cancel()
        autosaveTask = nil
        guard project != nil else { return }
        let token = beginPublishedOperation(.autosave)
        Task { [weak self] in
            guard let self else { return }
            do {
                if try await self.sessionActor.autosave(reason: .manualFlush) != nil {
                    self.commandCountSinceAutosave = 0
                    guard self.publicationGate.accepts(token) else { return }
                    self.status = .succeeded("Immutable recovery snapshot created")
                } else if self.publicationGate.accepts(token) {
                    self.status = .succeeded("No new autosave was needed")
                }
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    private func perform(_ payload: ProjectCommandPayload, mergeKey: String?) {
        let token = beginPublishedOperation(.edit)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.apply(payload, mergeKey: mergeKey)
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "Session change applied")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    private func openCanonicalProject(from externalURL: URL) {
        let token = beginPublishedOperation(.openProject)
        Task { [weak self] in
            guard let self else { return }
            let hasScope = externalURL.startAccessingSecurityScopedResource()
            defer { if hasScope { externalURL.stopAccessingSecurityScopedResource() } }
            do {
                let destination = try self.copyCanonicalIntoWorkspace(externalURL)
                switch try await self.sessionActor.openCanonical(packageURL: destination) {
                case .opened(let snapshot):
                    self.publish(snapshot, token: token, message: "Canonical project opened")
                case .pendingDecision(let context):
                    guard self.publicationGate.accepts(token) else { return }
                    self.pendingDecision = context
                    self.status = .succeeded("Pending save needs an explicit recovery decision")
                }
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    private func inspectLegacyProject(from externalURL: URL) {
        let token = beginPublishedOperation(.legacyInspection)
        Task { [weak self] in
            guard let self else { return }
            let hasScope = externalURL.startAccessingSecurityScopedResource()
            defer { if hasScope { externalURL.stopAccessingSecurityScopedResource() } }
            do {
                let inspection = try await self.sessionActor.inspectLegacy(packageURL: externalURL)
                guard self.publicationGate.accepts(token) else { return }
                self.legacySourceURL = externalURL
                self.legacyInspection = inspection
                self.status = .succeeded("Legacy import ready for review")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    private func scheduleAutosaveOrFlush() {
        autosaveTask?.cancel()
        if commandCountSinceAutosave >= 20 {
            autosaveTask = Task { [weak self] in
                guard let self else { return }
                do {
                    if try await self.sessionActor.autosave(reason: .commandThreshold) != nil {
                        self.commandCountSinceAutosave = 0
                    }
                } catch {
                    self.status = .failed(error.localizedDescription)
                }
            }
            return
        }

        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            do {
                if try await self.sessionActor.autosave(reason: .idleDelay) != nil {
                    self.commandCountSinceAutosave = 0
                }
            } catch {
                self.status = .failed(error.localizedDescription)
            }
        }
    }

    private func beginPublishedOperation(_ kind: OperationKind) -> Int {
        let token = publicationGate.begin()
        status = .running(kind)
        return token
    }

    private func publish(
        _ snapshot: ProjectSessionSnapshot,
        token: Int,
        message: String
    ) {
        guard publicationGate.accepts(token) else { return }
        apply(snapshot)
        status = .succeeded(message)
    }

    private func publish(_ error: Error, token: Int) {
        guard publicationGate.accepts(token) else { return }
        status = .failed(error.localizedDescription)
    }

    private func apply(_ snapshot: ProjectSessionSnapshot) {
        project = snapshot.document
        packageURL = snapshot.packageURL
        projectNameInput = snapshot.document.metadata.name
        lastSavedAt = snapshot.lastSavedAt
        missingMediaIDs = snapshot.missingMediaIDs
        canUndo = snapshot.canUndo
        canRedo = snapshot.canRedo
        hasUnsavedChanges = snapshot.hasUnsavedChanges
        pendingDecision = nil
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
            .appendingPathExtension(ProjectDocumentTypes.canonicalExtension)
    }

    private func uniqueImportedPackageURL(baseName: String) throws -> URL {
        let safe = baseName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        return try projectsRootURL()
            .appendingPathComponent("\(safe)-\(UUID().uuidString.lowercased())")
            .appendingPathExtension(ProjectDocumentTypes.canonicalExtension)
    }

    private func copyCanonicalIntoWorkspace(_ sourceURL: URL) throws -> URL {
        let destination = try uniqueImportedPackageURL(
            baseName: sourceURL.deletingPathExtension().lastPathComponent
        )
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }
}
