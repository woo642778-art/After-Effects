from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
def write(path, text):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)

write('App/EditorWorkspaceState.swift', r'''import Foundation
import VertexCore
import VertexProject

public enum TimelineTool: String, CaseIterable, Sendable {
    case selection
    case ripple
    case roll
    case slip
    case slide
}

public enum GraphEditorMode: String, CaseIterable, Sendable {
    case value
    case speed
}

public enum CompactEditorPanel: String, CaseIterable, Sendable {
    case timeline
    case effects
    case project
}

@MainActor
final class EditorWorkspaceState: ObservableObject {
    @Published var playhead: RationalTime = .zero
    @Published var selectedLayerIDs: Set<VertexID> = []
    @Published var selectedKeyframeIDs: Set<VertexID> = []
    @Published var activeTool: TimelineTool = .selection
    @Published var snappingEnabled = true
    @Published var pixelsPerSecond: Double = 120
    @Published var graphMode: GraphEditorMode? = nil
    @Published var compactPanel: CompactEditorPanel = .timeline

    private(set) var activeCompositionID: VertexID?

    func synchronize(project: ProjectDocument?) {
        guard let project,
              let compositionID = project.activeCompositionID,
              let composition = project.composition(id: compositionID) else {
            activeCompositionID = nil
            playhead = .zero
            selectedLayerIDs.removeAll()
            selectedKeyframeIDs.removeAll()
            return
        }

        let compositionChanged = activeCompositionID != compositionID
        activeCompositionID = compositionID
        let validLayerIDs = Set(composition.layerIDs)
        selectedLayerIDs.formIntersection(validLayerIDs)
        if selectedLayerIDs.isEmpty,
           let selected = project.selectedLayerID,
           validLayerIDs.contains(selected) {
            selectedLayerIDs = [selected]
        }
        if compositionChanged || selectedLayerIDs.isEmpty {
            selectedKeyframeIDs.removeAll()
        } else {
            let validKeyframes = Set(
                project.layerRegistry
                    .filter { selectedLayerIDs.contains($0.id) }
                    .flatMap(\.animationChannels)
                    .flatMap(\.keyframes)
                    .map(\.id)
            )
            selectedKeyframeIDs.formIntersection(validKeyframes)
        }
        clampPlayhead(to: composition)
    }

    func setPlayhead(_ time: RationalTime, composition: ProjectComposition) {
        playhead = time
        clampPlayhead(to: composition)
    }

    func setPlayhead(frameIndex: Int64, composition: ProjectComposition) {
        guard composition.frameRate.value > 0,
              composition.frameRate.value <= Int64(Int32.max) else {
            playhead = .zero
            return
        }
        let index = max(0, frameIndex)
        let product = index.multipliedReportingOverflow(by: Int64(composition.frameRate.timescale))
        guard !product.overflow else {
            playhead = composition.duration
            return
        }
        playhead = RationalTime(
            value: product.partialValue,
            timescale: Int32(composition.frameRate.value)
        )
        clampPlayhead(to: composition)
    }

    func selectLayer(_ id: VertexID?, additive: Bool = false) {
        guard let id else {
            selectedLayerIDs.removeAll()
            selectedKeyframeIDs.removeAll()
            return
        }
        if additive {
            if selectedLayerIDs.remove(id) == nil { selectedLayerIDs.insert(id) }
        } else {
            selectedLayerIDs = [id]
        }
        selectedKeyframeIDs.removeAll()
    }

    private func clampPlayhead(to composition: ProjectComposition) {
        if playhead < .zero { playhead = .zero }
        if playhead > composition.duration { playhead = composition.duration }
    }
}
''')

