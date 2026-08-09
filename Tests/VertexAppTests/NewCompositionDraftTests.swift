import Foundation
import Testing
import VertexCore
import VertexProject
@testable import Vertex

@Test func newCompositionDraftBuildsExact2997FrameTiming() throws {
    var draft = NewCompositionDraft()
    draft.name = "Timing"
    draft.width = 1920
    draft.height = 1080
    draft.frameRateChoice = .fps2997
    draft.durationSeconds = 10
    draft.displayStartSeconds = 1
    draft.bpmText = "120"

    let composition = try draft.makeComposition(
        color: .rec709SDR(alphaMode: .straight),
        backgroundColor: .transparent
    )

    #expect(composition.frameRate == RationalTime(value: 30_000, timescale: 1_001))
    #expect(composition.duration == RationalTime(value: 300_300, timescale: 30_000))
    #expect(composition.displayStartTime == RationalTime(value: 30_030, timescale: 30_000))
    #expect(composition.bpm == 120)
}

@Test func newCompositionDraftAppliesUHD5994Preset() throws {
    var draft = NewCompositionDraft()
    draft.apply(.uhd4K5994)

    #expect(draft.width == 3840)
    #expect(draft.height == 2160)
    #expect(draft.frameRateChoice == .fps5994)
}

@Test func newCompositionDraftRejectsInvalidCustomFrameRate() {
    var draft = NewCompositionDraft()
    draft.frameRateChoice = .custom
    draft.customFrameRateText = "0"

    #expect(throws: NewCompositionDraftError.self) {
        _ = try draft.makeComposition(
            color: .rec709SDR(alphaMode: .straight),
            backgroundColor: .transparent
        )
    }
}

@Test func phase11CompositionSupportsUHD8K5994Preset() {
    var draft = NewCompositionDraft()
    draft.apply(.uhd8K5994)

    #expect(draft.width == 7680)
    #expect(draft.height == 4320)
    #expect(draft.frameRateChoice == .fps5994)
}

@Test func phase11CompositionSupportsDCI8KCustomAndPixelAspect() throws {
    var draft = NewCompositionDraft()
    draft.preset = .custom
    draft.width = 8192
    draft.height = 4320
    draft.frameRateChoice = .fps60
    draft.pixelAspectRatio = 1.5

    let composition = try draft.makeComposition(
        color: .rec709SDR(alphaMode: .straight),
        backgroundColor: .transparent
    )

    #expect(composition.width == 8192)
    #expect(composition.height == 4320)
    #expect(composition.pixelAspectRatio == 1.5)
}
