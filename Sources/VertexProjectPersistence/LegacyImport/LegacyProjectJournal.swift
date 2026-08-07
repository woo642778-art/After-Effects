import Foundation
import VertexCore
import VertexProject

public struct ProjectJournalRecord: Codable, Equatable, Sendable {
    public var sequence: UInt64
    public var command: ProjectCommandRecord
    public var checksum: String

    public init(sequence: UInt64, command: ProjectCommandRecord) throws {
        guard sequence > 0 else {
            throw ProjectError.journalCorruption("Journal sequence must be positive.")
        }
        self.sequence = sequence
        self.command = command
        self.checksum = try Self.computeChecksum(sequence: sequence, command: command)
    }

    public func validated() throws -> Self {
        let actual = try Self.computeChecksum(sequence: sequence, command: command)
        guard checksum == actual else {
            throw ProjectError.checksumMismatch(expected: checksum, actual: actual)
        }
        return self
    }

    private static func computeChecksum(sequence: UInt64, command: ProjectCommandRecord) throws -> String {
        let unsigned = UnsignedProjectJournalRecord(sequence: sequence, command: command)
        let encoder = ProjectJournalCodec.makeEncoder()
        do {
            return StableProjectSHA256.hexDigest(try encoder.encode(unsigned))
        } catch {
            throw ProjectError.deterministicEncodingFailure(
                "Journal checksum payload could not be encoded: \(error.localizedDescription)"
            )
        }
    }

    public static func fixture(sequence: UInt64) throws -> ProjectJournalRecord {
        let projectID = VertexID(rawValue: "50000000-0000-0000-0000-000000000030")
        let commandSuffix = String(format: "%012llu", sequence + 100)
        let command = ProjectCommandRecord(
            commandID: VertexID(rawValue: "50000000-0000-0000-0000-\(commandSuffix)"),
            projectID: projectID,
            baseRevision: sequence - 1,
            timestamp: Date(timeIntervalSince1970: Double(sequence)),
            mergeKey: "fixture.exposure",
            forwardOperation: .setRenderParameter(
                .exposure,
                before: Double(sequence - 1),
                after: Double(sequence)
            ),
            inverseOperation: .setRenderParameter(
                .exposure,
                before: Double(sequence),
                after: Double(sequence - 1)
            )
        )
        return try ProjectJournalRecord(sequence: sequence, command: command)
    }
}

private struct UnsignedProjectJournalRecord: Codable, Sendable {
    var sequence: UInt64
    var command: ProjectCommandRecord
}

public struct ProjectJournalAnalysis: Equatable, Sendable {
    public var validRecords: [ProjectJournalRecord]
    public var discardedTrailingBytes: Int

    public init(validRecords: [ProjectJournalRecord], discardedTrailingBytes: Int) {
        self.validRecords = validRecords
        self.discardedTrailingBytes = discardedTrailingBytes
    }
}

public struct ProjectJournalCodec: Sendable {
    public init() {}

    internal static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        encoder.nonConformingFloatEncodingStrategy = .throw
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        return decoder
    }

    public func encodeLine(_ record: ProjectJournalRecord) throws -> Data {
        let validated = try record.validated()
        do {
            var data = try Self.makeEncoder().encode(validated)
            data.append(0x0A)
            return data
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.deterministicEncodingFailure(
                "Journal record could not be encoded: \(error.localizedDescription)"
            )
        }
    }

    public func encodeLines(_ records: [ProjectJournalRecord]) throws -> Data {
        var result = Data()
        for record in records {
            result.append(try encodeLine(record))
        }
        return result
    }

    public func decodeLine(_ line: Data) throws -> ProjectJournalRecord {
        var payload = line
        while payload.last == 0x0A || payload.last == 0x0D {
            payload.removeLast()
        }
        guard !payload.isEmpty else {
            throw ProjectError.journalCorruption("Journal line must not be empty.")
        }
        do {
            return try Self.makeDecoder().decode(ProjectJournalRecord.self, from: payload).validated()
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.journalCorruption(
                "A complete journal line could not be decoded: \(error.localizedDescription)"
            )
        }
    }

    public func analyze(_ data: Data) throws -> ProjectJournalAnalysis {
        guard !data.isEmpty else {
            return ProjectJournalAnalysis(validRecords: [], discardedTrailingBytes: 0)
        }

        let bytes = [UInt8](data)
        guard let finalNewline = bytes.lastIndex(of: 0x0A) else {
            return ProjectJournalAnalysis(validRecords: [], discardedTrailingBytes: bytes.count)
        }

        let complete = Data(bytes[0...finalNewline])
        let discarded = bytes.count - finalNewline - 1
        var records: [ProjectJournalRecord] = []
        var lineStart = complete.startIndex
        while lineStart < complete.endIndex {
            guard let newline = complete[lineStart...].firstIndex(of: 0x0A) else { break }
            let line = complete[lineStart...newline]
            if line.count > 1 {
                records.append(try decodeLine(Data(line)))
            }
            lineStart = complete.index(after: newline)
        }
        return ProjectJournalAnalysis(validRecords: records, discardedTrailingBytes: discarded)
    }
}

public struct ProjectJournalReplayResult: Equatable, Sendable {
    public var project: ProjectDocument
    public var appliedCount: Int
    public var lastSequence: UInt64

    public init(project: ProjectDocument, appliedCount: Int, lastSequence: UInt64) {
        self.project = project
        self.appliedCount = appliedCount
        self.lastSequence = lastSequence
    }
}

public struct ProjectJournalReplayer: Sendable {
    public init() {}

    public func replay(
        _ records: [ProjectJournalRecord],
        onto document: ProjectDocument,
        startingAfter committedSequence: UInt64 = 0
    ) throws -> ProjectJournalReplayResult {
        var project = try document.validated()
        var expected = committedSequence + 1
        var appliedCount = 0
        var lastSequence = committedSequence
        let engine = ProjectCommandEngine()

        for record in records {
            _ = try record.validated()
            if record.sequence <= committedSequence {
                continue
            }
            guard record.sequence == expected else {
                throw ProjectError.journalGap(expected: expected, actual: record.sequence)
            }
            expected += 1
            lastSequence = record.sequence
            project = try engine.apply(record.command, to: project)
            appliedCount += 1
        }

        return ProjectJournalReplayResult(
            project: project,
            appliedCount: appliedCount,
            lastSequence: lastSequence
        )
    }
}
