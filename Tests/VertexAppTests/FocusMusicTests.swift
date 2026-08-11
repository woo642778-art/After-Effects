import AVFoundation
import Foundation
import Testing
@testable import Vertex

@Test func focusMusicCatalogHasManyDistinctOriginalWorkTracks() {
    let tracks = FocusMusicTrack.allCases
    #expect(tracks.count >= 30)
    #expect(Set(tracks.map(\.rawValue)).count == tracks.count)
    #expect(Set(tracks.map(\.title)).count == tracks.count)
    #expect(tracks.allSatisfy { (50...100).contains($0.bpm) })
}

@Test func focusMusicSynthesizerProducesPlayableNonSilentPCMContainer() {
    for track in FocusMusicTrack.allCases {
        let data = FocusMusicSynthesizer.render(track: track)
        #expect(data.count > 44)
        #expect(String(data: data.prefix(4), encoding: .ascii) == "RIFF")
        #expect(String(data: data.dropFirst(8).prefix(4), encoding: .ascii) == "WAVE")

        let pcm = data.dropFirst(44)
        var peak = 0
        var index = pcm.startIndex
        while index < pcm.endIndex {
            let next = pcm.index(after: index)
            guard next < pcm.endIndex else { break }
            let low = UInt16(pcm[index])
            let high = UInt16(pcm[next]) << 8
            let sample = Int(Int16(bitPattern: low | high))
            peak = max(peak, abs(sample))
            index = pcm.index(index, offsetBy: 2)
        }
        #expect(peak > 512, "\(track.rawValue) rendered effectively silent PCM")
    }
}

@Test func focusMusicUsesAudiblePlaybackSessionPolicy() {
    #expect(FocusMusicPlayer.audioSessionCategory == .playback)
    #expect(FocusMusicPlayer.audioSessionOptions.contains(.mixWithOthers))
}

private final class RefusingFocusPlayback: FocusMusicPlaybackStarting {
    func play() -> Bool { false }
}

@MainActor
@Test func focusMusicDoesNotClaimPlaybackWhenEngineRefusesToStart() {
    let suiteName = "FocusMusicStartTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Could not create isolated Focus Music defaults.")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let player = FocusMusicPlayer(defaults: defaults)
    let started = player.startPlaybackForTesting(RefusingFocusPlayback())
    #expect(started == false)
    #expect(player.isPlaying == false)
    #expect(player.errorMessage != nil)
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
