import Foundation
import VertexCore
import VertexMedia
import VertexMediaAVFoundation

@MainActor
final class MediaImportViewModel: ObservableObject {
    struct LoadedMedia {
        let descriptor: MediaAssetDescriptor
        let thumbnail: PortableImage?
        let waveform: AudioWaveform?
    }

    enum State {
        case idle
        case loading(filename: String)
        case loaded(LoadedMedia)
        case failed(message: String)
    }

    @Published private(set) var state: State = .idle

    private var analysisTask: Task<Void, Never>?
    private var selectionID = UUID()

    deinit {
        analysisTask?.cancel()
    }

    func importMedia(from url: URL) {
        analysisTask?.cancel()
        let requestID = UUID()
        selectionID = requestID
        state = .loading(filename: url.lastPathComponent)

        let cancellationToken = MediaCancellationToken()
        analysisTask = Task { [weak self] in
            guard let self else { return }

            await withTaskCancellationHandler {
                let hasSecurityScope = url.startAccessingSecurityScopedResource()
                defer {
                    if hasSecurityScope {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let inspector = AVFoundationMediaInspector()
                    let descriptor = try await inspector.inspect(
                        url: url,
                        cancellationToken: cancellationToken
                    )

                    var thumbnail: PortableImage?
                    if !descriptor.videoStreams.isEmpty {
                        let frameTime = RationalTime(
                            value: max(0, descriptor.duration.value / 3),
                            timescale: descriptor.duration.timescale
                        )
                        let frameRequest = try VideoFrameRequest(
                            time: frameTime,
                            targetSize: VertexSize(width: 1280, height: 720),
                            tolerance: .nearest
                        )
                        thumbnail = try await AVFoundationVideoFrameProvider(url: url)
                            .frame(for: frameRequest, cancellationToken: cancellationToken)
                            .image
                    }

                    var waveform: AudioWaveform?
                    if !descriptor.audioStreams.isEmpty, descriptor.duration.value > 0 {
                        let range = try MediaTimeRange(start: .zero, duration: descriptor.duration)
                        let request = try AudioWaveformRequest(timeRange: range, bucketCount: 128)
                        waveform = try await AVFoundationAudioWaveformProvider(url: url)
                            .waveform(for: request, cancellationToken: cancellationToken)
                    }

                    guard self.selectionID == requestID, !Task.isCancelled else { return }
                    self.state = .loaded(
                        LoadedMedia(
                            descriptor: descriptor,
                            thumbnail: thumbnail,
                            waveform: waveform
                        )
                    )
                } catch let error as MediaError {
                    guard self.selectionID == requestID, error != .cancelled else { return }
                    self.state = .failed(message: error.localizedDescription)
                } catch is CancellationError {
                    return
                } catch {
                    guard self.selectionID == requestID else { return }
                    self.state = .failed(message: error.localizedDescription)
                }
            } onCancel: {
                Task {
                    await cancellationToken.cancel()
                }
            }
        }
    }
}
