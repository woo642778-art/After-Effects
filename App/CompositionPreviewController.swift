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

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
final class CompositionPreviewController: ObservableObject {
    @Published private(set) var frameIndex: Int64 = 0
    @Published private(set) var result: RenderResult?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRendering = false

    private var coordinator: LatestRenderCoordinator?
    private var renderTask: Task<Void, Never>?
    private var compileToken: RenderCancellationToken?
    private var generation: UInt64 = 0

    init() {
        do {
            coordinator = LatestRenderCoordinator(backend: try MetalRenderBackend())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var exportDocument: CompositionPNGDocument? {
        result.map { CompositionPNGDocument(data: $0.image.data) }
    }

    func setFrameIndex(_ value: Int64, composition: ProjectComposition) {
        let clamped = min(max(0, value), lastFrameIndex(for: composition))
        guard clamped != frameIndex else { return }
        frameIndex = clamped
    }

    func step(by frames: Int64, composition: ProjectComposition) {
        let sum = frameIndex.addingReportingOverflow(frames)
        setFrameIndex(sum.overflow ? (frames < 0 ? 0 : Int64.max) : sum.partialValue, composition: composition)
    }

    func resetForComposition(_ composition: ProjectComposition) {
        setFrameIndex(0, composition: composition)
    }

    func render(project: ProjectDocument, packageURL: URL?) {
        guard let compositionID = project.activeCompositionID,
              let composition = project.composition(id: compositionID),
              let coordinator else {
            errorMessage = "Create or select a composition before rendering."
            return
        }
        setFrameIndex(frameIndex, composition: composition)
        generation &+= 1
        let requestGeneration = generation
        renderTask?.cancel()
        if let compileToken {
            Task { await compileToken.cancel() }
        }
        let token = RenderCancellationToken()
        compileToken = token
        isRendering = true
        errorMessage = nil

        renderTask = Task { [weak self] in
            guard let self else { return }
            do {
                let time = try self.exactTime(frameIndex: self.frameIndex, frameRate: composition.frameRate)
                let output = try RenderOutputSpecification(
                    width: composition.width,
                    height: composition.height,
                    color: composition.color
                )
                let compositionRequest = CompositionRenderRequest(
                    project: project,
                    compositionID: compositionID,
                    time: time,
                    output: output
                )
                let resolver = CompositionMediaFrameResolver(project: project, packageURL: packageURL)
                let renderRequest = try await CompositionGraphCompiler().compile(
                    compositionRequest,
                    resolver: resolver,
                    cancellationToken: token
                )
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

    private func exactTime(frameIndex: Int64, frameRate: RationalTime) throws -> RationalTime {
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
