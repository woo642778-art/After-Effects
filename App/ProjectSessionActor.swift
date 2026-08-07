import Foundation
import VertexCore
import VertexProject
import VertexProjectPersistence

enum AutosaveReason: String, Equatable, Sendable {
    case idleDelay
    case commandThreshold
    case background
    case beforeProjectSwitch
    case manualFlush
}

enum CloseDisposition: Equatable, Sendable {
    case saveAndClose
    case discardSessionChanges
    case cancel
}

struct ProjectSessionSnapshot: Equatable, Sendable {
    let document: ProjectDocument
    let packageURL: URL
    let canUndo: Bool
    let canRedo: Bool
    let undoCount: Int
    let redoCount: Int
    let savedRevision: UInt64
    let hasUnsavedChanges: Bool
    let lastSavedAt: Date?
    let missingMediaIDs: Set<VertexID>
}

enum ProjectOpenOutcome: Equatable, Sendable {
    case opened(ProjectSessionSnapshot)
    case pendingDecision(PendingSnapshotDecisionContext)
}

actor ProjectSessionActor {
    private var editingSession: ProjectEditingSession?
    private var packageURL: URL?
    private var lastSavedAt: Date?

    private let packageStore = VertexProjectPackageStore()
    private let autosaveStore = ImmutableAutosaveStore()
    private let bookmarkStore = BookmarkSidecarStore()
    private let embeddedMediaStore = EmbeddedMediaStore()
    private let legacyImporter = LegacyProjectImporter()

    func create(name: String, packageURL: URL) async throws -> ProjectSessionSnapshot {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = try ProjectDocument.makeNew(
            name: trimmed.isEmpty ? "Untitled Project" : trimmed
        )
        let created = try packageStore.create(at: packageURL, document: document)
        try install(created)
        return try currentSnapshot()
    }

    func openCanonical(packageURL: URL) async throws -> ProjectOpenOutcome {
        guard packageURL.pathExtension.lowercased() == ProjectDocumentTypes.canonicalExtension else {
            throw ProjectPersistenceError.unsupportedPackageExtension(
                found: packageURL.pathExtension.lowercased()
            )
        }
        switch try packageStore.open(at: packageURL) {
        case .opened(let snapshot):
            try install(snapshot)
            return .opened(try currentSnapshot())
        case .pendingDecision(let context):
            return .pendingDecision(context)
        }
    }

    func discardPendingAndOpen(packageURL: URL) async throws -> ProjectSessionSnapshot {
        let snapshot = try packageStore.discardPending(in: packageURL)
        try install(snapshot)
        return try currentSnapshot()
    }

    func inspectLegacy(packageURL: URL) async throws -> LegacyImportInspection {
        guard packageURL.pathExtension.lowercased() == ProjectDocumentTypes.legacyExtension else {
            throw ProjectPersistenceError.unsupportedPackageExtension(
                found: packageURL.pathExtension.lowercased()
            )
        }
        return try legacyImporter.inspect(sourceURL: packageURL)
    }

    func importLegacy(
        sourceURL: URL,
        destinationURL: URL
    ) async throws -> ProjectSessionSnapshot {
        let result = try legacyImporter.convert(
            sourceURL: sourceURL,
            destinationURL: destinationURL
        )
        try install(result.snapshot)
        return try currentSnapshot()
    }

    func apply(
        _ payload: ProjectCommandPayload,
        mergeKey: String?
    ) async throws -> ProjectSessionSnapshot {
        var session = try requireSession()
        let request = ProjectCommandRequest(
            projectID: session.document.projectID,
            baseRevision: session.document.revision,
            mergeKey: mergeKey,
            payload: payload
        )
        try session.apply(request)
        editingSession = session
        return try currentSnapshot()
    }

    func setSelectedMedia(_ mediaID: VertexID?) async throws -> ProjectSessionSnapshot {
        var session = try requireSession()
        try session.setSelectedMedia(mediaID)
        editingSession = session
        return try currentSnapshot()
    }

    func undo() async throws -> ProjectSessionSnapshot {
        var session = try requireSession()
        try session.undo()
        editingSession = session
        return try currentSnapshot()
    }

    func redo() async throws -> ProjectSessionSnapshot {
        var session = try requireSession()
        try session.redo()
        editingSession = session
        return try currentSnapshot()
    }

    func save() async throws -> ProjectSessionSnapshot {
        var session = try requireSession()
        guard session.hasUnsavedChanges else {
            return try currentSnapshot()
        }
        let destination = try requirePackageURL()
        let saved = try packageStore.save(session.document, to: destination)
        try session.markSaved(revision: saved.document.revision)
        editingSession = session
        lastSavedAt = saved.manifest.lastSuccessfulSave
        return try currentSnapshot()
    }

    func autosave(reason: AutosaveReason) async throws -> AutosaveRecord? {
        _ = reason
        let session = try requireSession()
        let destination = try requirePackageURL()
        guard session.hasUnsavedChanges else { return nil }
        return try autosaveStore.write(document: session.document, in: destination)
    }

    func registerExternalMedia(from url: URL) async throws -> ProjectSessionSnapshot {
        let hasScope = url.startAccessingSecurityScopedResource()
        defer { if hasScope { url.stopAccessingSecurityScopedResource() } }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fingerprint = try embeddedMediaStore.fingerprint(of: url)
        let reference = MediaReference(
            displayName: url.lastPathComponent,
            originalFilename: url.lastPathComponent,
            fileSize: (attributes[.size] as? NSNumber)?.int64Value ?? 0,
            modificationDate: attributes[.modificationDate] as? Date,
            contentFingerprint: fingerprint,
            locator: MediaLocator(relativeHint: url.lastPathComponent),
            kind: .video,
            availabilityStatus: .external
        )
        let destination = try requirePackageURL()
        let bookmark = try AppleBookmarkAdapter().create(for: url)

        do {
            try bookmarkStore.write(bookmark, mediaID: reference.id, in: destination)
            var session = try requireSession()
            try session.apply(ProjectCommandRequest(
                projectID: session.document.projectID,
                baseRevision: session.document.revision,
                payload: .registerMedia(reference)
            ))
            try session.setSelectedMedia(reference.id)
            editingSession = session
            return try currentSnapshot()
        } catch {
            try? bookmarkStore.remove(mediaID: reference.id, in: destination)
            throw error
        }
    }

    func relink(mediaID: VertexID, to url: URL) async throws -> ProjectSessionSnapshot {
        var session = try requireSession()
        guard let reference = session.document.mediaRegistry.first(where: { $0.id == mediaID }) else {
            throw ProjectError.missingMedia(mediaID.rawValue)
        }

        let hasScope = url.startAccessingSecurityScopedResource()
        defer { if hasScope { url.stopAccessingSecurityScopedResource() } }
        let fingerprint = try embeddedMediaStore.fingerprint(of: url)
        if let expected = reference.contentFingerprint,
           expected.lowercased() != fingerprint {
            throw ProjectError.relinkMismatch("The selected file fingerprint does not match the project media.")
        }

        let destination = try requirePackageURL()
        let previousBookmark = try bookmarkStore.read(mediaID: mediaID, in: destination)
        let nextBookmark = try AppleBookmarkAdapter().create(for: url)
        let nextLocator = MediaLocator(
            relativeHint: url.lastPathComponent,
            embeddedPath: reference.locator.embeddedPath
        )

        do {
            try bookmarkStore.write(nextBookmark, mediaID: mediaID, in: destination)
            try session.apply(ProjectCommandRequest(
                projectID: session.document.projectID,
                baseRevision: session.document.revision,
                payload: .relinkMedia(id: mediaID, locator: nextLocator)
            ))
            editingSession = session
            return try currentSnapshot()
        } catch {
            if let previousBookmark {
                try? bookmarkStore.write(previousBookmark, mediaID: mediaID, in: destination)
            } else {
                try? bookmarkStore.remove(mediaID: mediaID, in: destination)
            }
            throw error
        }
    }

    func embed(mediaID: VertexID, from url: URL) async throws -> ProjectSessionSnapshot {
        var session = try requireSession()
        guard let reference = session.document.mediaRegistry.first(where: { $0.id == mediaID }) else {
            throw ProjectError.missingMedia(mediaID.rawValue)
        }
        let destination = try requirePackageURL()
        let hasScope = url.startAccessingSecurityScopedResource()
        defer { if hasScope { url.stopAccessingSecurityScopedResource() } }

        let embedded = try embeddedMediaStore.embed(
            reference: reference,
            sourceURL: url,
            packageURL: destination
        )
        try session.apply(ProjectCommandRequest(
            projectID: session.document.projectID,
            baseRevision: session.document.revision,
            payload: .setEmbeddedPath(id: mediaID, path: embedded.locator.embeddedPath)
        ))
        editingSession = session
        return try currentSnapshot()
    }

    func resolveExternalMedia(_ mediaID: VertexID) async throws -> URL? {
        let destination = try requirePackageURL()
        return try bookmarkStore.resolveAndRefreshIfNeeded(
            mediaID: mediaID,
            in: destination
        )
    }

    func snapshot() async throws -> ProjectSessionSnapshot {
        try currentSnapshot()
    }

    func close(disposition: CloseDisposition) async throws -> ProjectSessionSnapshot? {
        switch disposition {
        case .cancel:
            return try currentSnapshot()
        case .saveAndClose:
            _ = try await save()
            editingSession = nil
            packageURL = nil
            lastSavedAt = nil
            return nil
        case .discardSessionChanges:
            editingSession = nil
            packageURL = nil
            lastSavedAt = nil
            return nil
        }
    }

    private func install(_ snapshot: ProjectPackageSnapshot) throws {
        editingSession = try ProjectEditingSession(document: snapshot.document)
        packageURL = snapshot.layout.root
        lastSavedAt = snapshot.manifest.lastSuccessfulSave
    }

    private func requireSession() throws -> ProjectEditingSession {
        guard let editingSession else {
            throw ProjectError.invalidOperation("No project editing session is open.")
        }
        return editingSession
    }

    private func requirePackageURL() throws -> URL {
        guard let packageURL else {
            throw ProjectError.invalidOperation("No project package is open.")
        }
        return packageURL
    }

    private func currentSnapshot() throws -> ProjectSessionSnapshot {
        let session = try requireSession()
        let destination = try requirePackageURL()
        return ProjectSessionSnapshot(
            document: session.document,
            packageURL: destination,
            canUndo: session.canUndo,
            canRedo: session.canRedo,
            undoCount: session.undoCount,
            redoCount: session.redoCount,
            savedRevision: session.savedRevision,
            hasUnsavedChanges: session.hasUnsavedChanges,
            lastSavedAt: lastSavedAt,
            missingMediaIDs: missingMediaIDs(
                in: session.document,
                packageURL: destination
            )
        )
    }

    private func missingMediaIDs(
        in document: ProjectDocument,
        packageURL: URL
    ) -> Set<VertexID> {
        var missing = Set<VertexID>()
        for reference in document.mediaRegistry {
            do {
                if let embeddedURL = try embeddedMediaStore.resolve(
                    reference: reference,
                    packageURL: packageURL
                ), FileManager.default.fileExists(atPath: embeddedURL.path) {
                    continue
                }
            } catch {
                // Embedded corruption is isolated to this media reference.
            }

            do {
                if let externalURL = try bookmarkStore.resolveAndRefreshIfNeeded(
                    mediaID: reference.id,
                    in: packageURL
                ), FileManager.default.fileExists(atPath: externalURL.path) {
                    continue
                }
            } catch {
                // Bookmark failure is isolated to this media reference.
            }
            missing.insert(reference.id)
        }
        return missing
    }
}
