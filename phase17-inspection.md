# Phase17 inspection

## Focus/music references
App/FocusMusicPlayer.swift:7:enum FocusMusicTrack: String, CaseIterable, Identifiable, Sendable {
App/FocusMusicPlayer.swift:41:    fileprivate var configuration: FocusMusicConfiguration {
App/FocusMusicPlayer.swift:44:            FocusMusicConfiguration(rootMIDI: 50, progression: [0, 5, 3, 7], chordIntervals: [0, 3, 7, 10], bpm: 72, brightness: 0.16, air: 0.0018, pluck: 0.050, phase: 0.1)
App/FocusMusicPlayer.swift:46:            FocusMusicConfiguration(rootMIDI: 45, progression: [0, 3, 7, 5], chordIntervals: [0, 3, 7, 10], bpm: 64, brightness: 0.08, air: 0.0010, pluck: 0.032, phase: 1.3)
App/FocusMusicPlayer.swift:48:            FocusMusicConfiguration(rootMIDI: 48, progression: [0, 7, 5, 3], chordIntervals: [0, 4, 7, 11], bpm: 68, brightness: 0.13, air: 0.0042, pluck: 0.040, phase: 2.4)
App/FocusMusicPlayer.swift:50:            FocusMusicConfiguration(rootMIDI: 53, progression: [0, 4, 9, 5], chordIntervals: [0, 4, 7, 11], bpm: 76, brightness: 0.20, air: 0.0015, pluck: 0.057, phase: 0.7)
App/FocusMusicPlayer.swift:52:            FocusMusicConfiguration(rootMIDI: 47, progression: [0, 5, 8, 3], chordIntervals: [0, 3, 7, 10], bpm: 80, brightness: 0.24, air: 0.0012, pluck: 0.060, phase: 1.9)
App/FocusMusicPlayer.swift:54:            FocusMusicConfiguration(rootMIDI: 43, progression: [0, 5, 2, 7], chordIntervals: [0, 3, 7, 10], bpm: 60, brightness: 0.05, air: 0.0007, pluck: 0.020, phase: 2.9)
App/FocusMusicPlayer.swift:59:private struct FocusMusicConfiguration: Sendable {
App/FocusMusicPlayer.swift:70:/// Small deterministic synthesizer used instead of bundled copyrighted songs.
App/FocusMusicPlayer.swift:71:/// It creates one PCM loop on a utility task, then AVAudioPlayer loops that
App/FocusMusicPlayer.swift:73:enum FocusMusicSynthesizer {
App/FocusMusicPlayer.swift:77:    static func render(track: FocusMusicTrack) -> Data {
App/FocusMusicPlayer.swift:196:final class FocusMusicPlayer: ObservableObject {
App/FocusMusicPlayer.swift:198:        static let track = "vertex.focusMusic.track.v1"
App/FocusMusicPlayer.swift:199:        static let volume = "vertex.focusMusic.volume.v1"
App/FocusMusicPlayer.swift:202:    @Published private(set) var selectedTrack: FocusMusicTrack
App/FocusMusicPlayer.swift:208:    private var audioPlayer: AVAudioPlayer?
App/FocusMusicPlayer.swift:209:    private var loadedTrack: FocusMusicTrack?
App/FocusMusicPlayer.swift:215:        selectedTrack = FocusMusicTrack(rawValue: defaults.string(forKey: DefaultsKey.track) ?? "") ?? .quietDesk
App/FocusMusicPlayer.swift:225:            audioPlayer?.pause()
App/FocusMusicPlayer.swift:229:        if loadedTrack == selectedTrack, let audioPlayer {
App/FocusMusicPlayer.swift:232:                audioPlayer.volume = Float(volume)
App/FocusMusicPlayer.swift:233:                audioPlayer.play()
App/FocusMusicPlayer.swift:244:    func select(_ track: FocusMusicTrack) {
App/FocusMusicPlayer.swift:250:            audioPlayer?.stop()
App/FocusMusicPlayer.swift:257:        let tracks = FocusMusicTrack.allCases
App/FocusMusicPlayer.swift:263:        let tracks = FocusMusicTrack.allCases
App/FocusMusicPlayer.swift:270:        audioPlayer?.volume = Float(volume)
App/FocusMusicPlayer.swift:274:    private func prepare(track: FocusMusicTrack, autoPlay: Bool) {
App/FocusMusicPlayer.swift:282:                FocusMusicSynthesizer.render(track: track)
App/FocusMusicPlayer.swift:286:                let player = try AVAudioPlayer(data: data)
App/FocusMusicPlayer.swift:290:                self.audioPlayer?.stop()
App/FocusMusicPlayer.swift:291:                self.audioPlayer = player
App/FocusMusicPlayer.swift:308:        let session = AVAudioSession.sharedInstance()
App/FocusMusicPlayer.swift:309:        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
App/FocusMusicView.swift:3:struct FocusMusicView: View {
App/FocusMusicView.swift:4:    @EnvironmentObject private var player: FocusMusicPlayer
App/FocusMusicView.swift:27:                Image(systemName: "music.note")
App/FocusMusicView.swift:32:                Text("Focus Music")
App/FocusMusicView.swift:34:                Text("Original offline music for long editing sessions")
App/FocusMusicView.swift:73:                .help(player.isPlaying ? "Pause Focus Music" : "Play Focus Music")
App/FocusMusicView.swift:94:                .accessibilityLabel("Focus Music volume")
App/FocusMusicView.swift:107:                ForEach(FocusMusicTrack.allCases) { track in
App/FocusMusicView.swift:110:                            Image(systemName: player.selectedTrack == track ? "waveform.circle.fill" : "music.note.list")
App/FocusMusicView.swift:146:            Label("Music keeps playing while you work anywhere in Vertex2.", systemImage: "arrow.triangle.2.circlepath")
App/FocusMusicView.swift:147:            Label("Focus Music is separate from timeline audio and is never exported.", systemImage: "square.and.arrow.up")
App/VertexApp.swift:6:    @StateObject private var focusMusic: FocusMusicPlayer
App/VertexApp.swift:12:        _focusMusic = StateObject(wrappedValue: FocusMusicPlayer())
App/VertexApp.swift:32:            .environmentObject(focusMusic)
App/AEWorkspaceChrome.swift:53:    @EnvironmentObject private var focusMusic: FocusMusicPlayer
App/AEWorkspaceChrome.swift:55:    @State private var isFocusMusicPresented = false
App/AEWorkspaceChrome.swift:88:            Button { isFocusMusicPresented.toggle() } label: {
App/AEWorkspaceChrome.swift:89:                Image(systemName: focusMusic.isPlaying ? "music.note.list" : "music.note")
App/AEWorkspaceChrome.swift:91:            .buttonStyle(AEToolButtonStyle(isActive: focusMusic.isPlaying))
App/AEWorkspaceChrome.swift:92:            .help("Focus Music")
App/AEWorkspaceChrome.swift:93:            .popover(isPresented: $isFocusMusicPresented, arrowEdge: .top) {
App/AEWorkspaceChrome.swift:94:                FocusMusicView()
Sources/Vertex3D/Scene3DTypes.swift:128:    case ambient
Sources/VertexProject/EffectIndexedCatalogShard2.generated.swift:53:Boris FX Continuum|BCC Lights|BCC+ Ambient Light
Tests/VertexAppTests/FocusMusicTests.swift:5:@Test func focusMusicCatalogHasDistinctOriginalWorkTracks() {
Tests/VertexAppTests/FocusMusicTests.swift:6:    let tracks = FocusMusicTrack.allCases
Tests/VertexAppTests/FocusMusicTests.swift:13:@Test func focusMusicSynthesizerProducesPlayablePCMContainer() {
Tests/VertexAppTests/FocusMusicTests.swift:14:    let data = FocusMusicSynthesizer.render(track: .deepFocus)
Tests/VertexAppTests/FocusMusicTests.swift:21:@Test func focusMusicPreferencesPersistWithoutEnteringProjectAudio() {
Tests/VertexAppTests/FocusMusicTests.swift:22:    let suiteName = "FocusMusicTests.\(UUID().uuidString)"
Tests/VertexAppTests/FocusMusicTests.swift:24:        Issue.record("Could not create isolated Focus Music defaults.")
Tests/VertexAppTests/FocusMusicTests.swift:29:    let player = FocusMusicPlayer(defaults: defaults)
Tests/VertexAppTests/FocusMusicTests.swift:33:    let restored = FocusMusicPlayer(defaults: defaults)
Documentation/V16_RELEASE_NOTES.md:3:Vertex2 16 expands the effects system, adds advanced deterministic pre-compose operations, reduces interactive effect-control stalls, and introduces persistent offline Focus Music for long editing sessions while preserving the full-quality preview/export contract.
Documentation/V16_RELEASE_NOTES.md:40:## Focus Music
Documentation/V16_RELEASE_NOTES.md:42:- Added six original Vertex2-generated ambient/lo-fi instrumental tracks: Quiet Desk, Midnight Render, Rainy Timeline, Warm Keyframes, Soft Circuit, and Deep Focus.
Documentation/V16_RELEASE_NOTES.md:43:- Focus Music is offline and does not require streaming, a server, or copyrighted commercial songs.
Documentation/V16_RELEASE_NOTES.md:45:- Users can choose tracks, play/pause, move to previous/next tracks, and adjust a dedicated Focus Music volume.
Documentation/V16_RELEASE_NOTES.md:47:- Music is generated once into PCM and looped by the audio player, avoiding a continuous synthesis workload during editing.
Documentation/V16_RELEASE_NOTES.md:48:- Focus Music is deliberately separate from project/timeline audio and is never included in project exports.
docs/superpowers/plans/2026-08-08-vertex2-11-ae-parity-time-engine.md:9:**Tech Stack:** Swift 6, SwiftUI, UIKit document/file APIs, Swift Package Manager, XcodeGen, Metal/MetalKit, AVFoundation, Vision + Metal for optical-flow synthesis, AVAudioEngine/AVAudioUnitTimePitch/AVAudioUnitVarispeed for audio retiming, Core ML for inherited AI effects, exact `RationalTime`, GitHub Actions.
docs/superpowers/plans/2026-08-08-vertex2-11-ae-parity-time-engine.md:430:Use `AVAudioUnitTimePitch` for preserve-pitch time stretch and `AVAudioUnitVarispeed` for pitch-following playback. `AudioTimeStretchRequest` is derived from the same `ProjectTimeRemap` used for video. Tests compare output duration/timestamps against the mapped video duration.

## Audio-like files

## V17 / particles / procedural references
Documentation/ROADMAP_7_TO_26.md:26:5. Add particles, nodes, AI, asset infrastructure, and 3D.
Documentation/ROADMAP_7_TO_26.md:80:The exact Swift API is determined during the Phase 7 design, but animation cannot be hard-coded only for transforms. Later effects, masks, text, lights, particles, color controls, and other properties must be able to reuse the same channel/keyframe engine.
Documentation/ROADMAP_7_TO_26.md:326:## 17.0.0 — Particles and Procedural Graphics
Documentation/ROADMAP_7_TO_26.md:334:- GPU particle system.
Documentation/ROADMAP_7_TO_26.md:336:- Particle lifetime and birth controls.
Documentation/ROADMAP_7_TO_26.md:342:- Sprite and procedural particle rendering.
Documentation/ROADMAP_7_TO_26.md:344:- Procedural generators.
Documentation/PHASE_5_COMPLETION.md:68:Phase 5 does not implement layers/compositions, continuous playback, timeline editing, video export, effects, motion keyframes, retiming, masks, tracking, AI cutout, shapes, text animation, professional color/audio, particles, nodes, or 3D.
Documentation/PHASE_4_COMPLETION.md:85:Not implemented: continuous playback, timeline editing, multilayer composition, video export, project persistence, general effects, keyframes, retiming, masks, tracking, AI cutout, shapes, text animation, professional color/audio, particles, nodes, or 3D.
Documentation/PROJECT_PERSISTENCE_ARCHITECTURE.md:153:Phase 5 does not claim layers/compositions, continuous playback, timeline editing, video export, motion keyframes, retiming, masks, tracking, AI cutout, shape or text animation, professional color/audio, particles, node compositing, or 3D.
Documentation/GPU_SOURCE_AUDIT.md:21:MetalPetal demonstrates mature separation between image descriptions, kernels, render context, and output. Its effect catalog and texture-management work remain important references for Phase 17 and later performance phases.
Documentation/WORK_LOG.md:178:Media selection, inspection, thumbnail decoding, waveform extraction, branding, startup, and first-run Telegram behavior are real. The app does not yet provide playback, timeline editing, multilayer rendering, video export, effects, motion, retiming, masks, tracking, AI cutout, shape tools, text animation, color grading, audio effects, particles, node compositing, or 3D.
Documentation/HANDOFF.md:87:- Do not claim continuous playback, video export, motion, tracking, AI, text/shape engines, professional color/audio, particles, nodes, or 3D until implemented and tested.
Documentation/GPU_RENDER_GRAPH_ARCHITECTURE.md:128:Phase 4 does not implement continuous video playback, temporal effects, multilayer composition, video export, render caching, masks, motion blur, HDR grading, shape rasterization, text, tracking, AI, particles, node editing, or 3D.
Documentation/PRODUCT_VISION.md:12:- Node Video's procedural power without forcing every user into a difficult node-only workflow.
Documentation/ROADMAP_28_PHASES.md:26:| 17 | 17.0.0 | Particles and procedural graphics | Deterministic GPU particles, emitters, forces, turbulence, trails, procedural/noise generators |
docs/superpowers/plans/2026-08-08-vertex2-11-ae-parity-time-engine.md:534:- **Truthfulness:** Unsupported future Color/Expression/Tracking/Paint/Particle/advanced 3D roadmap features are not represented as completed 11.0 functionality.
docs/superpowers/specs/2026-08-05-phase-5-project-persistence-design.md:9:Phase 5 implements project persistence, command history, recovery, migration, and media relinking. It does not implement a timeline, layer compositor, continuous playback, video export, general effects, motion, tracking, AI cutout, shape or text animation, professional color or audio tools, particles, nodes, or 3D.
docs/superpowers/specs/2026-08-05-phase-5-project-persistence-design.md:420:Phase 5 does not claim timeline editing, layers, compositions with rendered contents, continuous playback, video export, general effect stacks, animation channels, masks, tracking, AI segmentation, vector shapes, text motion, color grading, audio processing, particles, node compositing, or 3D.
docs/superpowers/specs/2026-08-08-vertex2-11-ae-parity-time-engine-design.md:14:11.0 must not ship fake controls. A control is present only when its data path is real or when it is an explicitly informative state such as unavailable/unsupported. Future Color, Expression, Tracking, Paint, Particle, and later roadmap engines stay scheduled for later releases instead of being represented as working 11.0 functionality.
docs/superpowers/specs/2026-08-08-vertex2-11-ae-parity-time-engine-design.md:359:- universal tracking, advanced matte/keying, content-aware paint/inpainting, particle/simulation systems
Sources/VertexProject/EffectIndexedCatalogShard6.generated.swift:96:Boris FX workflow tools|Silhouette tools/nodes|Silhouette - Particle Illusion Integration
Sources/VertexProject/EffectIndexedCatalogShard3.generated.swift:8:Boris FX Continuum|BCC Transitions|BCC Particle Illusion Dissolve
Sources/VertexProject/EffectIndexedCatalogShard3.generated.swift:97:BCC obsolete / legacy|Legacy / obsolete|BCC Particle System
Sources/VertexProject/ProjectEffectExpansionDescriptors.swift:118:        descriptor(.vertexFilmGrain, "Vertex Film Grain", .stylize, keywords: ["vertex", "film", "grain", "noise"], summary: "Vertex-owned procedural film-grain treatment generated locally without bundled third-party assets.", parameters: [scalar(ExpandedEffectParameterID.amount, "Amount", 0.12, 0.0...1.0), scalar(ExpandedEffectParameterID.size, "Size", 1.0, 1.0...8.0), scalar(ExpandedEffectParameterID.chroma, "Chroma", 0.15, 0.0...1.0)]),
Sources/VertexProject/ProjectEffectExpansionDescriptors.swift:119:        descriptor(.vertexScanlines, "Vertex Scanlines", .stylize, keywords: ["vertex", "scanline", "crt", "retro"], summary: "Vertex-owned procedural scanline overlay for CRT and display treatments.", parameters: [scalar(ExpandedEffectParameterID.frequency, "Frequency", 2.0, 1.0...40.0), scalar(ExpandedEffectParameterID.intensity, "Intensity", 0.25, 0.0...1.0), scalar(ExpandedEffectParameterID.angle, "Angle", 0.0, -180.0...180.0)]),
Sources/VertexProject/ProjectEffectExpansionDescriptors.swift:122:        descriptor(.vertexLightLeak, "Vertex Light Leak", .stylize, keywords: ["vertex", "light leak", "film", "flare"], summary: "Vertex-owned procedural radial light leak generated from Core Image gradients.", parameters: [scalar(ExpandedEffectParameterID.centerX, "Center X", 0.2, 0.0...1.0), scalar(ExpandedEffectParameterID.centerY, "Center Y", 0.8, 0.0...1.0), scalar(ExpandedEffectParameterID.radius, "Radius", 500.0, 1.0...3000.0), scalar(ExpandedEffectParameterID.intensity, "Intensity", 0.7, 0.0...2.0)]),
Sources/VertexProject/ProjectEffectExpansionDescriptors.swift:123:        descriptor(.vertexSunRays, "Vertex Sun Rays", .stylize, keywords: ["vertex", "sun", "rays", "beams"], summary: "Vertex-owned light-ray composite using a procedural generator cropped to the source frame.", parameters: [scalar(ExpandedEffectParameterID.centerX, "Center X", 0.5, 0.0...1.0), scalar(ExpandedEffectParameterID.centerY, "Center Y", 0.5, 0.0...1.0), scalar(ExpandedEffectParameterID.intensity, "Intensity", 0.8, 0.0...2.0), scalar(ExpandedEffectParameterID.radius, "Radius", 120.0, 1.0...1000.0)]),
Sources/VertexProject/EffectIndexedCatalogShard2.generated.swift:96:Boris FX Continuum|BCC Particles|BCC 2D Particles
Sources/VertexProject/EffectIndexedCatalogShard2.generated.swift:97:Boris FX Continuum|BCC Particles|BCC Organic Strands
Sources/VertexProject/EffectIndexedCatalogShard2.generated.swift:98:Boris FX Continuum|BCC Particles|BCC Particle Array 3D
Sources/VertexProject/EffectIndexedCatalogShard2.generated.swift:99:Boris FX Continuum|BCC Particles|BCC Particle Emitter 3D
Sources/VertexProject/EffectIndexedCatalogShard2.generated.swift:100:Boris FX Continuum|BCC Particles|BCC Particle Illusion
Sources/VertexProject/EffectIndexedCatalogShard2.generated.swift:101:Boris FX Continuum|BCC Particles|BCC Pin Art 3D
Sources/VertexProject/EffectIndexedCatalogShard2.generated.swift:102:Boris FX Continuum|BCC Particles|BCC Rain
Sources/VertexProject/EffectIndexedCatalogShard2.generated.swift:103:Boris FX Continuum|BCC Particles|BCC Snow
Sources/VertexProject/EffectIndexedCatalogShard2.generated.swift:104:Boris FX Continuum|BCC Particles|BCC Wild Cards
Sources/VertexProject/EffectIndexedCatalogShard1.generated.swift:28:Adobe After Effects|Simulation|CC Particle Systems II
Sources/VertexProject/EffectIndexedCatalogShard1.generated.swift:29:Adobe After Effects|Simulation|CC Particle World
Sources/VertexProject/EffectIndexedCatalogShard1.generated.swift:36:Adobe After Effects|Simulation|Particle Playground
Sources/VertexProject/EffectIndexedCatalogShard5.generated.swift:96:Maxon Red Giant + Universe|RG Particles and 3D|Form
Sources/VertexProject/EffectIndexedCatalogShard5.generated.swift:97:Maxon Red Giant + Universe|RG Particles and 3D|Geo
Sources/VertexProject/EffectIndexedCatalogShard5.generated.swift:98:Maxon Red Giant + Universe|RG Particles and 3D|Horizon
Sources/VertexProject/EffectIndexedCatalogShard5.generated.swift:99:Maxon Red Giant + Universe|RG Particles and 3D|Lux
Sources/VertexProject/EffectIndexedCatalogShard5.generated.swift:100:Maxon Red Giant + Universe|RG Particles and 3D|Mir 3
Sources/VertexProject/EffectIndexedCatalogShard5.generated.swift:101:Maxon Red Giant + Universe|RG Particles and 3D|Tao
Sources/VertexProject/EffectIndexedCatalogShard5.generated.swift:102:Maxon Red Giant + Universe|RG Particles and 3D|Trapcode Particular

## Relevant filenames
App/AIEffectBakeCoordinator.swift
App/AIEffectControlsView.swift
App/AIFrameEffectService.swift
App/AfterEffectsTheme.swift
App/BundledAIEnvironment+FrameEffects.swift
App/CompositionEffectResolverAdapter.swift
App/EffectControlsView.swift
App/EffectsAndPresetsView.swift
App/FocusMusicPlayer.swift
App/FocusMusicView.swift
App/NativeExpandedFrameEffectProcessor.swift
App/NativeFrameEffectProcessor.swift
Documentation/ROADMAP_28_PHASES.md
Documentation/ROADMAP_7_TO_26.md
Sources/VertexAI/AIFrameEffectKey.swift
Sources/VertexAI/AIFrameEffectTypes.swift
Sources/VertexComposition/CompositionEffectResolver.swift
Sources/VertexComposition/EffectAnimationEvaluator.swift
Sources/VertexMediaAVFoundation/AVFoundationAudioWaveformProvider.swift
Sources/VertexProject/EffectCompatibilityAudit.swift
Sources/VertexProject/EffectIndexedCatalog.generated.swift
Sources/VertexProject/EffectIndexedCatalogShard0.generated.swift
Sources/VertexProject/EffectIndexedCatalogShard1.generated.swift
Sources/VertexProject/EffectIndexedCatalogShard2.generated.swift
Sources/VertexProject/EffectIndexedCatalogShard3.generated.swift
Sources/VertexProject/EffectIndexedCatalogShard4.generated.swift
Sources/VertexProject/EffectIndexedCatalogShard5.generated.swift
Sources/VertexProject/EffectIndexedCatalogShard6.generated.swift
Sources/VertexProject/EffectIndexedCatalogShard7.generated.swift
Sources/VertexProject/EffectPreviewUpdateGate.swift
Sources/VertexProject/ProjectEffect.swift
Sources/VertexProject/ProjectEffectDescriptor.swift
Sources/VertexProject/ProjectEffectExpansionDescriptors.swift
Tests/VertexAITests/AIFrameEffectKeyTests.swift
Tests/VertexAppTests/AIEffectBakeCoordinatorTests.swift
Tests/VertexAppTests/AIEffectFailureSemanticsTests.swift
Tests/VertexAppTests/AIFrameEffectServiceTests.swift
Tests/VertexAppTests/EffectControlsInteractionTests.swift
Tests/VertexAppTests/EffectsAndPresetsCatalogTests.swift
Tests/VertexAppTests/FocusMusicTests.swift
Tests/VertexAppTests/NativeExpandedEffectsRenderTests.swift
Tests/VertexCompositionTests/EffectGraphCompilerTests.swift
Tests/VertexCompositionTests/EffectPreviewExportParityTests.swift
Tests/VertexProjectTests/AIEffectBakeCommandTests.swift
Tests/VertexProjectTests/Phase12NativeEffectTests.swift
Tests/VertexProjectTests/Phase15EffectDescriptorTests.swift
Tests/VertexProjectTests/Phase16EffectsCatalogTests.swift
Tests/VertexProjectTests/Phase16ExecutableEffectsExpansionTests.swift
Tests/VertexProjectTests/ProjectEffectCommandTests.swift
Tests/VertexProjectTests/ProjectEffectTests.swift
docs/superpowers/plans/2026-08-07-phase-9-ae-workspace-ai-effects.md
docs/superpowers/plans/2026-08-11-native-effects-expansion.md
docs/superpowers/plans/2026-08-11-v15-effects-architecture.md
docs/superpowers/specs/2026-08-07-phase-9-ae-workspace-ai-effects-design.md
docs/superpowers/specs/2026-08-11-native-effects-expansion-design.md
docs/superpowers/specs/2026-08-11-v15-effects-architecture-design.md
