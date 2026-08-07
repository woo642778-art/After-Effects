import Foundation
import Testing
@testable import VertexAI

@Test("Stable AI SHA-256 matches the standard abc vector")
func sha256StandardVector() {
    #expect(
        AIDigest.sha256(Data("abc".utf8)) ==
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    )
}

@Test("Streaming file SHA-256 matches in-memory digest")
func streamingFileDigest() throws {
    let payload = Data((0..<200_000).map { UInt8($0 % 251) })
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("vertex-ai-sha-\(UUID().uuidString).bin")
    defer { try? FileManager.default.removeItem(at: url) }
    try payload.write(to: url)
    #expect(try AIDigest.sha256(fileAt: url) == AIDigest.sha256(payload))
}
