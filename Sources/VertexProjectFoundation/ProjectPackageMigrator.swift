import Foundation
import VertexProject

public struct ProjectPackageMigrationResult: Sendable {
    public var sourcePackageURL: URL
    public var migratedPackageURL: URL
    public var reports: [ProjectMigrationReport]
    public var loadResult: ProjectPackageLoadResult

    public init(
        sourcePackageURL: URL,
        migratedPackageURL: URL,
        reports: [ProjectMigrationReport],
        loadResult: ProjectPackageLoadResult
    ) {
        self.sourcePackageURL = sourcePackageURL
        self.migratedPackageURL = migratedPackageURL
        self.reports = reports
        self.loadResult = loadResult
    }
}

public struct ProjectPackageMigrator {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func migrate(
        schema1PackageURL: URL,
        destinationURL: URL
    ) throws -> ProjectPackageMigrationResult {
        let source = schema1PackageURL.standardizedFileURL
        let destination = destinationURL.standardizedFileURL
        guard source != destination else {
            throw ProjectError.migrationFailure("Schema 1 migration destination must be a different package.")
        }
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw ProjectError.migrationFailure("Migration destination already exists.")
        }

        do {
            let read = try Schema1PackageReader(fileManager: fileManager).read(packageURL: source)
            let recoveredBytes = try Schema1ProjectCodec.encode(read.recovered.document)
            let migration = try ProjectMigrationRegistry.current.migrate(
                recoveredBytes,
                from: 1,
                to: ProjectDocument.currentSchemaVersion
            )
            let document = try DeterministicProjectCodec().decode(migration.data)
            let loaded = try ProjectPackageStore(fileManager: fileManager).create(
                at: destination,
                document: document,
                history: ProjectHistorySnapshot()
            )
            guard loaded.manifest.committedJournalSequence == 0,
                  loaded.history == ProjectHistorySnapshot(),
                  loaded.document.revision == read.recovered.document.revision else {
                throw ProjectError.migrationFailure("Migrated package reset or revision verification failed.")
            }
            return ProjectPackageMigrationResult(
                sourcePackageURL: source,
                migratedPackageURL: destination,
                reports: migration.reports,
                loadResult: loaded
            )
        } catch {
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }
            throw error
        }
    }
}

public enum ProjectPackageOpenResult: Sendable {
    case opened(ProjectPackageLoadResult)
    case migrated(ProjectPackageMigrationResult)
}

public struct ProjectPackageOpeningService {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func open(
        packageURL: URL,
        migrationDestination: () throws -> URL
    ) throws -> ProjectPackageOpenResult {
        let layout = try ProjectPackageLayout(root: packageURL)
        guard fileManager.fileExists(atPath: layout.projectURL.path) else {
            throw ProjectError.packageCorruption("Project package is missing project.json.")
        }
        let data = try Data(contentsOf: layout.projectURL)
        let compatibility = try ProjectMigrationRegistry.current.inspect(data)
        switch compatibility.schemaVersion {
        case ProjectDocument.currentSchemaVersion:
            return .opened(try ProjectPackageStore(fileManager: fileManager).load(from: packageURL))
        case 1:
            return .migrated(try ProjectPackageMigrator(fileManager: fileManager).migrate(
                schema1PackageURL: packageURL,
                destinationURL: migrationDestination()
            ))
        default:
            throw ProjectError.unsupportedSchema(
                found: compatibility.schemaVersion,
                supported: ProjectDocument.currentSchemaVersion
            )
        }
    }
}
