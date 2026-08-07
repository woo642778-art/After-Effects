import Foundation

public enum AIDigest {
    public static func sha256(_ data: Data) -> String {
        StableAISHA256.hexDigest(data)
    }

    public static func sha256(fileAt url: URL) throws -> String {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw AIError.outputVerificationFailed("Could not open file for SHA-256: \(error.localizedDescription)")
        }
        defer { try? handle.close() }
        var data = Data()
        do {
            while true {
                let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
                if chunk.isEmpty { break }
                data.append(chunk)
            }
        } catch {
            throw AIError.outputVerificationFailed("Could not read file for SHA-256: \(error.localizedDescription)")
        }
        return StableAISHA256.hexDigest(data)
    }
}
