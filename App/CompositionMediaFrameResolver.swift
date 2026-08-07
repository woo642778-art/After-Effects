import Foundation
import VertexComposition
import VertexCore
import VertexMedia
import VertexMediaAVFoundation
import VertexProject
import VertexProjectPersistence

actor CompositionMediaFrameResolver: CompositionFrameResolver {
    private let project: ProjectDocument
    private let packageURL: URL?
    private let embeddedMediaStore: EmbeddedMediaStore
    private let bookmarkStore: BookmarkSidecarStore

    init(
        project: ProjectDocument,
        packageURL: URL?,
        embeddedMediaStore: EmbeddedMediaStore = EmbeddedMediaStore(),
        bookmarkStore: BookmarkSidecarStore = BookmarkSidecarStore()
    ) {
        self.project = project
        self.packageURL = packageURL
        self.embeddedMediaStore = embeddedMediaStore
        self.bookmarkStore = bookmarkStore
    }

    func resolve(
        mediaID: VertexID,
        exactSourceTime: RationalTime,
        targetSize: VertexSize
    ) async throws -> CompositionFrameResolution {
        guard let reference = project.mediaRegistry.first(where: { $0.id == mediaID }) else {
            throw CompositionError.missingMedia(mediaID.rawValue)
        }
        guard let packageURL else {
            throw CompositionError.missingMedia(mediaID.rawValue)
        }

        let url = try resolveURL(reference: reference, packageURL: packageURL)
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
        } catch let error as CompositionError {
            throw error
        } catch {
            throw CompositionError.frameResolutionFailed(error.localizedDescription)
        }
    }

    private func resolveURL(reference: MediaReference, packageURL: URL) throws -> URL {
        do {
            if let embedded = try embeddedMediaStore.resolve(
                reference: reference,
                packageURL: packageURL
            ) {
                return embedded
            }
        } catch {
            // A corrupt embedded copy is isolated to this media item. The sidecar remains a valid fallback.
        }

        do {
            if let external = try bookmarkStore.resolveAndRefreshIfNeeded(
                mediaID: reference.id,
                in: packageURL
            ) {
                return external
            }
        } catch {
            // Bookmark failure is reported as missing media without invalidating the project package.
        }

        throw CompositionError.missingMedia(reference.id.rawValue)
    }
}
