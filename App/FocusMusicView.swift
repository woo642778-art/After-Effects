import SwiftUI

struct FocusMusicView: View {
    @EnvironmentObject private var player: FocusMusicPlayer

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AfterEffectsTheme.border)
            transport
            Divider().overlay(AfterEffectsTheme.border)
            trackList
            Divider().overlay(AfterEffectsTheme.border)
            footer
        }
        .frame(width: 340, height: 430)
        .background(AfterEffectsTheme.panel)
        .foregroundStyle(AfterEffectsTheme.primaryText)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(AfterEffectsTheme.selection)
                    .frame(width: 38, height: 38)
                Image(systemName: "music.note")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AfterEffectsTheme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Music")
                    .font(.subheadline.weight(.semibold))
                Text("Original offline music for long editing sessions")
                    .font(.system(size: 9))
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
            }
            Spacer()
            if player.isPreparing {
                ProgressView().controlSize(.small)
            } else if player.isPlaying {
                Text("PLAYING")
                    .font(.system(size: 8, weight: .bold).monospaced())
                    .foregroundStyle(AfterEffectsTheme.accent)
            }
        }
        .padding(12)
    }

    private var transport: some View {
        VStack(spacing: 12) {
            VStack(spacing: 3) {
                Text(player.selectedTrack.title)
                    .font(.callout.weight(.semibold))
                Text("\(player.selectedTrack.subtitle) • \(player.selectedTrack.bpm) BPM")
                    .font(.system(size: 9))
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
            }

            HStack(spacing: 22) {
                Button(action: player.selectPrevious) {
                    Image(systemName: "backward.fill")
                }
                .help("Previous focus track")

                Button(action: player.togglePlayback) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(AfterEffectsTheme.selection, in: Circle())
                }
                .disabled(player.isPreparing)
                .help(player.isPlaying ? "Pause Focus Music" : "Play Focus Music")

                Button(action: player.selectNext) {
                    Image(systemName: "forward.fill")
                }
                .help("Next focus track")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AfterEffectsTheme.primaryText)

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1.fill")
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
                Slider(
                    value: Binding(
                        get: { player.volume },
                        set: { player.setVolume($0) }
                    ),
                    in: 0...0.8
                )
                .accessibilityLabel("Focus Music volume")
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var trackList: some View {
        ScrollView {
            LazyVStack(spacing: 3) {
                ForEach(FocusMusicTrack.allCases) { track in
                    Button { player.select(track) } label: {
                        HStack(spacing: 9) {
                            Image(systemName: player.selectedTrack == track ? "waveform.circle.fill" : "music.note.list")
                                .font(.system(size: 13))
                                .foregroundStyle(player.selectedTrack == track ? AfterEffectsTheme.accent : AfterEffectsTheme.secondaryText)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AfterEffectsTheme.primaryText)
                                Text("\(track.subtitle) • \(track.bpm) BPM")
                                    .font(.system(size: 8))
                                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
                            }
                            Spacer(minLength: 8)
                            if player.selectedTrack == track {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(AfterEffectsTheme.accent)
                            }
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 42)
                        .background(
                            player.selectedTrack == track ? AfterEffectsTheme.selection.opacity(0.72) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Music keeps playing while you work anywhere in Vertex2.", systemImage: "arrow.triangle.2.circlepath")
            Label("Focus Music is separate from timeline audio and is never exported.", systemImage: "square.and.arrow.up")
            if let errorMessage = player.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.system(size: 8))
        .foregroundStyle(AfterEffectsTheme.tertiaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AfterEffectsTheme.elevatedPanel)
    }
}
