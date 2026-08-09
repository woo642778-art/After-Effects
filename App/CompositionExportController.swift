import CoreGraphics
import Foundation
import ImageIO
import VertexAI
import VertexAICoreML
import VertexComposition
import VertexCore
import VertexExport
import VertexExportAVFoundation
import VertexProject
import VertexRender
import VertexRenderMetal

@MainActor
final class CompositionExportController: ObservableObject {
    enum State: Equatable {
        case idle
        case rendering
        case completed
        case failed
        case cancelled
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var progress = ExportProgressSnapshot(completedFrames: 0, totalFrames: 0)
    @Published private(set) var completedURL: URL?
    @Published private(set) var errorMessage: String?

    private var task: Task<Void, Never>?
    private var cancellation: ExportCancellationToken?

    var isRunning: Bool { state == .rendering }

    func start(
        project: ProjectDocument,
        packageURL: URL?,
        composition: ProjectComposition,
        format: ExportFormat,
        codec: ExportVideoCodec?,
        quality: ExportQualityPreset,
        includeAlpha: Bool
    ) {
        cancel()
        do {
            let destination = try outputURL(projectName: project.metadata.name, format: format)
            let job = try ExportJob(
                format: format,
                codec: codec,
                quality: quality,
                width: composition.width,
                height: composition.height,
                frameRate: composition.frameRate,
                outputURL: destination,
                includeAlpha: includeAlpha,
                includeAudio: false
            ).validated()
            let frameCount = max(1, Int64(floor(composition.duration.seconds * composition.frameRate.seconds + 0.0000001)))
            let cancellation = ExportCancellationToken()
            self.cancellation = cancellation
            progress = ExportProgressSnapshot(completedFrames: 0, totalFrames: frameCount)
            completedURL = nil
            errorMessage = nil
            state = .rendering

            task = Task { [weak self] in
                guard let self else { return }
                do {
                    let renderer = try LatestRenderCoordinator(backend: MetalRenderBackend())
                    let output = try RenderOutputSpecification(width: job.width, height: job.height, color: composition.color)
                    let resolver = CompositionMediaFrameResolver(project: project, packageURL: packageURL)
                    let compiler = CompositionGraphCompiler()
                    let effectResolver = try self.effectResolverIfNeeded(project: project)
                    let writer = AppleExportWriter()
                    let compositionID = composition.id
                    let resultURL = try await writer.export(
                        job: job,
                        frameCount: frameCount,
                        frameProvider: { frameIndex in
                            try await cancellation.throwIfCancelled()
                            let time = try job.exactPresentationTime(frameIndex: frameIndex)
                            let request = CompositionRenderRequest(
                                project: project,
                                compositionID: compositionID,
                                time: time,
                                output: output,
                                purpose: .export
                            )
                            let token = RenderCancellationToken()
                            let graph: RenderRequest
                            if let effectResolver {
                                graph = try await compiler.compile(request, resolver: resolver, effectResolver: effectResolver, cancellationToken: token)
                            } else {
                                graph = try await compiler.compile(request, resolver: resolver, cancellationToken: token)
                            }
                            let rendered = try await renderer.renderLatest(graph)
                            return try Self.decodeRGBA(rendered.image.data, width: job.width, height: job.height)
                        },
                        progress: { snapshot in
                            Task { @MainActor [weak self] in self?.progress = snapshot }
                        },
                        cancellation: cancellation
                    )
                    guard !Task.isCancelled else { throw CancellationError() }
                    self.completedURL = resultURL
                    self.progress = ExportProgressSnapshot(completedFrames: frameCount, totalFrames: frameCount)
                    self.state = .completed
                } catch is CancellationError {
                    self.state = .cancelled
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.state = .failed
                }
                self.task = nil
                self.cancellation = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if let cancellation { Task { await cancellation.cancel() } }
        cancellation = nil
        if state == .rendering { state = .cancelled }
    }

    private func effectResolverIfNeeded(project: ProjectDocument) throws -> (any CompositionEffectResolver)? {
        guard project.layerRegistry.contains(where: { $0.effects.contains(where: \.enabled) }) else { return nil }
        let environment = try BundledAIEnvironment.load()
        let service = try AIFrameEffectService.live(backend: BundledAIFrameEffectBackend(environment: environment))
        return CompositionEffectResolverAdapter(service: service, environment: environment)
    }

    private func outputURL(projectName: String, format: ExportFormat) throws -> URL {
        let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let root = documents.appendingPathComponent("Vertex2 Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let cleaned = projectName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let base = (cleaned.isEmpty ? "Vertex2" : cleaned) + "-" + stamp
        if format.isImageSequence {
            return root.appendingPathComponent(base + "-" + format.rawValue, isDirectory: true)
        }
        return root.appendingPathComponent(base).appendingPathExtension(format.fileExtension)
    }

    nonisolated private static func decodeRGBA(_ encoded: Data, width: Int, height: Int) throws -> ExportRGBAFrame {
        guard let source = CGImageSourceCreateWithData(encoded as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw AppleExportWriterError.imageCreationFailed
        }
        var rgba = Data(count: width * height * 4)
        let success = rgba.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard success else { throw AppleExportWriterError.imageCreationFailed }
        return try ExportRGBAFrame(width: width, height: height, rgba8: rgba)
    }
}