write('App/VertexEditorWorkspaceView.swift', r'''import SwiftUI
import UIKit
import VertexCore
import VertexProject

struct VertexEditorWorkspaceView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var editorState = EditorWorkspaceState()
    @StateObject private var preview = CompositionPreviewController()

    var body: some View {
        Group {
            if workspace.project == nil {
                projectBootstrap
            } else if horizontalSizeClass == .regular {
                IPadEditorWorkspaceView(editorState: editorState, preview: preview)
            } else {
                IPhoneEditorWorkspaceView(editorState: editorState, preview: preview)
            }
        }
        .onAppear {
            synchronizeAndRender()
        }
        .onChange(of: workspace.project?.activeCompositionID) { _, _ in
            synchronizeAndRender()
        }
        .onChange(of: workspace.project?.revision) { _, _ in
            synchronizeAndRender()
        }
        .onChange(of: editorState.playhead) { _, _ in
            renderCurrentFrame()
        }
        .onChange(of: preview.aiResultGeneration) { _, _ in
            renderCurrentFrame()
        }
    }

    private var projectBootstrap: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                editorHeader
                ProjectWorkspaceView()
                MediaImportView()
            }
            .padding(18)
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 12) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Vertex2")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text("Professional Timeline Workspace")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            Spacer()
        }
    }

    private func synchronizeAndRender() {
        editorState.synchronize(project: workspace.project)
        if let selected = editorState.selectedLayerIDs.sorted(by: { $0.rawValue < $1.rawValue }).first {
            workspace.selectLayer(selected)
        }
        renderCurrentFrame()
    }

    private func renderCurrentFrame() {
        guard let project = workspace.project else {
            preview.cancel()
            return
        }
        preview.render(project: project, packageURL: workspace.packageURL, at: editorState.playhead)
    }
}

struct EditorPreviewSurface: View {
    @ObservedObject var preview: CompositionPreviewController
    @ObservedObject var editorState: EditorWorkspaceState
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("COMPOSITION")
                    .font(.caption.bold())
                    .foregroundStyle(AfterEffectsTheme.accent)
                Spacer()
                Text(editorState.playhead.description)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            ZStack {
                Color.black
                if let result = preview.result, let image = UIImage(data: result.image.data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else if preview.isRendering {
                    ProgressView("Rendering")
                        .tint(AfterEffectsTheme.accent)
                } else {
                    Text("No rendered frame")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
            }
            .aspectRatio(previewAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            if let error = preview.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private var previewAspectRatio: CGFloat {
        guard let composition = workspace.activeComposition, composition.height > 0 else { return 16 / 9 }
        return CGFloat(composition.width) / CGFloat(composition.height)
    }
}

struct WorkspaceTimelineOverview: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TIMELINE")
                    .font(.caption.bold())
                    .foregroundStyle(AfterEffectsTheme.accent)
                Spacer()
                Toggle("Snap", isOn: $editorState.snappingEnabled)
                    .labelsHidden()
                Text("Snap")
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            if let composition = workspace.activeComposition {
                Slider(
                    value: Binding(
                        get: { Double(currentFrame(composition)) },
                        set: { editorState.setPlayhead(frameIndex: Int64($0.rounded()), composition: composition) }
                    ),
                    in: 0...Double(max(1, lastFrame(composition))),
                    step: 1
                )
                .tint(AfterEffectsTheme.accent)
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(workspace.orderedLayers) { layer in
                            Button {
                                editorState.selectLayer(layer.id)
                                workspace.selectLayer(layer.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: layer.enabled ? "eye.fill" : "eye.slash")
                                        .frame(width: 18)
                                    Text(layer.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(String(format: "%.2fs", layer.timing.startTime.seconds))
                                        .font(.caption2.monospacedDigit())
                                }
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    editorState.selectedLayerIDs.contains(layer.id)
                                        ? AfterEffectsTheme.accent.opacity(0.18)
                                        : Color.white.opacity(0.035),
                                    in: RoundedRectangle(cornerRadius: 7)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text("Select a composition")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
    }

    private func currentFrame(_ composition: ProjectComposition) -> Int64 {
        guard composition.frameRate.seconds > 0 else { return 0 }
        return max(0, Int64((editorState.playhead.seconds * composition.frameRate.seconds).rounded()))
    }

    private func lastFrame(_ composition: ProjectComposition) -> Int64 {
        guard composition.frameRate.seconds > 0 else { return 0 }
        return max(0, Int64(floor(composition.duration.seconds * composition.frameRate.seconds + 0.0000001)) - 1)
    }
}
''')

write('App/IPadEditorWorkspaceView.swift', r'''import SwiftUI

struct IPadEditorWorkspaceView: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @ObservedObject var preview: CompositionPreviewController

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ScrollView {
                    VStack(spacing: 12) {
                        ProjectWorkspaceView()
                        MediaImportView()
                    }
                }
                .frame(minWidth: 250, idealWidth: 290, maxWidth: 340)

                EditorPreviewSurface(preview: preview, editorState: editorState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ScrollView {
                    Phase8LayerEditorView()
                }
                .frame(minWidth: 270, idealWidth: 310, maxWidth: 360)
            }
            .frame(maxHeight: .infinity)

            WorkspaceTimelineOverview(editorState: editorState)
                .frame(minHeight: 190, idealHeight: 250, maxHeight: 320)
        }
        .padding(8)
    }
}
''')

write('App/IPhoneEditorWorkspaceView.swift', r'''import SwiftUI

struct IPhoneEditorWorkspaceView: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @ObservedObject var preview: CompositionPreviewController

    var body: some View {
        VStack(spacing: 8) {
            EditorPreviewSurface(preview: preview, editorState: editorState)
            Picker("Panel", selection: $editorState.compactPanel) {
                Text("Timeline").tag(CompactEditorPanel.timeline)
                Text("Effects").tag(CompactEditorPanel.effects)
                Text("Project").tag(CompactEditorPanel.project)
            }
            .pickerStyle(.segmented)

            ScrollView {
                switch editorState.compactPanel {
                case .timeline:
                    WorkspaceTimelineOverview(editorState: editorState)
                case .effects:
                    Phase8LayerEditorView()
                case .project:
                    VStack(spacing: 12) {
                        ProjectWorkspaceView()
                        MediaImportView()
                    }
                }
            }
        }
        .padding(8)
    }
}
''')

write('App/RootView.swift', r'''import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("afterEffects.didPresentTelegramPromotion.v1")
    private var didPresentTelegramPromotion = false
    @State private var isTelegramPromotionPresented = false
    @StateObject private var projectWorkspace = ProjectWorkspaceViewModel()

    var body: some View {
        ZStack {
            AfterEffectsTheme.background.ignoresSafeArea()
            VertexEditorWorkspaceView()
        }
        .environmentObject(projectWorkspace)
        .preferredColorScheme(.dark)
        .onAppear(perform: presentTelegramPromotionIfNeeded)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { projectWorkspace.flushAutosave() }
        }
        .sheet(isPresented: $isTelegramPromotionPresented) {
            TelegramPromotionView()
        }
    }

    private func presentTelegramPromotionIfNeeded() {
        var gate = OneTimePresentationGate(hasPresented: didPresentTelegramPromotion)
        guard gate.consumePresentation() else { return }
        didPresentTelegramPromotion = gate.hasPresented
        DispatchQueue.main.async { isTelegramPromotionPresented = true }
    }
}
''')

write('App/CompositionPreviewController.swift', r'''import Foundation
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
''')
print('Task 10 GREEN adaptive workspace written')
