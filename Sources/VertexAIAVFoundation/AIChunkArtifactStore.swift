import Foundation
import VertexAI

struct AIChunkArtifactManifest: Codable, Equatable, Sendable {
    let formatVersion: Int
    let chunkIndex: Int
    let videoFilename: String
    let videoSHA256: String
    let depthFilename: String?
    let depthSHA256: String?
    let frameCount: Int64
}

final class AIChunkArtifactStore: @unchecked Sendable {
    let jobRoot: URL

    init(jobRoot: URL) {
        self.jobRoot = jobRoot
    }

    func videoURL(chunkIndex: Int) -> URL {
        jobRoot.appendingPathComponent(String(format: "chunk-%08d.mov", chunkIndex))
    }

    func depthURL(chunkIndex: Int) -> URL {
        jobRoot.appendingPathComponent(String(format: "chunk-%08d.depthf32", chunkIndex))
    }

    func manifestURL(chunkIndex: Int) -> URL {
        jobRoot.appendingPathComponent(String(format: "chunk-%08d.json", chunkIndex))
    }

    func commit(
        chunkIndex: Int,
        frameCount: Int64,
        hasDepth: Bool
    ) throws -> String {
        try FileManager.default.createDirectory(at: jobRoot, withIntermediateDirectories: true)
        let video = videoURL(chunkIndex: chunkIndex)
        let videoDigest = try AIDigest.sha256(fileAt: video)
        let depth: URL? = hasDepth ? depthURL(chunkIndex: chunkIndex) : nil
        let depthDigest = try depth.map { try AIDigest.sha256(fileAt: $0) }
        let manifest = AIChunkArtifactManifest(
            formatVersion: 1,
            chunkIndex: chunkIndex,
            videoFilename: video.lastPathComponent,
            videoSHA256: videoDigest,
            depthFilename: depth?.lastPathComponent,
            depthSHA256: depthDigest,
            frameCount: frameCount
        )
        let data = try canonicalData(manifest)
        let destination = manifestURL(chunkIndex: chunkIndex)
        try data.write(to: destination, options: .atomic)
        return AIDigest.sha256(data)
    }

    func verify(chunk: AIJobChunk) throws -> Bool {
        guard chunk.state == .completed, let expectedDigest = chunk.artifactDigest else { return false }
        let manifestLocation = manifestURL(chunkIndex: chunk.index)
        guard FileManager.default.fileExists(atPath: manifestLocation.path) else { return false }
        let data = try Data(contentsOf: manifestLocation)
        guard AIDigest.sha256(data) == expectedDigest else { return false }
        let manifest = try JSONDecoder().decode(AIChunkArtifactManifest.self, from: data)
        guard manifest.formatVersion == 1, manifest.chunkIndex == chunk.index,
              manifest.frameCount == chunk.endFrameExclusive - chunk.startFrame else { return false }
        let video = jobRoot.appendingPathComponent(manifest.videoFilename)
        guard FileManager.default.fileExists(atPath: video.path),
              try AIDigest.sha256(fileAt: video) == manifest.videoSHA256 else { return false }
        if let depthFilename = manifest.depthFilename {
            guard let expected = manifest.depthSHA256 else { return false }
            let depth = jobRoot.appendingPathComponent(depthFilename)
            guard FileManager.default.fileExists(atPath: depth.path),
                  try AIDigest.sha256(fileAt: depth) == expected else { return false }
        }
        return true
    }

    func remove(chunkIndex: Int) {
        try? FileManager.default.removeItem(at: videoURL(chunkIndex: chunkIndex))
        try? FileManager.default.removeItem(at: depthURL(chunkIndex: chunkIndex))
        try? FileManager.default.removeItem(at: manifestURL(chunkIndex: chunkIndex))
    }

    func manifests(for job: AIJob) throws -> [AIChunkArtifactManifest] {
        try job.chunks.map { chunk in
            guard chunk.state == .completed,
                  try verify(chunk: chunk) else {
                throw AIError.outputVerificationFailed("Chunk \(chunk.index) is not a verified completed artifact.")
            }
            let data = try Data(contentsOf: manifestURL(chunkIndex: chunk.index))
            return try JSONDecoder().decode(AIChunkArtifactManifest.self, from: data)
        }
    }

    private func canonicalData(_ manifest: AIChunkArtifactManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(manifest)
    }
}
