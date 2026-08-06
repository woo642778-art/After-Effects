import Foundation
import VertexComposition
import VertexCore
import VertexMedia
import VertexMediaAVFoundation
import VertexProject
import VertexProjectFoundation

actor CompositionMediaFrameResolver: CompositionFrameResolver {
    private let project: ProjectDocument
    private let packageURL: URL?
    private let mediaStore: ProjectMediaStore

    init(
        project: ProjectDocument,
        packageURL: URL?,
        mediaStore: ProjectMediaStore = ProjectMediaStore()
    ) {
        self.project = project
        self.packageURL = packageURL
        self.mediaStore = mediaStore
    }

    func resolve(
        mediaID: VertexID,
        exactSourceTime: RationalTime,
        targetSize: VertexSize
    ) async throws -> CompositionFrameResolution {
        guard let reference = project.mediaRegistry.first(where: { $0.id == mediaID }) else {
            throw CompositionError.missingMedia(mediaID.rawValue)
        }

        let url: URL
        if let packageURL,
           let embedded = try mediaStore.resolveEmbedded(reference: reference, packageURL: packageURL) {
            url = embedded
        } else if let bookmark = reference.locator.bookmarkData {
            let resolved = try mediaStore.resolveSecurityScopedBookmark(bookmark)
            guard !resolved.isStale else {
                throw CompositionError.missingMedia("\(mediaID.rawValue) bookmark is stale")
            }
            url = resolved.url
        } else {
            throw CompositionError.missingMedia(mediaID.rawValue)
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CompositionError.missingMedia(mediaID.rawValue)
        }
        let hasScope = url.startAccessingSecurityScopedResource()
        defer { if hasScope { url.stopAccessingSecurityScopedResource() } }

        do {
            let request = try VideoFrameRequest(
                time: exactSourceTime,
                targetSize: targetSize,
                tolerance: .exact
            )
            let frame = try await AVFoundationVideoFrameProvider(url: url).frame(
                for: request,
                cancellationToken: MediaCancellationToken()
            )
            return .frame(frame.image)
        } catch MediaError.cancelled {
            throw CompositionError.cancelled
        } catch {
            throw CompositionError.frameResolutionFailed(error.localizedDescription)
        }
    }
}
