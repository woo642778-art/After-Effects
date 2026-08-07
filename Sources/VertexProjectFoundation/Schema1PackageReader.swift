import Foundation
import VertexProject

struct Schema1PackageReadResult: Sendable {
    var layout: ProjectPackageLayout
    var recovered: Schema1RecoveredState
    var manifest: Schema1Manifest
}

struct Schema1PackageReader {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func read(packageURL: URL) throws -> Schema1PackageReadResult {
        let layout = try ProjectPackageLayout(root: packageURL)
        guard fileManager.fileExists(atPath: layout.projectURL.path),
              fileManager.fileExists(atPath: layout.manifestURL.path) else {
            throw ProjectError.packageCorruption("Schema 1 package is missing project.json or manifest.json.")
        }

        let projectData: Data
        let manifestData: Data
        do {
            projectData = try Data(contentsOf: layout.projectURL)
            manifestData = try Data(contentsOf: layout.manifestURL)
        } catch {
            throw ProjectError.packageCorruption("Schema 1 package files could not be read: \(error.localizedDescription)")
        }

        let project = try Schema1ProjectCodec.decode(projectData)
        let manifest = try Schema1ProjectCodec.decodeManifest(manifestData)
        guard manifest.schemaVersion == 1,
              manifest.projectID == project.projectID,
              manifest.projectRevision == project.revision else {
            throw ProjectError.manifestCorruption("Schema 1 manifest identity, schema, or revision does not match project.json.")
        }
        let actualChecksum = StableProjectSHA256.hexDigest(projectData)
        guard manifest.projectChecksum == actualChecksum else {
            throw ProjectError.checksumMismatch(expected: manifest.projectChecksum, actual: actualChecksum)
        }

        let journalData = (try? Data(contentsOf: layout.journalURL)) ?? Data()
        let analysis = try ProjectJournalCodec().analyze(journalData)
        let recovered = try Schema1JournalReplayer().replay(
            analysis.validRecords,
            onto: project,
            startingAfter: manifest.committedJournalSequence
        )
        return Schema1PackageReadResult(layout: layout, recovered: recovered, manifest: manifest)
    }
}
