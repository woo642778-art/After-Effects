import Foundation
import Testing
@testable import Vertex

@Test @MainActor func recentProjectsDeduplicateByProjectIdentity() throws {
    let suite = "vertex2.recent-tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = RecentProjectsStore(userDefaults: defaults)
    store.record(
        projectID: "project-1",
        name: "First Name",
        packageURL: URL(fileURLWithPath: "/tmp/project-1.vertexproject"),
        openedAt: Date(timeIntervalSince1970: 10)
    )
    store.record(
        projectID: "project-1",
        name: "Renamed",
        packageURL: URL(fileURLWithPath: "/tmp/project-1-new.vertexproject"),
        openedAt: Date(timeIntervalSince1970: 20)
    )

    #expect(store.records.count == 1)
    #expect(store.records[0].name == "Renamed")
    #expect(store.records[0].packageURL.path == "/tmp/project-1-new.vertexproject")
    #expect(store.records[0].lastOpenedAt == Date(timeIntervalSince1970: 20))
}

@Test @MainActor func recentProjectsPruneMissingPackagesWithoutBlockingHome() throws {
    let suite = "vertex2.recent-tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }

    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("vertex2-recent-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let existing = root.appendingPathComponent("existing.vertexproject", isDirectory: true)
    try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
    let missing = root.appendingPathComponent("missing.vertexproject", isDirectory: true)

    let store = RecentProjectsStore(userDefaults: defaults)
    store.record(projectID: "existing", name: "Existing", packageURL: existing)
    store.record(projectID: "missing", name: "Missing", packageURL: missing)
    store.pruneMissingPackages()

    #expect(store.records.map(\.projectID) == ["existing"])
}

@Test @MainActor func recentProjectsPersistAcrossStoreInstances() throws {
    let suite = "vertex2.recent-tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }

    let url = URL(fileURLWithPath: "/tmp/persist.vertexproject")
    RecentProjectsStore(userDefaults: defaults).record(
        projectID: "persist",
        name: "Persisted",
        packageURL: url,
        openedAt: Date(timeIntervalSince1970: 30)
    )

    let reopened = RecentProjectsStore(userDefaults: defaults)
    #expect(reopened.records.count == 1)
    #expect(reopened.records[0].projectID == "persist")
}
