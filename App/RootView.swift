import SwiftUI
import VertexCore

struct RootView: View {
    private let milestone = MilestoneCatalog.current

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    statusCard
                    sourcesSection
                    artifactCard
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.red)
                    .frame(width: 12, height: 34)

                Text("VERTEX")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .tracking(2)
            }

            Text("Professional motion, compositing, editing, color, audio, 3D, and AI on one timeline.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PHASE \(milestone.number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.red)

                Spacer()

                Text(milestone.status.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.18), in: Capsule())
            }

            Text(milestone.title)
                .font(.title2.weight(.bold))

            ForEach(milestone.deliverables, id: \.self) { deliverable in
                Label(deliverable, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .vertexCard()
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SOURCE ADOPTION")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(milestone.sourceAdoptions) { source in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(source.repository)
                            .font(.headline)
                        Spacer()
                        Text(source.license)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Text(source.mode.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.red)

                    Text(source.purpose)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .vertexCard()
            }
        }
    }

    private var artifactCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unsigned IPA pipeline", systemImage: "shippingbox.fill")
                .font(.headline)
            Text(milestone.artifactPolicy)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .vertexCard()
    }
}

private extension View {
    func vertexCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.065))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
    }
}
