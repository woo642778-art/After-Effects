import Foundation
import SwiftUI
import UniformTypeIdentifiers
import VertexComposition
import VertexCore
import VertexProject
import VertexRender
import VertexRenderMetal

struct CompositionPNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
final class CompositionPreviewController: ObservableObject {
    @Published private(set) var frameIndex: Int64 = 0
    @Published private(set) var exactTime: RationalTime = .zero
    @Published private(set) var result: RenderResult?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRendering = false
    @Published private(set) var aiResultGeneration: UInt64 = 0

    private var coordinator: LatestRenderCoordinator?
    private var renderTask: Task<Void, Never>?
    private var compileToken: RenderCancellationToken?
    private var generation: UInt64 = 0
    private var aiEnvironment: BundledAIEnvironment?
    private var aiService: AIFrameEffectService?

    init() {
        do { coordinator = LatestRenderCoordinator(backend: try MetalRenderBackend()) }
        catch { errorMessage = error.localizedDescription }
    }

    var exportDocument: CompositionPNGDocument? {
        result.map { CompositionPNGDocument(data: $0.image.data) }
    }

    func setFrameIndex(_ value: Int64, composition: ProjectComposition) {
        let clamped = min(max(0, value), lastFrameIndex(for: composition))
        guard clamped != frameIndex else { return }
        frameIndex = clamped
        exactTime = (try? currentTime(for: composition)) ?? .zero
    }

    func step(by frames: Int64, composition: ProjectComposition) {
        let sum = frameIndex.addingReportingOverflow(frames)
        setFrameIndex(sum.overflow ? (frames < 0 ? 0 : Int64.max) : sum.partialValue, composition: composition)
    }

    func resetForComposition(_ composition: ProjectComposition) {
        frameIndex = 0
        exactTime = .zero
    }

    func currentTime(for composition: ProjectComposition) throws -> RationalTime {
        try exactFrameTime(frameIndex: frameIndex, frameRate: composition.frameRate)
    }

    func render(project: ProjectDocument, packageURL: URL?) {
        guard let compositionID = project.activeCompositionID,
              let composition = project.composition(id: compositionID) else {
            errorMessage = "Create or select a composition before rendering."
            return
        }
        let time = (try? currentTime(for: composition)) ?? .zero
        render(project: project, packageURL: packageURL, at: time)
    }

    func render(project: ProjectDocument, packageURL: URL?, at requestedTime: RationalTime) {
        guard let compositionID = project.activeCompositionID,
              let composition = project.composition(id: compositionID),
              let coordinator else {
            errorMessage = "Create or select a composition before rendering."
            return
        }
        let time = min(max(requestedTime, .zero), composition.duration)
        exactTime = time
        frameIndex = frameIndex(for: time, composition: composition)
        generation &+= 1
        let requestGeneration = generation
        renderTask?.cancel()
        if let compileToken { Task { await compileToken.cancel() } }
        let token = RenderCancellationToken()
        compileToken = token
        isRendering = true
        errorMessage = nil

        let effectResolver: (any CompositionEffectResolver)?
        do { effectResolver = try effectResolverIfNeeded(project: project) }
        catch {
            errorMessage = "AI effect runtime unavailable: \(error.localizedDescription)"
            isRendering = false
            return
        }

        renderTask = Task { [weak self] in
            guard let self else { return }
            do {
                let output = try RenderOutputSpecification(
                    width: composition.width,
                    height: composition.height,
                    color: composition.color
                )
                let compositionRequest = CompositionRenderRequest(
                    project: project,
                    compositionID: compositionID,
                    time: time,
                    output: output,
                    purpose: .interactivePreview
                )
                let resolver = CompositionMediaFrameResolver(project: project, packageURL: packageURL)
                let compiler = CompositionGraphCompiler()
                let renderRequest: RenderRequest
                if let effectResolver {
                    renderRequest = try await compiler.compile(
                        compositionRequest,
                        resolver: resolver,
                        effectResolver: effectResolver,
                        cancellationToken: token
                    )
                } else {
                    renderRequest = try await compiler.compile(
                        compositionRequest,
                        resolver: resolver,
                        cancellationToken: token
                    )
                }
                let rendered = try await coordinator.renderLatest(renderRequest)
                guard !Task.isCancelled, self.generation == requestGeneration else { return }
                self.result = rendered
                self.errorMessage = nil
                self.isRendering = false
            } catch CompositionError.cancelled, RenderError.cancelled, RenderError.staleResult {
                if self.generation == requestGeneration { self.isRendering = false }
            } catch {
                guard !Task.isCancelled, self.generation == requestGeneration else { return }
                self.errorMessage = error.localizedDescription
                self.isRendering = false
            }
        }
    }

    func notifyAIResultGenerationChanged() {
        aiResultGeneration &+= 1
    }

    func cancel() {
        generation &+= 1
        renderTask?.cancel()
        renderTask = nil
        if let compileToken { Task { await compileToken.cancel() } }
        if let coordinator { Task { await coordinator.cancelActiveRender() } }
        isRendering = false
    }

    func lastFrameIndex(for composition: ProjectComposition) -> Int64 {
        let count = floor(composition.duration.seconds * composition.frameRate.seconds + 0.0000001)
        guard count.isFinite, count > 1 else { return 0 }
        return Int64(min(count - 1, Double(Int64.max)))
    }

    private func effectResolverIfNeeded(project: ProjectDocument) throws -> (any CompositionEffectResolver)? {
        guard project.layerRegistry.contains(where: { $0.effects.contains(where: \.enabled) }) else { return nil }
        let environment: BundledAIEnvironment
        if let aiEnvironment { environment = aiEnvironment }
        else {
            environment = try BundledAIEnvironment.load()
            aiEnvironment = environment
        }
        let service: AIFrameEffectService
        if let aiService { service = aiService }
        else {
            service = try AIFrameEffectService.live(backend: BundledAIFrameEffectBackend(environment: environment))
            aiService = service
        }
        return CompositionEffectResolverAdapter(service: service, environment: environment)
    }

    private func frameIndex(for time: RationalTime, composition: ProjectComposition) -> Int64 {
        let value = time.seconds * composition.frameRate.seconds
        guard value.isFinite, value > 0 else { return 0 }
        return min(max(0, Int64(value.rounded())), lastFrameIndex(for: composition))
    }

    private func exactFrameTime(frameIndex: Int64, frameRate: RationalTime) throws -> RationalTime {
        guard frameRate.value > 0, frameRate.value <= Int64(Int32.max) else {
            throw CompositionError.invalidTimingRange("Frame rate cannot be represented as an exact frame denominator.")
        }
        let numerator = frameIndex.multipliedReportingOverflow(by: Int64(frameRate.timescale))
        guard !numerator.overflow else {
            throw CompositionError.invalidTimingRange("Frame index overflowed exact time conversion.")
        }
        return RationalTime(value: numerator.partialValue, timescale: Int32(frameRate.value))
    }
}
