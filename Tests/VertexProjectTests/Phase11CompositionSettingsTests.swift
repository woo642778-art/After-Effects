import Foundation
import Testing
import VertexCore
@testable import VertexProject

@Test("Phase 11 composition settings round-trip through canonical Codable state")
func phase11CompositionSettingsRoundTrip() throws {
    let composition = ProjectComposition(
        id: VertexID(rawValue: "b1000000-0000-0000-0000-000000000001"),
        name: "Comp 1",
        width: 1920,
        height: 1080,
        duration: RationalTime(value: 300, timescale: 30),
        frameRate: RationalTime(value: 30, timescale: 1),
        color: .rec709SDR(alphaMode: .straight),
        backgroundColor: ProjectRGBAColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1),
        layerIDs: [],
        displayStartTime: RationalTime(value: 30, timescale: 30),
        pixelAspectRatio: 1,
        previewResolution: .half,
        bpm: 128,
        motionBlurShutterAngle: 180,
        motionBlurShutterPhase: -90,
        rendererMode: .classic2D
    )

    let encoded = try JSONEncoder().encode(composition)
    let decoded = try JSONDecoder().decode(ProjectComposition.self, from: encoded)

    #expect(decoded == composition)
    #expect(decoded.displayStartTime == RationalTime(value: 1, timescale: 1))
    #expect(decoded.previewResolution == .half)
    #expect(decoded.bpm == 128)
    #expect(decoded.motionBlurShutterAngle == 180)
    #expect(decoded.motionBlurShutterPhase == -90)
}

@Test("Legacy composition JSON decodes Phase 11 settings with safe defaults")
func legacyCompositionGetsPhase11Defaults() throws {
    let legacy = #"{"backgroundColor":{"alpha":0,"blue":0,"green":0,"red":0},"color":{"alphaMode":"straight","colorSpace":{"named":"rec709"},"transferFunction":"sRGB"},"duration":{"timescale":1,"value":10},"frameRate":{"timescale":1,"value":30},"height":1080,"id":{"rawValue":"b1000000-0000-0000-0000-000000000002"},"layerIDs":[],"markers":[],"name":"Legacy","width":1920}"#

    let decoded = try JSONDecoder().decode(ProjectComposition.self, from: Data(legacy.utf8))

    #expect(decoded.displayStartTime == .zero)
    #expect(decoded.pixelAspectRatio == 1)
    #expect(decoded.previewResolution == .full)
    #expect(decoded.bpm == nil)
    #expect(decoded.motionBlurShutterAngle == 180)
    #expect(decoded.motionBlurShutterPhase == -90)
    #expect(decoded.rendererMode == .classic2D)
}

@Test("Phase 11 composition settings reject invalid BPM and pixel aspect")
func phase11CompositionSettingsValidateRanges() throws {
    let base = ProjectComposition(
        name: "Invalid",
        width: 1920,
        height: 1080,
        duration: RationalTime(value: 10, timescale: 1),
        frameRate: RationalTime(value: 30, timescale: 1),
        color: .rec709SDR(alphaMode: .straight)
    )

    var badBPM = base
    badBPM.bpm = 0
    #expect(throws: ProjectError.self) {
        _ = try badBPM.validated(layerByID: [:])
    }

    var badPixelAspect = base
    badPixelAspect.pixelAspectRatio = 0
    #expect(throws: ProjectError.self) {
        _ = try badPixelAspect.validated(layerByID: [:])
    }
}
