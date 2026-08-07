import Foundation

public struct ProjectCompatibilityInfo: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var minimumReaderVersion: Int
    public var projectID: String?
    public var projectName: String?
    public var lastSavedByAppVersion: String?

    public init(
        schemaVersion: Int,
        minimumReaderVersion: Int,
        projectID: String?,
        projectName: String?,
        lastSavedByAppVersion: String?
    ) {
        self.schemaVersion = schemaVersion
        self.minimumReaderVersion = minimumReaderVersion
        self.projectID = projectID
        self.projectName = projectName
        self.lastSavedByAppVersion = lastSavedByAppVersion
    }
}

public struct ProjectMigrationReport: Codable, Equatable, Sendable {
    public var sourceVersion: Int
    public var destinationVersion: Int
    public var messages: [String]

    public init(sourceVersion: Int, destinationVersion: Int, messages: [String] = []) {
        self.sourceVersion = sourceVersion
        self.destinationVersion = destinationVersion
        self.messages = messages
    }
}

public struct ProjectMigrationStepResult: Equatable, Sendable {
    public var data: Data
    public var report: ProjectMigrationReport

    public init(data: Data, report: ProjectMigrationReport) {
        self.data = data
        self.report = report
    }
}

public struct ProjectMigrationResult: Equatable, Sendable {
    public var data: Data
    public var reports: [ProjectMigrationReport]

    public init(data: Data, reports: [ProjectMigrationReport]) {
        self.data = data
        self.reports = reports
    }
}

public protocol ProjectMigrator: Sendable {
    var sourceVersion: Int { get }
    var destinationVersion: Int { get }
    func migrate(_ data: Data) throws -> ProjectMigrationStepResult
}

public struct ProjectMigrationRegistry: Sendable {
    public static let current = ProjectMigrationRegistry(migrators: [
        Schema1To2Migrator(),
        Schema2To3Migrator(),
        Schema3To4Migrator()
    ])

    private let migrators: [any ProjectMigrator]

    public init(migrators: [any ProjectMigrator]) {
        self.migrators = migrators.sorted {
            if $0.sourceVersion == $1.sourceVersion {
                return $0.destinationVersion < $1.destinationVersion
            }
            return $0.sourceVersion < $1.sourceVersion
        }
    }

    public func inspect(_ data: Data) throws -> ProjectCompatibilityInfo {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ProjectError.decodingFailure("Project compatibility header could not be read: \(error.localizedDescription)")
        }
        guard let root = object as? [String: Any],
              let schemaVersion = integer(root["schemaVersion"]) else {
            throw ProjectError.decodingFailure("Project schemaVersion is missing or invalid.")
        }
        let minimumReaderVersion = integer(root["minimumReaderVersion"]) ?? schemaVersion
        let metadata = root["metadata"] as? [String: Any]
        return ProjectCompatibilityInfo(
            schemaVersion: schemaVersion,
            minimumReaderVersion: minimumReaderVersion,
            projectID: root["projectID"] as? String,
            projectName: metadata?["name"] as? String,
            lastSavedByAppVersion: metadata?["lastSavedByAppVersion"] as? String
        )
    }

    public func migrate(_ data: Data, from sourceVersion: Int, to destinationVersion: Int) throws -> ProjectMigrationResult {
        guard sourceVersion <= destinationVersion else {
            throw ProjectError.migrationFailure("Project migrations cannot run backwards.")
        }
        if sourceVersion == destinationVersion {
            return ProjectMigrationResult(data: data, reports: [])
        }

        var currentData = data
        var version = sourceVersion
        var reports: [ProjectMigrationReport] = []
        while version < destinationVersion {
            guard let migrator = migrators.first(where: {
                $0.sourceVersion == version && $0.destinationVersion == version + 1
            }) else {
                throw ProjectError.migrationFailure("No deterministic migration exists from schema \(version) to \(version + 1).")
            }
            let result = try migrator.migrate(currentData)
            guard result.report.sourceVersion == version,
                  result.report.destinationVersion == version + 1 else {
                throw ProjectError.migrationFailure("Migrator report did not match its declared version transition.")
            }
            let inspected = try inspect(result.data)
            guard inspected.schemaVersion == version + 1 else {
                throw ProjectError.migrationFailure("Migrated data did not declare schema \(version + 1).")
            }
            currentData = result.data
            reports.append(result.report)
            version += 1
        }
        return ProjectMigrationResult(data: currentData, reports: reports)
    }

    private func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }
}
