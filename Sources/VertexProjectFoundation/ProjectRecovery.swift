import Foundation
import VertexProject

public enum ProjectRecoverySource: String, Codable, CaseIterable, Sendable {
    case current
    case backup
    case autosaveCurrent
    case autosavePrevious
    case hourlyAutosave
}

public struct ProjectRecoveryCandidate: Sendable {
    public var source: ProjectRecoverySource
    public var url: URL
    public var document: ProjectDocument?
    public var history: ProjectHistorySnapshot
    public var isValid: Bool
    public var errorMessage: String?

    public init(
        source: ProjectRecoverySource,
        url: URL,
        document: ProjectDocument?,
        history: ProjectHistorySnapshot = ProjectHistorySnapshot(),
        isValid: Bool,
        errorMessage: String? = nil
    ) {
        self.source = source
        self.url = url
        self.document = document
        self.history = history
        self.isValid = isValid
        self.errorMessage = errorMessage
    }
}

public struct ProjectRecoveryInspection: Sendable {
    public var packageURL: URL
    public var candidates: [ProjectRecoveryCandidate]

    public init(packageURL: URL, candidates: [ProjectRecoveryCandidate]) {
        self.packageURL = packageURL
        self.candidates = candidates
    }

    public var bestCandidate: ProjectRecoveryCandidate? {
        candidates
            .filter { $0.isValid && $0.document != nil }
            .sorted {
                let leftRevision = $0.document?.revision ?? 0
                let rightRevision = $1.document?.revision ?? 0
                if leftRevision == rightRevision {
                    return priority($0.source) > priority($1.source)
                }
                return leftRevision > rightRevision
            }
            .first
    }

    private func priority(_ source: ProjectRecoverySource) -> Int {
        switch source {
        case .current: 5
        case .backup: 4
        case .autosaveCurrent: 3
        case .autosavePrevious: 2
        case .hourlyAutosave: 1
        }
    }
}

public struct ProjectRecoveryEngine {
    private let fileManager: FileManager
    private let codec = DeterministicProjectCodec()

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func inspect(packageURL: URL) throws -> ProjectRecoveryInspection {
        let layout = try ProjectPackageLayout(root: packageURL)
        var candidates: [ProjectRecoveryCandidate] = []
        let packageStore = ProjectPackageStore(fileManager: fileManager)

        do {
            let loaded = try packageStore.load(from: packageURL)
            candidates.append(ProjectRecoveryCandidate(
                source: .current,
                url: layout.projectURL,
                document: loaded.document,
                history: loaded.history,
                isValid: true
            ))
        } catch {
            candidates.append(ProjectRecoveryCandidate(
                source: .current,
                url: layout.projectURL,
                document: nil,
                isValid: false,
                errorMessage: error.localizedDescription
            ))
        }

        if fileManager.fileExists(atPath: layout.projectBackupURL.path) {
            candidates.append(loadRawProjectCandidate(
                source: .backup,
                url: layout.projectBackupURL
            ))
        }

        let autosaveStore = ProjectAutosaveStore(fileManager: fileManager)
        for url in try autosaveStore.snapshotURLs(in: packageURL) {
            let source: ProjectRecoverySource
            switch url.lastPathComponent {
            case "snapshot-current.json": source = .autosaveCurrent
            case "snapshot-previous.json": source = .autosavePrevious
            default: source = .hourlyAutosave
            }
            do {
                let snapshot = try autosaveStore.loadSnapshot(at: url)
                candidates.append(ProjectRecoveryCandidate(
                    source: source,
                    url: url,
                    document: snapshot.document,
                    history: snapshot.history,
                    isValid: true
                ))
            } catch {
                candidates.append(ProjectRecoveryCandidate(
                    source: source,
                    url: url,
                    document: nil,
                    isValid: false,
                    errorMessage: error.localizedDescription
                ))
            }
        }

        return ProjectRecoveryInspection(packageURL: layout.root, candidates: candidates)
    }

    public func recover(
        _ candidate: ProjectRecoveryCandidate,
        from inspection: ProjectRecoveryInspection,
        timestamp: Date = Date()
    ) throws -> URL {
        guard candidate.isValid, let document = candidate.document else {
            throw ProjectError.packageCorruption("The selected recovery candidate is not valid.")
        }

        let sourceURL = inspection.packageURL.standardizedFileURL
        let parent = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let timestampToken = Int64(timestamp.timeIntervalSince1970.rounded(.down))
        let preservationURL = parent
            .appendingPathComponent("\(baseName)-recovery-source-\(timestampToken)")
            .appendingPathExtension("aeproject")
        let recoveredURL = parent
            .appendingPathComponent("\(baseName)-recovered-\(timestampToken)")
            .appendingPathExtension("aeproject")

        do {
            if fileManager.fileExists(atPath: preservationURL.path) {
                try fileManager.removeItem(at: preservationURL)
            }
            if fileManager.fileExists(atPath: recoveredURL.path) {
                try fileManager.removeItem(at: recoveredURL)
            }
            try fileManager.copyItem(at: sourceURL, to: preservationURL)
        } catch {
            throw ProjectError.packageCorruption("The damaged source package could not be preserved before recovery: \(error.localizedDescription)")
        }

        var recoveredDocument = document
        guard recoveredDocument.revision < UInt64.max else {
            throw ProjectError.invalidRevision
        }
        recoveredDocument.revision += 1
        recoveredDocument.metadata.modifiedAt = timestamp
        recoveredDocument.metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion

        _ = try ProjectPackageStore(fileManager: fileManager).create(
            at: recoveredURL,
            document: recoveredDocument,
            history: candidate.history
        )
        try copyEmbeddedMedia(from: sourceURL, to: recoveredURL)
        return recoveredURL
    }

    private func loadRawProjectCandidate(
        source: ProjectRecoverySource,
        url: URL
    ) -> ProjectRecoveryCandidate {
        do {
            let document = try codec.decode(Data(contentsOf: url))
            return ProjectRecoveryCandidate(
                source: source,
                url: url,
                document: document,
                history: ProjectHistorySnapshot(),
                isValid: true
            )
        } catch {
            return ProjectRecoveryCandidate(
                source: source,
                url: url,
                document: nil,
                isValid: false,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func copyEmbeddedMedia(from sourcePackage: URL, to destinationPackage: URL) throws {
        let sourceLayout = try ProjectPackageLayout(root: sourcePackage)
        let destinationLayout = try ProjectPackageLayout(root: destinationPackage)
        guard fileManager.fileExists(atPath: sourceLayout.mediaDirectoryURL.path) else { return }
        let contents = try fileManager.contentsOfDirectory(
            at: sourceLayout.mediaDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for source in contents {
            let destination = destinationLayout.mediaDirectoryURL.appendingPathComponent(source.lastPathComponent)
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.copyItem(at: source, to: destination)
            }
        }
    }
}
