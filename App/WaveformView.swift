import SwiftUI
import VertexMedia

struct WaveformView: View {
    let waveform: AudioWaveform

    var body: some View {
        Canvas { context, size in
            guard waveform.bucketCount > 0 else { return }
            let centerY = size.height / 2
            let step = size.width / CGFloat(waveform.bucketCount)
            var path = Path()

            for index in waveform.peaks.indices {
                let x = (CGFloat(index) + 0.5) * step
                let amplitude = CGFloat(waveform.peaks[index]) * centerY
                path.move(to: CGPoint(x: x, y: centerY - amplitude))
                path.addLine(to: CGPoint(x: x, y: centerY + amplitude))
            }

            context.stroke(
                path,
                with: .color(AfterEffectsTheme.accent),
                lineWidth: max(1, step * 0.55)
            )
        }
        .frame(height: 92)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("Audio waveform with \(waveform.bucketCount) buckets")
    }
}
