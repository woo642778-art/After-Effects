import Foundation
import VertexCore
import VertexMedia
import VertexRender
import VertexRenderMetal

@MainActor
final class RenderLabViewModel: ObservableObject {
    enum State {
        case idle
        case rendering
        case rendered(RenderResult)
        case failed(String)
    }

    @Published var exposure: Double = 0 { didSet { scheduleRender() } }
    @Published var saturation: Double = 1 { didSet { scheduleRender() } }
    @Published var opacity: Double = 1 { didSet { scheduleRender() } }
    @Published var inverted = false { didSet { scheduleRender() } }
    @Published var scale: Double = 1 { didSet { scheduleRender() } }
    @Published var translationX: Double = 0 { didSet { scheduleRender() } }
    @Published var translationY: Double = 0 { didSet { scheduleRender() } }
    @Published var outputLongEdge = 1080 { didSet { scheduleRender() } }
    @Published private(set) var state: State = .idle

    let source: PortableImage

    private var coordinator: LatestRenderCoordinator?
    private var debounceTask: Task<Void, Never>?
    private var hasStarted = false

    init(source: PortableImage) {
        self.source = source
        do {
            coordinator = LatestRenderCoordinator(backend: try MetalRenderBackend())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    deinit {
        debounceTask?.cancel()
    }

    var renderedImageData: Data? {
        guard case .rendered(let result) = state else { return nil }
        return result.image.data
    }

    var exportDocument: RenderExportDocument? {
        guard let data = renderedImageData else { return nil }
        return RenderExportDocument(data: data)
    }

    var metrics: RenderMetrics? {
        guard case .rendered(let result) = state else { return nil }
        return result.metrics
    }

    var cacheKey: String? {
        guard case .rendered(let result) = state else { return nil }
        return result.cacheKey.rawValue
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        scheduleRender(immediate: true)
    }

    func renderNow() {
        scheduleRender(immediate: true)
    }

    private func scheduleRender(immediate: Bool = false) {
        guard hasStarted, coordinator != nil else { return }
        debounceTask?.cancel()

        let exposure = exposure
        let saturation = saturation
        let opacity = opacity
        let inverted = inverted
        let scale = scale
        let translationX = translationX
        let translationY = translationY
        let outputLongEdge = outputLongEdge

        debounceTask = Task { [weak self] in
            guard let self else { return }
            if !immediate {
                do {
                    try await Task.sleep(for: .milliseconds(120))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            await self.performRender(
                exposure: exposure,
                saturation: saturation,
                opacity: opacity,
                inverted: inverted,
                scale: scale,
                translationX: translationX,
                translationY: translationY,
                outputLongEdge: outputLongEdge
            )
        }
    }

    private func performRender(
        exposure: Double,
        saturation: Double,
        opacity: Double,
        inverted: Bool,
        scale: Double,
        translationX: Double,
        translationY: Double,
        outputLongEdge: Int
    ) async {
        guard let coordinator else { return }
        state = .rendering

        do {
            let output = try outputSpecification(longEdge: outputLongEdge)
            let sourceID = VertexID(rawValue: "30000000-0000-0000-0000-000000000001")
            let operationID = VertexID(rawValue: "30000000-0000-0000-0000-000000000002")
            let outputID = VertexID(rawValue: "30000000-0000-0000-0000-000000000003")
            let graph = RenderGraph(nodes: [
                RenderNode(id: sourceID, dependencies: [], kind: .source(source)),
                RenderNode(
                    id: operationID,
                    dependencies: [sourceID],
                    kind: .operations([
                        .transform(scale: scale, translationX: translationX, translationY: translationY),
                        .exposure(stops: exposure),
                        .saturation(saturation),
                        .invert(inverted),
                        .opacity(opacity)
                    ])
                ),
                RenderNode(id: outputID, dependencies: [operationID], kind: .output)
            ])
            let request = try RenderRequest(graph: graph, time: .zero, output: output)
            let result = try await coordinator.renderLatest(request)
            guard !Task.isCancelled else { return }
            state = .rendered(result)
        } catch RenderError.cancelled, RenderError.staleResult {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error.localizedDescription)
        }
    }

    private func outputSpecification(longEdge: Int) throws -> RenderOutputSpecification {
        let sourceWidth = max(1, source.pixelSize.width)
        let sourceHeight = max(1, source.pixelSize.height)
        let boundedLongEdge = max(240, min(2160, longEdge))
        let width: Int
        let height: Int
        if sourceWidth >= sourceHeight {
            width = boundedLongEdge
            height = max(1, Int((Double(boundedLongEdge) * sourceHeight / sourceWidth).rounded()))
        } else {
            height = boundedLongEdge
            width = max(1, Int((Double(boundedLongEdge) * sourceWidth / sourceHeight).rounded()))
        }
        return try RenderOutputSpecification(width: width, height: height)
    }
}
