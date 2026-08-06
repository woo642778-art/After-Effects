import Foundation
import VertexProject

package struct LegacyJournalReadResult: Equatable, Sendable {
    package let document: ProjectDocument
    package let lastSequence: UInt64
    package let validJournalRecordCount: Int
    package let ignoredJournalRecordCount: Int
    package let discardedTrailingBytes: Int
    package let failureSequence: UInt64?
}

package struct LegacyJournalReader: Sendable {
    package init() {}

    package func read(
        _ data: Data,
        committedSequence: UInt64,
        document: ProjectDocument
    ) -> LegacyJournalReadResult {
        let split = splitCompleteLines(data)
        var current: ProjectDocument
        do {
            current = try document.validated()
        } catch {
            return LegacyJournalReadResult(
                document: document,
                lastSequence: committedSequence,
                validJournalRecordCount: 0,
                ignoredJournalRecordCount: split.completeLines.count + (split.trailingBytes > 0 ? 1 : 0),
                discardedTrailingBytes: split.trailingBytes,
                failureSequence: nil
            )
        }

        var expected = committedSequence == UInt64.max ? UInt64.max : committedSequence + 1
        var lastSequence = committedSequence
        var appliedCount = 0
        var failureSequence: UInt64?
        var failureIndex: Int?
        let codec = ProjectJournalCodec()
        let engine = ProjectCommandEngine()

        for (index, line) in split.completeLines.enumerated() {
            let record: ProjectJournalRecord
            do {
                record = try codec.decodeLine(line)
            } catch {
                failureSequence = bestEffortSequence(in: line)
                failureIndex = index
                break
            }

            if record.sequence <= committedSequence {
                continue
            }
            guard expected != UInt64.max,
                  record.sequence == expected else {
                failureSequence = record.sequence
                failureIndex = index
                break
            }

            do {
                current = try engine.apply(record.command, to: current)
            } catch {
                failureSequence = record.sequence
                failureIndex = index
                break
            }
            appliedCount += 1
            lastSequence = record.sequence
            expected = record.sequence == UInt64.max ? UInt64.max : record.sequence + 1
        }

        let ignoredComplete: Int
        if let failureIndex {
            ignoredComplete = split.completeLines.count - failureIndex
        } else {
            ignoredComplete = 0
        }
        let ignoredTrailing = split.trailingBytes > 0 ? 1 : 0

        return LegacyJournalReadResult(
            document: current,
            lastSequence: lastSequence,
            validJournalRecordCount: appliedCount,
            ignoredJournalRecordCount: ignoredComplete + ignoredTrailing,
            discardedTrailingBytes: split.trailingBytes,
            failureSequence: failureSequence
        )
    }

    private func splitCompleteLines(_ data: Data) -> (completeLines: [Data], trailingBytes: Int) {
        guard !data.isEmpty else { return ([], 0) }
        let bytes = [UInt8](data)
        var lines: [Data] = []
        var start = 0
        for index in bytes.indices where bytes[index] == 0x0A {
            lines.append(Data(bytes[start...index]))
            start = index + 1
        }
        return (lines, bytes.count - start)
    }

    private func bestEffortSequence(in line: Data) -> UInt64? {
        var payload = line
        while payload.last == 0x0A || payload.last == 0x0D {
            payload.removeLast()
        }
        guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let number = object["sequence"] as? NSNumber else {
            return nil
        }
        return number.uint64Value
    }
}
