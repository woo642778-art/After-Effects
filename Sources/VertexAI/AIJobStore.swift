import Foundation

public actor AIJobStore {
    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public func save(_ job: AIJob) throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .throw
        let data: Data
        do {
            data = try encoder.encode(job)
        } catch {
            throw AIError.invalidJobState("AI job could not be encoded: \(error.localizedDescription)")
        }

        let destination = url(for: job.id)
        let temporary = rootURL.appendingPathComponent(".\(job.id).\(UUID().uuidString).tmp")
        do {
            try data.write(to: temporary, options: .atomic)
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: destination)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw AIError.invalidJobState("AI job checkpoint could not be written: \(error.localizedDescription)")
        }
    }

    public func load(identity: AIJobIdentity) throws -> AIJob? {
        let location = url(for: identity.digest)
        guard FileManager.default.fileExists(atPath: location.path) else { return nil }
        let data: Data
        do {
            data = try Data(contentsOf: location)
        } catch {
            throw AIError.invalidJobState("AI job checkpoint could not be read: \(error.localizedDescription)")
        }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .throw
        let stored: AIJob
        do {
            stored = try decoder.decode(AIJob.self, from: data)
        } catch {
            throw AIError.invalidJobState("AI job checkpoint is corrupt: \(error.localizedDescription)")
        }
        return try stored.resumeCandidate(for: identity)
    }

    public func remove(identity: AIJobIdentity) throws {
        let location = url(for: identity.digest)
        guard FileManager.default.fileExists(atPath: location.path) else { return }
        do {
            try FileManager.default.removeItem(at: location)
        } catch {
            throw AIError.invalidJobState("AI job checkpoint could not be removed: \(error.localizedDescription)")
        }
    }

    public func removeAll() throws {
        guard FileManager.default.fileExists(atPath: rootURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: rootURL)
        } catch {
            throw AIError.invalidJobState("AI job checkpoint directory could not be cleared: \(error.localizedDescription)")
        }
    }

    private func url(for jobID: String) -> URL {
        rootURL.appendingPathComponent(jobID).appendingPathExtension("aijob.json")
    }
}
