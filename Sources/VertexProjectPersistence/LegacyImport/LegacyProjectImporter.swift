import Foundation
import VertexCore
import VertexProject

public struct LegacyImportInspection: Equatable, Sendable {
    public let sourceDigest: String
    public let compositionCount: Int
    public let layerCount: Int
    public let mediaCount: Int
    public let embeddedMediaEligibleCount: Int
    public let bookmarkSuccessCount: Int
    public let bookmarkFailureCount: Int
    public let discardedUndoCount: Int
    public let discardedRedoCount: Int
    public let discardedAutosaveCount: Int
    public let validJournalRecordCount: Int
    public let ignoredJournalRecordCount: Int

    public init(
        sourceDigest: String,
        compositionCount: Int,
        layerCount: Int,
        mediaCount: Int,
        embeddedMediaEligibleCount: Int,
        bookmarkSuccessCount: Int,
        bookmarkFailureCount: Int,
        discardedUndoCount: Int,
        discardedRedoCount: Int,
        discardedAutosaveCount: Int,
        validJournalRecordCount: Int,
        ignoredJournalRecordCount: Int
    ) {
        self.sourceDigest = sourceDigest
        self.compositionCount = compositionCount
        self.layerCount = layerCount
        self.mediaCount = mediaCount
        self.embeddedMediaEligibleCount = embeddedMediaEligibleCount
        self.bookmarkSuccessCount = bookmarkSuccessCount
        self.bookmarkFailureCount = bookmarkFailureCount
        self.discardedUndoCount = discardedUndoCount
        self.discardedRedoCount = discardedRedoCount
        self.discardedAutosaveCount = discardedAutosaveCount
        self.validJournalRecordCount = validJournalRecordCount
        self.ignoredJournalRecordCount = ignoredJournalRecordCount
    }
}

public struct LegacyImportResult: Sendable {
    public let destinationURL: URL
    public let snapshot: ProjectPackageSnapshot
    public let inspection: LegacyImportInspection

    public init(destinationURL: URL, snapshot: ProjectPackageSnapshot, inspection: LegacyImportInspection) {
        self.destinationURL = destinationURL
        self.snapshot = snapshot
        self.inspection = inspection
    }
}

private struct LegacyImportContext: Sendable {
    let sourceURL: URL
    let sourceLayout: LegacyProjectPackageLayout
    let sourceDigest: String
    let project: DecodedLegacyProject
    let manifest: LegacyManifestDTO
    let replay: LegacyJournalReadResult
    let discardedUndoCount: Int
    let discardedRedoCount: Int
    let discardedAutosaveCount: Int
    let embeddedSourceURLs: [VertexID: URL]

    var inspection: LegacyImportInspection {
        let bookmarkPayloads = project.bookmarkPayloads
        return LegacyImportInspection(
            sourceDigest: sourceDigest,
            compositionCount: replay.document.compositionRegistry.count,
            layerCount: replay.document.layerRegistry.count,
            mediaCount: replay.document.mediaRegistry.count,
            embeddedMediaEligibleCount: embeddedSourceURLs.count,
            bookmarkSuccessCount: bookmarkPayloads.values.filter { !$0.isEmpty }.count,
            bookmarkFailureCount: bookmarkPayloads.values.filter(\.isEmpty).count,
            discardedUndoCount: discardedUndoCount,
            discardedRedoCount: discardedRedoCount,
            discardedAutosaveCount: discardedAutosaveCount,
            validJournalRecordCount: replay.validJournalRecordCount,
            ignoredJournalRecordCount: replay.ignoredJournalRecordCount
        )
    }
}

public struct LegacyProjectImporter: Sendable {
    public init() {}

    public func inspect(sourceURL: URL) throws -> LegacyImportInspection {
        try loadContext(sourceURL: sourceURL).inspection
    }

    public func convert(sourceURL: URL, destinationURL: URL) throws -> LegacyImportResult {
        let context = try loadContext(sourceURL: sourceURL)
        let destination = try validatedDestination(destinationURL)
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw ProjectPersistenceError.legacyImportIncomplete(stage: "destination already exists")
        }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        let staging = stagingURL(for: destination)
        try? fileManager.removeItem(at: staging)
        var promoted = false
        defer { if !promoted { try? fileManager.removeItem(at: staging) } }

