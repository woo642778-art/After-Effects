# Render time inspection
Sources/VertexComposition/CompositionEffectResolver.swift:11:public struct CompositionEffectRequest: Sendable {
Sources/VertexComposition/CompositionEffectResolver.swift:49:    func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage
Sources/VertexComposition/CompositionEffectResolver.swift:54:    public func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage {
Sources/VertexComposition/CompositionGraphCompiler.swift:233:                    image = try await effectResolver.resolve(CompositionEffectRequest(
App/NativeFrameEffectProcessor.swift:23:    func process(_ request: CompositionEffectRequest) throws -> PortableImage {
App/CompositionEffectResolverAdapter.swift:11:    func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage {
Tests/VertexCompositionTests/EffectGraphCompilerTests.swift:26:    private(set) var requests: [CompositionEffectRequest] = []
Tests/VertexCompositionTests/EffectGraphCompilerTests.swift:27:    func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage {
## Effect backend protocols
Sources/VertexComposition/CompositionEffectResolver.swift:11:public struct CompositionEffectRequest: Sendable {
Sources/VertexComposition/CompositionEffectResolver.swift:49:    func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage
Sources/VertexComposition/CompositionEffectResolver.swift:54:    public func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage {
Sources/VertexComposition/CompositionEffectResolver.swift:56:            "Layer \(request.layerID.rawValue) requires effect \(request.effect.type.rawValue), but no effect resolver was provided."
Sources/VertexComposition/CompositionGraphCompiler.swift:233:                    image = try await effectResolver.resolve(CompositionEffectRequest(
App/NativeFrameEffectProcessor.swift:23:    func process(_ request: CompositionEffectRequest) throws -> PortableImage {
App/NativeFrameEffectProcessor.swift:24:        guard request.effect.type.isNativePixelEffect else {
App/NativeFrameEffectProcessor.swift:25:            throw CompositionError.graphCompilationFailed("Native processor received a non-native effect: \(request.effect.type.rawValue).")
App/NativeFrameEffectProcessor.swift:31:        let output = try filteredImage(effect: request.effect, input: input).cropped(to: input.extent)
App/CompositionEffectResolverAdapter.swift:11:    func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage {
App/CompositionEffectResolverAdapter.swift:13:            if request.effect.type.isNativePixelEffect {
App/CompositionEffectResolverAdapter.swift:14:                return try NativeFrameEffectProcessor().process(request)
App/CompositionEffectResolverAdapter.swift:17:            let (recipe, requestedTier) = try request.effect.aiRecipeAndTier()
App/CompositionEffectResolverAdapter.swift:26:                effectType: request.effect.type.rawValue,
App/CompositionEffectResolverAdapter.swift:35:            let frameRequest = AIFrameEffectRequest(
App/CompositionEffectResolverAdapter.swift:37:                effectID: request.effect.id,
App/CompositionEffectResolverAdapter.swift:38:                effect: request.effect,
App/CompositionEffectResolverAdapter.swift:50:                effectID: request.effect.id.rawValue,
App/CompositionEffectResolverAdapter.swift:51:                effectType: request.effect.type.rawValue,
App/CompositionExportController.swift:96:                                graph = try await compiler.compile(request, resolver: resolver, effectResolver: effectResolver, cancellationToken: token)
App/CompositionExportController.swift:138:        let service = try AIFrameEffectService.live(backend: BundledAIFrameEffectBackend(environment: environment))
App/CompositionPreviewController.swift:183:            service = try AIFrameEffectService.live(backend: BundledAIFrameEffectBackend(environment: environment))
App/AIEffectBakeCoordinator.swift:59:        let (recipe, requestedTier) = try effect.aiRecipeAndTier()
App/BundledAIEnvironment+FrameEffects.swift:78:actor BundledAIFrameEffectBackend: AIFrameEffectBackend {
App/BundledAIEnvironment+FrameEffects.swift:95:    func infer(_ request: AIFrameEffectRequest) async throws -> PortableImage {
App/BundledAIEnvironment+FrameEffects.swift:97:        let (recipe, tier) = try request.effect.aiRecipeAndTier()
App/BundledAIEnvironment+FrameEffects.swift:102:            let result = try depth.infer(pixelBuffer: input, recipe: value, previousFrame: previousDepth[request.effectID])
App/BundledAIEnvironment+FrameEffects.swift:103:            previousDepth[request.effectID] = result
App/BundledAIEnvironment+FrameEffects.swift:106:            let mask = try cutout.infer(pixelBuffer: input, recipe: value, previousFrame: previousMask[request.effectID])
App/BundledAIEnvironment+FrameEffects.swift:107:            previousMask[request.effectID] = mask
App/AIFrameEffectService.swift:7:struct AIFrameEffectRequest: Sendable {
App/AIFrameEffectService.swift:15:protocol AIFrameEffectBackend: Sendable {
App/AIFrameEffectService.swift:16:    func infer(_ request: AIFrameEffectRequest) async throws -> PortableImage
App/AIFrameEffectService.swift:34:        var request: AIFrameEffectRequest
App/AIFrameEffectService.swift:42:    private let backend: any AIFrameEffectBackend
App/AIFrameEffectService.swift:55:        backend: any AIFrameEffectBackend,
App/AIFrameEffectService.swift:70:    static func live(backend: any AIFrameEffectBackend) throws -> AIFrameEffectService {
App/AIFrameEffectService.swift:81:    func resolve(request: AIFrameEffectRequest, priority: AIFramePriority) async throws -> PortableImage {
App/AIFrameEffectService.swift:83:            effectStatus[request.effectID] = .cached
App/AIFrameEffectService.swift:86:        effectStatus[request.effectID] = .computing
App/AIFrameEffectService.swift:92:    func prefetch(_ requests: [AIFrameEffectRequest], priority: AIFramePriority) async {
App/AIFrameEffectService.swift:110:            effectStatus[job.request.effectID] = .stale
App/AIFrameEffectService.swift:154:        request: AIFrameEffectRequest,
App/AIFrameEffectService.swift:209:                try writeDisk(digest: digest, effectID: job.request.effectID, image: image)
App/AIFrameEffectService.swift:210:                insertMemory(digest: digest, effectID: job.request.effectID, image: image)
App/AIFrameEffectService.swift:211:                effectStatus[job.request.effectID] = .cached
App/AIFrameEffectService.swift:214:                effectStatus[job.request.effectID] = .failed(error.localizedDescription)
App/AIFrameEffectService.swift:218:            effectStatus[job.request.effectID] = error is CancellationError ? .stale : .failed(error.localizedDescription)
## RationalTime composition render references
Sources/VertexComposition/CompositionError.swift:16:    case effectResolutionFailed(layerID: String, effectID: String, effectType: String, time: String, message: String)
Sources/VertexComposition/LayerAnimationEvaluator.swift:17:        at time: RationalTime
Sources/VertexComposition/EffectAnimationEvaluator.swift:9:        at time: RationalTime
Sources/VertexComposition/CompositionModule.swift:5:        "Exact RationalTime compilation",
Sources/VertexComposition/CompositionVisibility.swift:9:        time: RationalTime
Sources/VertexComposition/CompositionTypes.swift:15:        exactSourceTime: RationalTime,
Sources/VertexComposition/CompositionTypes.swift:23:        exactSourceTime: RationalTime,
Sources/VertexComposition/CompositionTypes.swift:61:    public var time: RationalTime
Sources/VertexComposition/CompositionTypes.swift:69:        time: RationalTime,
Sources/VertexComposition/CompositionTypes.swift:85:    var time: RationalTime
Sources/VertexComposition/CompositionEffectResolver.swift:17:    public var exactCompositionTime: RationalTime
Sources/VertexComposition/CompositionEffectResolver.swift:18:    public var exactSourceTime: RationalTime
Sources/VertexComposition/CompositionEffectResolver.swift:29:        exactCompositionTime: RationalTime,
Sources/VertexComposition/CompositionEffectResolver.swift:30:        exactSourceTime: RationalTime,
Sources/VertexComposition/CompositionEffectResolver.swift:40:        self.exactCompositionTime = exactCompositionTime
Sources/VertexComposition/CompositionGraphCompiler.swift:43:            time: request.time,
Sources/VertexComposition/CompositionGraphCompiler.swift:55:                time: request.time,
Sources/VertexComposition/CompositionGraphCompiler.swift:100:        time: RationalTime,
Sources/VertexComposition/CompositionGraphCompiler.swift:134:            time: time
Sources/VertexComposition/CompositionGraphCompiler.swift:151:                    compositionTime: time,
Sources/VertexComposition/CompositionGraphCompiler.swift:177:                        compositionTime: time,
Sources/VertexComposition/CompositionGraphCompiler.swift:206:        compositionTime: RationalTime,
Sources/VertexComposition/CompositionGraphCompiler.swift:218:                compositionTime: compositionTime,
Sources/VertexComposition/CompositionGraphCompiler.swift:219:                sourceStartTime: sourceStartTime
Sources/VertexComposition/CompositionGraphCompiler.swift:222:            let resolution = try await resolveFrame(mediaID: mediaID, time: sourceTime)
Sources/VertexComposition/CompositionGraphCompiler.swift:230:                    at: compositionTime
Sources/VertexComposition/CompositionGraphCompiler.swift:239:                        exactCompositionTime: compositionTime,
Sources/VertexComposition/CompositionGraphCompiler.swift:240:                        exactSourceTime: sourceTime,
Sources/VertexComposition/CompositionGraphCompiler.swift:249:                        "Effect \(effect.type.rawValue) on layer \(layer.id.rawValue) failed at \(compositionTime.description): \(error.localizedDescription)"
Sources/VertexComposition/CompositionGraphCompiler.swift:262:                compositionTime: compositionTime,
Sources/VertexComposition/CompositionGraphCompiler.swift:263:                sourceStartTime: sourceStartTime
Sources/VertexComposition/CompositionGraphCompiler.swift:272:                time: childTime,
Sources/VertexComposition/CompositionGraphCompiler.swift:296:                compositionTime: compositionTime,
Sources/VertexComposition/CompositionGraphCompiler.swift:316:        compositionTime: RationalTime,
Sources/VertexComposition/CompositionGraphCompiler.swift:317:        sourceStartTime: RationalTime
Sources/VertexComposition/CompositionGraphCompiler.swift:318:    ) throws -> RationalTime {
Sources/VertexComposition/CompositionGraphCompiler.swift:319:        let layerLocalTime = try compositionTime.subtracting(layer.timing.startTime)
Sources/VertexComposition/CompositionGraphCompiler.swift:321:            return try TimeRemapEvaluator().sourceTime(mapping: mapping, compositionTime: layerLocalTime)
Sources/VertexComposition/CompositionGraphCompiler.swift:329:        compositionTime: RationalTime,
Sources/VertexComposition/CompositionGraphCompiler.swift:358:        let evaluated = try LayerAnimationEvaluator.evaluate(layer: matteLayer, at: compositionTime)
Sources/VertexComposition/CompositionGraphCompiler.swift:362:            compositionTime: compositionTime,
Sources/VertexComposition/CompositionGraphCompiler.swift:380:    func resolveFrame(mediaID: VertexID, time: RationalTime) async throws -> CompositionFrameResolution {
Sources/VertexComposition/CompositionGraphCompiler.swift:384:        let key = CompositionFrameCacheKey(mediaID: mediaID, time: time, width: output.width, height: output.height)
Sources/VertexComposition/CompositionGraphCompiler.swift:390:                exactSourceTime: time,
App/AETimelineView.swift:17:        frameRate: RationalTime
App/AETimelineView.swift:22:    static func splitEdit(layerID: VertexID, playhead: RationalTime) -> TimelineEdit {
App/AETimelineView.swift:26:    static func trimInEdit(layerID: VertexID, playhead: RationalTime) -> TimelineEdit {
App/AETimelineView.swift:30:    static func trimOutEdit(layerID: VertexID, playhead: RationalTime) -> TimelineEdit {
App/AETimelineView.swift:45:        from time: RationalTime,
App/AETimelineView.swift:48:    ) throws -> RationalTime {
App/AETimelineView.swift:54:        let frameDuration = RationalTime(
App/AETimelineView.swift:60:        let offset = RationalTime(value: scaled.partialValue, timescale: frameDuration.timescale)
App/AETimelineView.swift:61:        let candidate: RationalTime
App/AETimelineView.swift:73:        proposed: RationalTime,
App/AETimelineView.swift:77:    ) throws -> RationalTime {
App/AETimelineView.swift:80:            proposedTime: proposed,
App/AETimelineView.swift:87:    static func exactDelta(points: Double, pixelsPerSecond: Double, frameRate: RationalTime) throws -> RationalTime {
App/AETimelineView.swift:96:        return RationalTime(value: numerator.partialValue, timescale: Int32(frameRate.value))
App/AETimelineView.swift:358:    private func timecode(_ time: RationalTime, composition: ProjectComposition) -> String {
App/AETimelineView.swift:423:        markers.append(ProjectMarker(time: editorState.playhead, name: "Marker \(markerNumber)"))
App/ProjectWorkspaceViewModel.swift:242:            duration: basis?.duration ?? RationalTime(value: 10, timescale: 1),
App/ProjectWorkspaceViewModel.swift:338:    func setActiveCompositionFrameRate(_ frameRate: RationalTime) {
App/ProjectWorkspaceViewModel.swift:353:            source: .media(mediaID: media.id, sourceStartTime: .zero),
App/ProjectWorkspaceViewModel.swift:380:            source: .composition(compositionID: sourceCompositionID, sourceStartTime: .zero),
App/ProjectWorkspaceViewModel.swift:692:        LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration)
App/ProjectWorkspaceViewModel.swift:719:    func exactTime(seconds: Double, frameRate: RationalTime) -> RationalTime? {
App/ProjectWorkspaceViewModel.swift:727:        return RationalTime(value: numerator.partialValue, timescale: Int32(frameRate.value))
App/AETimelineLayerRow.swift:258:            let key = ProjectKeyframe(time: editorState.playhead, value: .scalar(staticValue(property)), interpolation: .linear)
App/AETimelineLayerRow.swift:278:                let key = ProjectKeyframe(time: editorState.playhead, value: value, interpolation: .linear)
App/AEAuxiliaryPanels.swift:102:        let frameDuration = RationalTime(value: Int64(frameRate.timescale), timescale: Int32(frameRate.value))
App/AEAuxiliaryPanels.swift:104:            let delta = RationalTime(value: frameDuration.value * frames, timescale: frameDuration.timescale)
App/CompositionEffectResolverAdapter.swift:23:                exactTime: request.exactSourceTime,
App/CompositionEffectResolverAdapter.swift:52:                time: request.exactCompositionTime.description,
App/TrackingStudioView.swift:387:        let frameDuration = RationalTime(
App/TrackingStudioView.swift:391:        let trackingEnd: RationalTime
App/TrackingStudioView.swift:405:            startTime: layer.timing.inPoint,
App/TrackingStudioView.swift:406:            endTime: trackingEnd,
App/TrackingStudioView.swift:411:        let sourceTimes: [RationalTime]
App/TrackingStudioView.swift:414:            let compositionTimes = try request.sampleTimes()
App/TrackingStudioView.swift:417:                compositionTimes: compositionTimes
App/TrackingStudioView.swift:485:                referenceTime: referenceSample.time,
App/TrackingStudioView.swift:500:        let refinement = ProjectRotoscopeRefinement(time: nearest.time, path: path(for: normalizedRegion))
App/CompositionExportController.swift:89:                                time: time,
App/CompositionPreviewController.swift:26:    @Published private(set) var exactTime: RationalTime = .zero
App/CompositionPreviewController.swift:65:    func currentTime(for composition: ProjectComposition) throws -> RationalTime {
App/CompositionPreviewController.swift:79:    func render(project: ProjectDocument, packageURL: URL?, at requestedTime: RationalTime) {
App/CompositionPreviewController.swift:117:                    time: time,
App/CompositionPreviewController.swift:189:    private func frameIndex(for time: RationalTime, composition: ProjectComposition) -> Int64 {
App/CompositionPreviewController.swift:195:    private func exactFrameTime(frameIndex: Int64, frameRate: RationalTime) throws -> RationalTime {
App/CompositionPreviewController.swift:203:        return RationalTime(value: numerator.partialValue, timescale: Int32(frameRate.value))
App/ProjectWorkspaceViewModel+Tracking.swift:62:        referenceTime: RationalTime,
App/ProjectWorkspaceViewModel+Tracking.swift:81:            referenceTime: referenceTime,
App/CompositionMediaFrameResolver.swift:24:        exactSourceTime: RationalTime,
App/CompositionMediaFrameResolver.swift:29:            exactSourceTime: exactSourceTime,
App/CompositionMediaFrameResolver.swift:37:        exactSourceTime: RationalTime,
App/CompositionMediaFrameResolver.swift:49:                let request = try VideoFrameRequest(time: exactSourceTime, targetSize: targetSize, tolerance: .exact)
App/CompositionMediaFrameResolver.swift:54:                let frameIndex = try floorFrameIndex(time: exactSourceTime, frameDuration: frameDuration)
App/CompositionMediaFrameResolver.swift:60:                    let request = try VideoFrameRequest(time: leftTime, targetSize: targetSize, tolerance: .exact)
App/CompositionMediaFrameResolver.swift:63:                let leftRequest = try VideoFrameRequest(time: leftTime, targetSize: targetSize, tolerance: .exact)
App/CompositionMediaFrameResolver.swift:64:                let rightRequest = try VideoFrameRequest(time: rightTime, targetSize: targetSize, tolerance: .exact)
App/CompositionMediaFrameResolver.swift:106:    private func exactFrameDuration(url: URL) async throws -> RationalTime {
App/CompositionMediaFrameResolver.swift:122:        return RationalTime(value: duration.value, timescale: duration.timescale)
App/CompositionMediaFrameResolver.swift:125:    private func floorFrameIndex(time: RationalTime, frameDuration: RationalTime) throws -> Int64 {
App/CompositionMediaFrameResolver.swift:135:    private func multiply(_ time: RationalTime, by value: Int64) throws -> RationalTime {
App/CompositionMediaFrameResolver.swift:140:        return RationalTime(value: product.partialValue, timescale: time.timescale)
App/AIEffectBakeCoordinator.swift:164:            source: .media(mediaID: embedded.id, sourceStartTime: .zero),
App/ExportWorkspaceView.swift:288:        let customRate: RationalTime?
App/ExportWorkspaceView.swift:295:            customRate = RationalTime(value: numerator, timescale: timescale)
App/GraphEditorView.swift:185:    private func xPosition(_ time: RationalTime, width: CGFloat) -> CGFloat {
App/MediaImportViewModel.swift:63:                        let frameTime = RationalTime(
App/MediaImportViewModel.swift:68:                            time: frameTime,
App/ProjectWorkspaceViewModel+GeneratedGraphics.swift:29:                            source: .media(mediaID: imported.id, sourceStartTime: .zero),
App/ProjectWorkspaceViewModel+GeneratedGraphics.swift:30:                            timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration)
App/RenderLabViewModel.swift:215:            let request = try RenderRequest(graph: graph, time: .zero, output: output)
App/NewCompositionView.swift:33:    func rational(customText: String) throws -> RationalTime {
App/NewCompositionView.swift:35:        case .fps23976: return RationalTime(value: 24_000, timescale: 1_001)
App/NewCompositionView.swift:36:        case .fps24: return RationalTime(value: 24, timescale: 1)
App/NewCompositionView.swift:37:        case .fps25: return RationalTime(value: 25, timescale: 1)
App/NewCompositionView.swift:38:        case .fps2997: return RationalTime(value: 30_000, timescale: 1_001)
App/NewCompositionView.swift:39:        case .fps30: return RationalTime(value: 30, timescale: 1)
App/NewCompositionView.swift:40:        case .fps50: return RationalTime(value: 50, timescale: 1)
App/NewCompositionView.swift:41:        case .fps5994: return RationalTime(value: 60_000, timescale: 1_001)
App/NewCompositionView.swift:42:        case .fps60: return RationalTime(value: 60, timescale: 1)
App/NewCompositionView.swift:55:            return RationalTime(value: numerator, timescale: denominator)
App/NewCompositionView.swift:107:        case .invalidStartTime: "Start time must be finite."
App/NewCompositionView.swift:198:            displayStartTime: startTime,
App/NewCompositionView.swift:208:    private func exactFrameTime(seconds: Double, frameRate: RationalTime) throws -> RationalTime {
App/NewCompositionView.swift:219:        return RationalTime(value: numerator.partialValue, timescale: Int32(frameRate.value))
App/EditorWorkspaceState.swift:26:    @Published var playhead: RationalTime = .zero
App/EditorWorkspaceState.swift:107:    func setPlayhead(_ time: RationalTime, composition: ProjectComposition) {
App/EditorWorkspaceState.swift:124:        playhead = RationalTime(
