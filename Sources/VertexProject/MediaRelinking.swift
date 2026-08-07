import Foundation

public struct MediaRelinkCandidate: Codable, Equatable, Sendable {
    public var displayName: String
    public var fileSize: Int64
    public var modificationDate: Date?
    public var fingerprint: String?
    public var locatorToken: String

    public init(
        displayName: String,
        fileSize: Int64,
        modificationDate: Date?,
        fingerprint: String?,
        locatorToken: String
    ) {
        self.displayName = displayName
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.fingerprint = fingerprint
        self.locatorToken = locatorToken
    }
}

public enum MediaRelinkDecision: Equatable, Sendable {
    case automatic(MediaRelinkCandidate)
    case requiresUserSelection([MediaRelinkCandidate])
    case missing
}

public struct MediaRelinker: Sendable {
    public init() {}

    public func decide(
        reference: MediaReference,
        candidates: [MediaRelinkCandidate]
    ) -> MediaRelinkDecision {
        guard !candidates.isEmpty else { return .missing }

        if let expectedFingerprint = normalized(reference.contentFingerprint) {
            let strong = candidates.filter {
                normalized($0.fingerprint) == expectedFingerprint
            }
            if strong.count == 1, let only = strong.first {
                return .automatic(only)
            }
            if strong.count > 1 {
                return .requiresUserSelection(stableSort(strong))
            }
        }

        return .requiresUserSelection(stableSort(candidates))
    }

    private func normalized(_ fingerprint: String?) -> String? {
        guard let fingerprint else { return nil }
        let value = fingerprint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty ? nil : value
    }

    private func stableSort(_ candidates: [MediaRelinkCandidate]) -> [MediaRelinkCandidate] {
        candidates.sorted {
            if $0.locatorToken == $1.locatorToken {
                if $0.displayName == $1.displayName {
                    return $0.fileSize < $1.fileSize
                }
                return $0.displayName < $1.displayName
            }
            return $0.locatorToken < $1.locatorToken
        }
    }
}
