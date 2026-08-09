import Foundation
import SwiftUI

struct RecentProjectRecord: Codable, Equatable, Identifiable, Sendable {
    var projectID: String
    var name: String
    var packageURL: URL
    var lastOpenedAt: Date
    var thumbnailPath: String?

    var id: String { projectID }
}

@MainActor
final class RecentProjectsStore: ObservableObject {
    @Published private(set) var records: [RecentProjectRecord]

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let maximumCount: Int

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "vertex2.recentProjects.v1",
        maximumCount: Int = 20
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.maximumCount = max(1, maximumCount)
        self.records = Self.load(from: userDefaults, key: storageKey)
        normalizeAndPersist()
    }

    func record(
        projectID: String,
        name: String,
        packageURL: URL,
        openedAt: Date = Date(),
        thumbnailPath: String? = nil
    ) {
        let trimmedID = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty, !trimmedName.isEmpty else { return }

        records.removeAll { $0.projectID == trimmedID }
        records.append(RecentProjectRecord(
            projectID: trimmedID,
            name: trimmedName,
            packageURL: packageURL.standardizedFileURL,
            lastOpenedAt: openedAt,
            thumbnailPath: thumbnailPath
        ))
        normalizeAndPersist()
    }

    func remove(projectID: String) {
        records.removeAll { $0.projectID == projectID }
        persist()
    }

    func pruneMissingPackages(fileManager: FileManager = .default) {
        records.removeAll { !fileManager.fileExists(atPath: $0.packageURL.path) }
        normalizeAndPersist()
    }

    private func normalizeAndPersist() {
        records.sort {
            if $0.lastOpenedAt != $1.lastOpenedAt {
                return $0.lastOpenedAt > $1.lastOpenedAt
            }
            return $0.projectID < $1.projectID
        }
        if records.count > maximumCount {
            records.removeLast(records.count - maximumCount)
        }
        persist()
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            userDefaults.set(try encoder.encode(records), forKey: storageKey)
        } catch {
            userDefaults.removeObject(forKey: storageKey)
        }
    }

    private static func load(from userDefaults: UserDefaults, key: String) -> [RecentProjectRecord] {
        guard let data = userDefaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RecentProjectRecord].self, from: data)) ?? []
    }
}
