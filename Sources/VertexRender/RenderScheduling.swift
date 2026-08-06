import Foundation

public enum RenderBackPressurePolicy: Codable, Equatable, Sendable {
    case latestWins
    case fifo(maxPending: Int)
    case rejectWhenBusy
}

public actor RenderCancellationToken {
    private var cancelled = false

    public init() {}

    public func cancel() {
        cancelled = true
    }

    public func throwIfCancelled() throws {
        if cancelled { throw RenderError.cancelled }
    }

    public var isCancelled: Bool { cancelled }
}

public actor LatestRenderCoordinator {
    private let backend: any RenderBackend
    private var generation: UInt64 = 0
    private var activeToken: RenderCancellationToken?

    public init(backend: any RenderBackend) {
        self.backend = backend
    }

    public func cancelActiveRender() async {
        generation &+= 1
        let token = activeToken
        activeToken = nil
        if let token { await token.cancel() }
    }

    public func renderLatest(_ request: RenderRequest) async throws -> RenderResult {
        generation &+= 1
        let requestGeneration = generation
        let previous = activeToken
        let token = RenderCancellationToken()
        activeToken = token
        if let previous { await previous.cancel() }

        do {
            let result = try await backend.render(request, cancellationToken: token)
            guard generation == requestGeneration, activeToken === token else {
                throw RenderError.staleResult
            }
            activeToken = nil
            return result
        } catch {
            if generation == requestGeneration, activeToken === token {
                activeToken = nil
            }
            throw error
        }
    }
}
