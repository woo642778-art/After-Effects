import Foundation
import Testing
import VertexCore
import VertexMedia
@testable import VertexRender

private actor DelayedRenderBackend: RenderBackend {
    func render(
        _ request: RenderRequest,
        cancellationToken: RenderCancellationToken
    ) async throws -> RenderResult {
        for _ in 0..<8 {
            try await Task.sleep(for: .milliseconds(5))
            try await cancellationToken.throwIfCancelled()
        }
        let image = try request.graph.sourceImage()
        return RenderResult(
            image: image,
            metrics: RenderMetrics(
                cpuEncodingMilliseconds: 0,
                gpuExecutionMilliseconds: nil,
                totalMilliseconds: 40,
                inputPixelCount: 1,
                outputPixelCount: request.output.width * request.output.height,
                estimatedTextureBytes: 4
            ),
            cacheKey: request.cacheKey
        )
    }
}

private func schedulingRequest(byte: UInt8, timeValue: Int64) throws -> RenderRequest {
    let image = try PortableImage(
        data: Data([byte]),
        format: .png,
        pixelSize: VertexSize(width: 1, height: 1)
    )
    let sourceID = VertexID(rawValue: "10000000-0000-0000-0000-000000000001")
    let outputID = VertexID(rawValue: "10000000-0000-0000-0000-000000000002")
    let graph = RenderGraph(nodes: [
        RenderNode(id: sourceID, dependencies: [], kind: .source(image)),
        RenderNode(id: outputID, dependencies: [sourceID], kind: .output)
    ])
    return try RenderRequest(
        graph: graph,
        time: RationalTime(value: timeValue, timescale: 24),
        output: RenderOutputSpecification(width: 1, height: 1)
    )
}

@Test("Cancellation token changes state deterministically")
func renderCancellationToken() async throws {
    let token = RenderCancellationToken()
    try await token.throwIfCancelled()
    await token.cancel()
    await #expect(throws: RenderError.cancelled) {
        try await token.throwIfCancelled()
    }
}

@Test("A newer render cancels or rejects the older result")
func latestRequestWins() async throws {
    let coordinator = LatestRenderCoordinator(backend: DelayedRenderBackend())
    let firstRequest = try schedulingRequest(byte: 1, timeValue: 0)
    let secondRequest = try schedulingRequest(byte: 2, timeValue: 1)

    let firstTask = Task { try await coordinator.renderLatest(firstRequest) }
    try await Task.sleep(for: .milliseconds(10))
    let secondResult = try await coordinator.renderLatest(secondRequest)

    #expect(secondResult.image.data == Data([2]))
    await #expect(throws: RenderError.self) {
        _ = try await firstTask.value
    }
}
