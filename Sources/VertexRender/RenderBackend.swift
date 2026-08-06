import Foundation

public protocol RenderBackend: Sendable {
    func render(
        _ request: RenderRequest,
        cancellationToken: RenderCancellationToken
    ) async throws -> RenderResult
}
