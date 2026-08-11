import Foundation
import Testing
@testable import Vertex

@Test func focusMusicCatalogHasDistinctOriginalWorkTracks() {
    let tracks = FocusMusicTrack.allCases
    #expect(tracks.count == 6)
    #expect(Set(tracks.map(\.rawValue)).count == tracks.count)
    #expect(Set(tracks.map(\.title)).count == tracks.count)
    #expect(tracks.allSatisfy { (55...85).contains($0.bpm) })
}

@Test func focusMusicSynthesizerProducesPlayablePCMContainer() {
    let data = FocusMusicSynthesizer.render(track: .deepFocus)
    #expect(data.count > 44)
    #expect(String(data: data.prefix(4), encoding: .ascii) == "RIFF")
    #expect(String(data: data.dropFirst(8).prefix(4), encoding: .ascii) == "WAVE")
}

@MainActor
@Test func focusMusicPreferencesPersistWithoutEnteringProjectAudio() {
    let suiteName = "FocusMusicTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Could not create isolated Focus Music defaults.")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let player = FocusMusicPlayer(defaults: defaults)
    player.select(.warmKeyframes)
    player.setVolume(0.41)

    let restored = FocusMusicPlayer(defaults: defaults)
    #expect(restored.selectedTrack == .warmKeyframes)
    #expect(abs(restored.volume - 0.41) < 0.0001)
    #expect(restored.isPlaying == false)
}
