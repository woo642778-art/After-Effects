import Foundation
import Testing
import VertexCore
import VertexProject
@testable import VertexProjectPersistence

private let legacyJournalProjectID = VertexID(rawValue: "56000000-0000-0000-0000-000000000001")

private func legacyJournalDocument(name: String = "Legacy Journal") throws -> ProjectDocument {
    try ProjectDocument.makeNew(
        id: legacyJournalProjectID,
        name: name,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

private func renameRecord(
    sequence: UInt64,
    project: ProjectDocument,
    from: String,
    to: String
) throws -> ProjectJournalRecord {
    let command = ProjectCommandRecord(
        project: project,
        commandID: VertexID(rawValue: String(format: "56000000-0000-0000-0000-%012llu", sequence + 100)),
        operation: .renameProject(before: from, after: to),
        timestamp: Date(timeIntervalSince1970: 1_700_000_000 + Double(sequence))
    )
    return try ProjectJournalRecord(sequence: sequence, command: command)
}

private func applied(_ record: ProjectJournalRecord, to project: ProjectDocument) throws -> ProjectDocument {
    try ProjectCommandEngine().apply(record.command, to: project)
}

@Test("Legacy journal starts after committed sequence and applies only contiguous records")
func legacyJournalStartsAfterCommittedSequence() throws {
    let initial = try legacyJournalDocument()
    let first = try renameRecord(sequence: 1, project: initial, from: "Legacy Journal", to: "Name 1")
    let committed = try applied(first, to: initial)
    let second = try renameRecord(sequence: 2, project: committed, from: "Name 1", to: "Name 2")
    let afterSecond = try applied(second, to: committed)
    let third = try renameRecord(sequence: 3, project: afterSecond, from: "Name 2", to: "Name 3")
    let data = try ProjectJournalCodec().encodeLines([first, second, third])

    let result = LegacyJournalReader().read(data, committedSequence: 1, document: committed)

    #expect(result.document.metadata.name == "Name 3")
    #expect(result.document.revision == 3)
    #expect(result.lastSequence == 3)
    #expect(result.validJournalRecordCount == 2)
    #expect(result.ignoredJournalRecordCount == 0)
}

@Test("A truncated final legacy journal line is ignored without losing the valid prefix")
func legacyJournalIgnoresTruncatedTail() throws {
    let initial = try legacyJournalDocument()
    let first = try renameRecord(sequence: 1, project: initial, from: "Legacy Journal", to: "Name 1")
    let afterFirst = try applied(first, to: initial)
    let second = try renameRecord(sequence: 2, project: afterFirst, from: "Name 1", to: "Name 2")
    var data = try ProjectJournalCodec().encodeLine(first)
    let secondLine = try ProjectJournalCodec().encodeLine(second)
    data.append(secondLine.prefix(secondLine.count / 2))

    let result = LegacyJournalReader().read(data, committedSequence: 0, document: initial)

    #expect(result.document.metadata.name == "Name 1")
    #expect(result.lastSequence == 1)
    #expect(result.validJournalRecordCount == 1)
    #expect(result.ignoredJournalRecordCount == 1)
    #expect(result.discardedTrailingBytes > 0)
}

@Test("A sequence gap stops replay and prohibits all later records")
func legacyJournalStopsAtFirstGap() throws {
    let initial = try legacyJournalDocument()
    let first = try renameRecord(sequence: 1, project: initial, from: "Legacy Journal", to: "Name 1")
    let afterFirst = try applied(first, to: initial)
    let gap = try renameRecord(sequence: 3, project: afterFirst, from: "Name 1", to: "Name 3")
    let later = try renameRecord(sequence: 4, project: afterFirst, from: "Name 1", to: "Name 4")
    let data = try ProjectJournalCodec().encodeLines([first, gap, later])

    let result = LegacyJournalReader().read(data, committedSequence: 0, document: initial)

    #expect(result.document.metadata.name == "Name 1")
    #expect(result.lastSequence == 1)
    #expect(result.validJournalRecordCount == 1)
    #expect(result.ignoredJournalRecordCount == 2)
    #expect(result.failureSequence == 3)
}

@Test("Checksum failure stops replay before later valid records")
func legacyJournalStopsAtChecksumFailure() throws {
    let initial = try legacyJournalDocument()
    let first = try renameRecord(sequence: 1, project: initial, from: "Legacy Journal", to: "Name 1")
    let afterFirst = try applied(first, to: initial)
    let second = try renameRecord(sequence: 2, project: afterFirst, from: "Name 1", to: "Name 2")
    let third = try renameRecord(sequence: 3, project: afterFirst, from: "Name 1", to: "Name 3")
    var corrupt = try ProjectJournalCodec().encodeLine(second)
    let marker = Data(second.checksum.utf8)
    let range = try #require(corrupt.range(of: marker))
    corrupt.replaceSubrange(range, with: Data(String(repeating: "0", count: 64).utf8))

    var data = try ProjectJournalCodec().encodeLine(first)
    data.append(corrupt)
    data.append(try ProjectJournalCodec().encodeLine(third))

    let result = LegacyJournalReader().read(data, committedSequence: 0, document: initial)
    #expect(result.document.metadata.name == "Name 1")
    #expect(result.validJournalRecordCount == 1)
    #expect(result.ignoredJournalRecordCount == 2)
    #expect(result.failureSequence == 2)
}

@Test("Unknown commands and invalid transitions stop replay")
func legacyJournalStopsAtUnknownOrInvalidTransition() throws {
    let initial = try legacyJournalDocument()
    let first = try renameRecord(sequence: 1, project: initial, from: "Legacy Journal", to: "Name 1")
    let afterFirst = try applied(first, to: initial)
    let third = try renameRecord(sequence: 3, project: afterFirst, from: "Name 1", to: "Name 3")

    let unknown = Data("{\"sequence\":2,\"command\":{\"unknownCommand\":true},\"checksum\":\"bad\"}\n".utf8)
    var unknownData = try ProjectJournalCodec().encodeLine(first)
    unknownData.append(unknown)
    unknownData.append(try ProjectJournalCodec().encodeLine(third))
    let unknownResult = LegacyJournalReader().read(unknownData, committedSequence: 0, document: initial)
    #expect(unknownResult.validJournalRecordCount == 1)
    #expect(unknownResult.ignoredJournalRecordCount == 2)

    let invalidCommand = ProjectCommandRecord(
        commandID: VertexID(rawValue: "56000000-0000-0000-0000-000000000222"),
        projectID: initial.projectID,
        baseRevision: 0,
        timestamp: Date(timeIntervalSince1970: 1_700_000_002),
        mergeKey: nil,
        forwardOperation: .renameProject(before: initial.metadata.name, after: "Changed"),
        inverseOperation: .renameProject(before: "Wrong", after: initial.metadata.name)
    )
    let invalid = try ProjectJournalRecord(sequence: 1, command: invalidCommand)
    let invalidResult = LegacyJournalReader().read(
        try ProjectJournalCodec().encodeLine(invalid),
        committedSequence: 0,
        document: initial
    )
    #expect(invalidResult.validJournalRecordCount == 0)
    #expect(invalidResult.ignoredJournalRecordCount == 1)
    #expect(invalidResult.failureSequence == 1)
}
