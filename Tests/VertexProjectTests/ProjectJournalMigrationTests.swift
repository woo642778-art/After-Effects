import Foundation
import Testing
@testable import VertexProject
import VertexCore

@Test("Journal records are independently checksummed and replay idempotently")
func journalReplayIsIdempotent() throws {
    let project = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "50000000-0000-0000-0000-000000000030"),
        name: "Journal",
        timestamp: Date(timeIntervalSince1970: 10)
    )
    let command = ProjectCommandRecord.settingExposure(
        project: project,
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000031"),
        from: 0,
        to: 1,
        timestamp: Date(timeIntervalSince1970: 11)
    )
    let record = try ProjectJournalRecord(sequence: 1, command: command)
    let line = try ProjectJournalCodec().encodeLine(record)
    let decoded = try ProjectJournalCodec().decodeLine(line)
    #expect(decoded.checksum == record.checksum)
    let once = try ProjectJournalReplayer().replay([decoded], onto: project)
    let twice = try ProjectJournalReplayer().replay([decoded], onto: once.project)
    #expect(twice.project == once.project)
    #expect(twice.appliedCount == 0)
}

@Test("A corrupt final journal line is excluded but a sequence gap stops replay")
func journalCorruptionRules() throws {
    let valid = try ProjectJournalRecord.fixture(sequence: 1)
    let bytes = try ProjectJournalCodec().encodeLines([valid]) + Data("{truncated".utf8)
    let analysis = try ProjectJournalCodec().analyze(bytes)
    #expect(analysis.validRecords.count == 1)
    #expect(analysis.discardedTrailingBytes > 0)
    #expect(throws: ProjectError.self) {
        try ProjectJournalReplayer().replay(
            [valid, try ProjectJournalRecord.fixture(sequence: 3)],
            onto: ProjectDocument.makeNew(
                id: valid.command.projectID,
                name: "Gap",
                timestamp: Date(timeIntervalSince1970: 1)
            )
        )
    }
}

@Test("Future schemas are inspected but never decoded as writable projects")
func futureSchemaIsNonDestructive() throws {
    let data = Data(#"{"schemaVersion":99,"minimumReaderVersion":99,"projectID":"50000000-0000-0000-0000-000000000001","metadata":{"name":"Future","lastSavedByAppVersion":"99.0.0"}}"#.utf8)
    let info = try ProjectMigrationRegistry.current.inspect(data)
    #expect(info.schemaVersion == 99)
    #expect(info.projectName == "Future")
    #expect(throws: ProjectError.self) { try DeterministicProjectCodec().decode(data) }
}

@Test("Migration registry requires every sequential version link")
func missingMigrationLinkFails() throws {
    let registry = ProjectMigrationRegistry(migrators: [])
    let source = Data(#"{"schemaVersion":0,"minimumReaderVersion":0}"#.utf8)
    #expect(throws: ProjectError.self) {
        try registry.migrate(source, from: 0, to: 1)
    }
}