        do {
            var document = try normalizedDocumentForStaging(context)
            let fixedTimestamp = document.metadata.modifiedAt
            let packageStore = VertexProjectPackageStore(fixedTimestamp: fixedTimestamp)
            _ = try packageStore.create(at: staging, document: document)

            let bookmarkStore = BookmarkSidecarStore()
            for (mediaID, payload) in context.project.bookmarkPayloads where !payload.isEmpty {
                try bookmarkStore.write(payload, mediaID: mediaID, in: staging)
            }

            let embeddedStore = EmbeddedMediaStore()
            for (mediaID, sourceMediaURL) in context.embeddedSourceURLs {
                guard let index = document.mediaRegistry.firstIndex(where: { $0.id == mediaID }) else {
                    throw ProjectPersistenceError.legacyImportIncomplete(stage: "embedded media ID missing from canonical registry")
                }
                document.mediaRegistry[index] = try embeddedStore.embed(reference: document.mediaRegistry[index], sourceURL: sourceMediaURL, packageURL: staging)
            }
            document = try document.validated()
            _ = try packageStore.save(document, to: staging)
            try VertexProjectPackageLayout(root: staging).validateAllowlist(mode: .steadyState)

            let digestAfter = try LegacySourceTreeDigest().digest(of: context.sourceURL)
            guard digestAfter == context.sourceDigest else {
                throw ProjectPersistenceError.legacyImportIncomplete(stage: "legacy source changed during conversion")
            }

            let io = DurableFileIO()
            try io.atomicPromote(staging, to: destination)
            try io.synchronizeDirectory(destination.deletingLastPathComponent())
            promoted = true

            let finalResult = try VertexProjectPackageStore().open(at: destination)
            guard case .opened(let snapshot) = finalResult else {
                throw ProjectPersistenceError.legacyImportIncomplete(stage: "converted package requires an unexpected pending decision")
            }
            return LegacyImportResult(destinationURL: destination, snapshot: snapshot, inspection: context.inspection)
        } catch let error as ProjectPersistenceError {
            throw error
        } catch {
            throw ProjectPersistenceError.legacyImportIncomplete(stage: "conversion: \(error.localizedDescription)")
        }
    }

    private func loadContext(sourceURL: URL) throws -> LegacyImportContext {
        let source = sourceURL.standardizedFileURL
        guard source.pathExtension.lowercased() == "aeproject" else {
            throw ProjectPersistenceError.unsupportedPackageExtension(found: source.pathExtension.lowercased())
        }
        let layout = try LegacyProjectPackageLayout(root: source)
        let digest = try LegacySourceTreeDigest().digest(of: source)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: layout.projectURL.path), fileManager.fileExists(atPath: layout.manifestURL.path) else {
            throw ProjectPersistenceError.legacyImportIncomplete(stage: "legacy project or manifest missing")
        }

        let projectData: Data
        let manifestData: Data
        do {
            projectData = try Data(contentsOf: layout.projectURL)
            manifestData = try Data(contentsOf: layout.manifestURL)
        } catch {
            throw ProjectPersistenceError.legacyImportIncomplete(stage: "legacy package read: \(error.localizedDescription)")
        }

        let project = try DecodedLegacyProject.decode(projectData)
        let manifest = try LegacyManifestDTO.decode(manifestData)
        try manifest.validate(project: project, projectData: projectData)
        let journalData = (try? Data(contentsOf: layout.journalURL)) ?? Data()
        let replay = LegacyJournalReader().read(journalData, committedSequence: manifest.committedJournalSequence, document: project.document)

        let historyCounts = readHistoryCounts(at: layout.historyURL)
        let autosaveCount = countFiles(in: layout.autosavesDirectoryURL)
        var embeddedSourceURLs: [VertexID: URL] = [:]
        for reference in project.mediaRegistry {
            guard let relativePath = reference.locator.embeddedPath,
                  let url = try? layout.embeddedMediaURL(relativePath: relativePath),
                  fileManager.fileExists(atPath: url.path) else { continue }
            embeddedSourceURLs[reference.id] = url
        }

        return LegacyImportContext(
            sourceURL: source,
            sourceLayout: layout,
            sourceDigest: digest,
            project: project,
            manifest: manifest,
            replay: replay,
            discardedUndoCount: historyCounts.undo,
            discardedRedoCount: historyCounts.redo,
            discardedAutosaveCount: autosaveCount,
            embeddedSourceURLs: embeddedSourceURLs
        )
    }

    private func normalizedDocumentForStaging(_ context: LegacyImportContext) throws -> ProjectDocument {
        var document = context.replay.document
        let bookmarks = context.project.bookmarkPayloads
        for index in document.mediaRegistry.indices {
            let mediaID = document.mediaRegistry[index].id
            document.mediaRegistry[index].locator = MediaLocator(relativeHint: document.mediaRegistry[index].locator.relativeHint, embeddedPath: nil)
            if context.embeddedSourceURLs[mediaID] != nil {
                document.mediaRegistry[index].availabilityStatus = .external
            } else if let payload = bookmarks[mediaID], !payload.isEmpty {
                document.mediaRegistry[index].availabilityStatus = .external
            } else {
                document.mediaRegistry[index].availabilityStatus = .missing
            }
        }
        return try document.validated()
    }

    private func readHistoryCounts(at url: URL) -> (undo: Int, redo: Int) {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return (0, 0) }
        let undo = (object["undo"] as? [Any])?.count ?? 0
        let redo = (object["redo"] as? [Any])?.count ?? 0
        return (undo, redo)
    }

    private func countFiles(in directory: URL) -> Int {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return 0 }
        return urls.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }.count
    }

    private func validatedDestination(_ url: URL) throws -> URL {
        let standardized = url.standardizedFileURL
        guard standardized.pathExtension.lowercased() == VertexProjectPackageLayout.requiredExtension else {
            throw ProjectPersistenceError.unsupportedPackageExtension(found: standardized.pathExtension.lowercased())
        }
        return standardized
    }

    private func stagingURL(for destination: URL) -> URL {
        destination.deletingLastPathComponent().appendingPathComponent(".\(destination.lastPathComponent).importing").appendingPathExtension(VertexProjectPackageLayout.requiredExtension)
    }
}
