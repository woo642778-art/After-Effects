import Foundation
import QuartzCore
import VertexComposition
import VertexCore
import VertexProject
import VertexRender
import VertexRenderMetal

@MainActor
public final class CompositionPlaybackEngine: ObservableObject {
    public enum State: Equatable {
        case stopped
        case playing
        case paused
        case buffering
        case failed(Error)
        
        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.stopped, .stopped), (.playing, .playing), (.paused, .paused), (.buffering, .buffering):
                return true
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }
    
    @Published public private(set) var state: State = .stopped
    @Published public private(set) var currentTime: RationalTime = .zero
    @Published public private(set) var currentFrameIndex: Int64 = 0
    @Published public private(set) var fps: Double = 0
    
    private var displayLink: CVDisplayLink?
    private var composition: ProjectComposition?
    private var project: ProjectDocument?
    private var packageURL: URL?
    private var renderCoordinator: LatestRenderCoordinator?
    private var frameResolver: CompositionMediaFrameResolver?
    private var compiler: CompositionGraphCompiler?
    private var effectResolver: (any CompositionEffectResolver)?
    private var outputSpec: RenderOutputSpecification?
    private var purpose: CompositionRenderPurpose = .interactivePreview
    
    private var frameCache: [Int64: RenderResult] = [:]
    private let maxCacheSize = 30
    private var pendingFrameIndex: Int64 = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var frameTimes: [CFTimeInterval] = []
    private let fpsSampleCount = 30
    
    private var isSeeking = false
    private var seekTargetTime: RationalTime?
    
    public init() {
        setupDisplayLink()
    }
    
    deinit {
        stopDisplayLink()
    }
    
    private func setupDisplayLink() {
        var displayLink: CVDisplayLink?
        let err = CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard err == kCVReturnSuccess, let link = displayLink else {
            print("Failed to create CVDisplayLink")
            return
        }
        
        let callback: CVDisplayLinkOutputCallback = { _, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext in
            let engine = Unmanaged<CompositionPlaybackEngine>.fromOpaque(displayLinkContext!).takeUnretainedValue()
            Task { @MainActor in
                engine.displayLinkCallback(now: inNow, outputTime: inOutputTime)
            }
            return kCVReturnSuccess
        }
        
        CVDisplayLinkSetOutputCallback(link, callback, Unmanaged.passUnretained(self).toOpaque())
        self.displayLink = link
    }
    
    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
    }
    
    private func displayLinkCallback(now: UnsafePointer<CVTimeStamp>, outputTime: UnsafePointer<CVTimeStamp>) {
        guard state == .playing, !isSeeking,
              let composition = composition,
              let coordinator = renderCoordinator,
              let outputSpec = outputSpec else { return }
        
        let targetTime = outputTime.pointee.videoTime
        let targetSeconds = Double(targetTime.timeValue) / Double(targetTime.timeScale)
        
        let frameDuration = composition.frameRate.seconds
        let targetFrameIndex = Int64((targetSeconds / frameDuration).rounded())
        let maxFrame = maxFrameIndex(for: composition)
        
        guard targetFrameIndex <= maxFrame else {
            Task { @MainActor in
                self.pause()
                self.currentFrameIndex = maxFrame
                self.currentTime = try? self.exactFrameTime(frameIndex: maxFrame, frameRate: composition.frameRate)
            }
            return
        }
        
        Task { @MainActor in
            await self.renderAndDeliverFrame(frameIndex: targetFrameIndex, targetTime: targetSeconds)
        }
    }
    
    public func prepare(
        project: ProjectDocument,
        packageURL: URL?,
        compositionID: VertexID,
        outputSpec: RenderOutputSpecification,
        purpose: CompositionRenderPurpose = .interactivePreview
    ) async throws {
        guard let composition = project.composition(id: compositionID) else {
            throw PlaybackError.compositionNotFound
        }
        
        self.project = project
        self.packageURL = packageURL
        self.composition = composition
        self.outputSpec = outputSpec
        self.purpose = purpose
        self.frameResolver = CompositionMediaFrameResolver(project: project, packageURL: packageURL)
        self.compiler = CompositionGraphCompiler()
        self.renderCoordinator = LatestRenderCoordinator(backend: try MetalRenderBackend())
        
        try await loadEffectResolverIfNeeded(project: project)
        
        clearCache()
        currentFrameIndex = 0
        currentTime = .zero
        state = .paused
    }
    
    private func loadEffectResolverIfNeeded(project: ProjectDocument) async throws {
        guard project.layerRegistry.contains(where: { $0.effects.contains(where: \.enabled) }) else { return }
        let environment = try BundledAIEnvironment.load()
        let service = try AIFrameEffectService.live(backend: BundledAIFrameEffectBackend(environment: environment))
        effectResolver = CompositionEffectResolverAdapter(service: service, environment: environment)
    }
    
    public func play() {
        guard state != .playing, composition != nil, displayLink != nil else { return }
        state = .playing
        lastFrameTime = CACurrentMediaTime()
        CVDisplayLinkStart(displayLink!)
    }
    
    public func pause() {
        guard state == .playing else { return }
        state = .paused
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
    }
    
    public func stop() {
        pause()
        currentFrameIndex = 0
        currentTime = .zero
        state = .stopped
        clearCache()
    }
    
    public func seek(to time: RationalTime) async {
        guard let composition = composition else { return }
        let clampedTime = min(max(time, .zero), composition.duration)
        
        isSeeking = true
        seekTargetTime = clampedTime
        
        pause()
        clearCache()
        
        let frameIndex = frameIndex(for: clampedTime, composition: composition)
        currentFrameIndex = frameIndex
        currentTime = clampedTime
        
        await renderAndDeliverFrame(frameIndex: frameIndex, targetTime: clampedTime.seconds)
        
        isSeeking = false
        seekTargetTime = nil
        
        if state == .playing {
            CVDisplayLinkStart(displayLink!)
        }
    }
    
    public func seekToFrame(_ frameIndex: Int64) async {
        guard let composition = composition else { return }
        let clamped = min(max(0, frameIndex), maxFrameIndex(for: composition))
        let time = try? exactFrameTime(frameIndex: clamped, frameRate: composition.frameRate)
        if let time { await seek(to: time) }
    }
    
    public func stepForward() async {
        guard let composition = composition else { return }
        let next = min(currentFrameIndex + 1, maxFrameIndex(for: composition))
        await seekToFrame(next)
    }
    
    public func stepBackward() async {
        let prev = max(currentFrameIndex - 1, 0)
        await seekToFrame(prev)
    }
    
    private func maxFrameIndex(for composition: ProjectComposition) -> Int64 {
        let count = floor(composition.duration.seconds * composition.frameRate.seconds + 0.0000001)
        guard count.isFinite, count > 1 else { return 0 }
        return Int64(min(count - 1, Double(Int64.max)))
    }
    
    private func frameIndex(for time: RationalTime, composition: ProjectComposition) -> Int64 {
        let value = time.seconds * composition.frameRate.seconds
        guard value.isFinite, value > 0 else { return 0 }
        return min(max(0, Int64(value.rounded())), maxFrameIndex(for: composition))
    }
    
    private func exactFrameTime(frameIndex: Int64, frameRate: RationalTime) throws -> RationalTime {
        guard frameRate.value > 0, frameRate.value <= Int64(Int32.max) else {
            throw PlaybackError.invalidFrameRate
        }
        let numerator = frameIndex.multipliedReportingOverflow(by: Int64(frameRate.timescale))
        guard !numerator.overflow else {
            throw PlaybackError.frameIndexOverflow
        }
        return RationalTime(value: numerator.partialValue, timescale: Int32(frameRate.value))
    }
    
    private func renderAndDeliverFrame(frameIndex: Int64, targetTime: Double) async {
        guard let composition = composition,
              let coordinator = renderCoordinator,
              let resolver = frameResolver,
              let compiler = compiler,
              let outputSpec = outputSpec else { return }
        
        if let cached = frameCache[frameIndex] {
            await deliverFrame(cached, frameIndex: frameIndex, targetTime: targetTime)
            return
        }
        
        state = .buffering
        
        do {
            let time = try exactFrameTime(frameIndex: frameIndex, frameRate: composition.frameRate)
            let request = CompositionRenderRequest(
                project: project!,
                compositionID: composition.id,
                time: time,
                output: outputSpec,
                purpose: purpose
            )
            let token = RenderCancellationToken()
            let graph: RenderRequest
            if let effectResolver = effectResolver {
                graph = try await compiler.compile(request, resolver: resolver, effectResolver: effectResolver, cancellationToken: token)
            } else {
                graph = try await compiler.compile(request, resolver: resolver, cancellationToken: token)
            }
            let rendered = try await coordinator.renderLatest(graph)
            
            await cacheFrame(frameIndex, rendered)
            await deliverFrame(rendered, frameIndex: frameIndex, targetTime: targetTime)
            
        } catch is CancellationError {
            state = .paused
        } catch {
            state = .failed(error)
        }
    }
    
    private func deliverFrame(_ result: RenderResult, frameIndex: Int64, targetTime: Double) async {
        guard state != .stopped else { return }
        
        currentFrameIndex = frameIndex
        currentTime = try? exactFrameTime(frameIndex: frameIndex, frameRate: composition!.frameRate)
        
        let now = CACurrentMediaTime()
        frameTimes.append(now)
        if frameTimes.count > fpsSampleCount {
            frameTimes.removeFirst()
        }
        if frameTimes.count >= 2 {
            let elapsed = frameTimes.last! - frameTimes.first!
            fps = Double(frameTimes.count - 1) / elapsed
        }
        
        lastFrameTime = now
    }
    
    private func cacheFrame(_ index: Int64, _ result: RenderResult) {
        frameCache[index] = result
        if frameCache.count > maxCacheSize {
            let keysToRemove = frameCache.keys.sorted().prefix(frameCache.count - maxCacheSize)
            for key in keysToRemove {
                frameCache.removeValue(forKey: key)
            }
        }
    }
    
    private func clearCache() {
        frameCache.removeAll()
        frameTimes.removeAll()
        fps = 0
    }
    
    public var duration: RationalTime { composition?.duration ?? .zero }
    public var frameRate: RationalTime { composition?.frameRate ?? RationalTime(value: 30, timescale: 1) }
    public var totalFrames: Int64 { maxFrameIndex(for: composition!) + 1 }
    public var progress: Double {
        guard let comp = composition, comp.duration.seconds > 0 else { return 0 }
        return currentTime.seconds / comp.duration.seconds
    }
    
    public func resultForCurrentFrame() -> RenderResult? {
        frameCache[currentFrameIndex]
    }
}

public enum PlaybackError: Error, LocalizedError {
    case compositionNotFound
    case invalidFrameRate
    case frameIndexOverflow
    case noActiveComposition
    case renderFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .compositionNotFound: return "Composition not found"
        case .invalidFrameRate: return "Invalid frame rate"
        case .frameIndexOverflow: return "Frame index overflow"
        case .noActiveComposition: return "No active composition"
        case .renderFailed(let err): return "Render failed: \(err.localizedDescription)"
        }
    }
}