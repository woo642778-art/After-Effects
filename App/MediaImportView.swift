import SwiftUI
import UniformTypeIdentifiers
import UIKit
import VertexMedia

struct MediaImportView: View {
    @EnvironmentObject private var projectWorkspace: ProjectWorkspaceViewModel
    @StateObject private var viewModel = MediaImportViewModel()
    @State private var isImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MEDIA INPUT / OUTPUT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AfterEffectsTheme.accent)
                        .tracking(0.8)
                    Text("Real AVFoundation inspection · imported as a layer")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Spacer()

                Button {
                    isImporterPresented = true
                } label: {
                    Label("Select Media", systemImage: "film.stack")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(AfterEffectsTheme.accent)
            }

            content
        }
        .afterEffectsCard()
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                projectWorkspace.registerImportedMedia(from: url)
                viewModel.importMedia(from: url)
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError {
                    viewModel.presentImporterError(error)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            Text("Choose a local movie. It is inspected with AVFoundation and inserted as the highest layer in the active composition.")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)

        case .loading(let filename):
            HStack(spacing: 12) {
                ProgressView()
                    .tint(AfterEffectsTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Inspecting and registering media")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(filename)
                        .font(.caption.monospaced())
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                        .lineLimit(1)
                }
            }

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)

        case .loaded(let media):
            loadedContent(media)
        }
    }

    @ViewBuilder
    private func loadedContent(_ media: MediaImportViewModel.LoadedMedia) -> some View {
        if let thumbnail = media.thumbnail,
           let image = UIImage(data: thumbnail.data) {
            VStack(alignment: .leading, spacing: 6) {
                Text("DECODED SOURCE FRAME")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }

        Text(media.descriptor.filename)
            .font(.headline)
            .foregroundStyle(.white)

        let video = media.descriptor.videoStreams.first
        let audio = media.descriptor.audioStreams.first

        VStack(spacing: 8) {
            metadataRow("Duration", value: durationText(media.descriptor.duration.seconds))
            metadataRow("Container", value: media.descriptor.containerHint?.uppercased() ?? "Unknown")

            if let video {
                metadataRow(
                    "Video",
                    value: "\(Int(video.pixelSize.width)) × \(Int(video.pixelSize.height)) · \(video.codec.uppercased())"
                )
                metadataRow(
                    "Timing",
                    value: "\(video.nominalFrameRate.formatted(.number.precision(.fractionLength(0...3)))) fps · \(video.variableFrameRateStatus.rawValue.uppercased())"
                )
                metadataRow("Color", value: colorText(video))
            }

            if let audio {
                metadataRow(
                    "Audio",
                    value: "\(Int(audio.sampleRate)) Hz · \(audio.channelCount) ch · \(audio.codec.uppercased())"
                )
            }
        }

        if let waveform = media.waveform {
            WaveformView(waveform: waveform)
        } else if audio == nil {
            Text("No audio stream")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        }

        Label(
            "Registered in the project and added to the active composition layer stack",
            systemImage: "square.stack.3d.up.fill"
        )
        .font(.caption)
        .foregroundStyle(AfterEffectsTheme.secondaryText)
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }

    private func durationText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "Unknown" }
        let totalMilliseconds = Int((seconds * 1_000).rounded())
        let minutes = totalMilliseconds / 60_000
        let remainingSeconds = (totalMilliseconds % 60_000) / 1_000
        let milliseconds = totalMilliseconds % 1_000
        return String(format: "%02d:%02d.%03d", minutes, remainingSeconds, milliseconds)
    }

    private func colorText(_ video: VideoStreamDescriptor) -> String {
        guard let color = video.color else {
            return video.isHDR ? "HDR · Unspecified metadata" : "Unspecified"
        }
        let dynamicRange = video.isHDR ? "HDR" : "SDR"
        return "\(dynamicRange) · \(color.primaries.rawValue) · \(color.transferFunction.rawValue)"
    }
}
