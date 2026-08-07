import SwiftUI
import VertexProjectPersistence

struct LegacyProjectImportView: View {
    let inspection: LegacyImportInspection
    let confirm: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("LEGACY .AEPROJECT IMPORT", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)

            Text("The source package will remain unchanged. A new .vertexproject copy will be created.")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)

            inspectionRow("Compositions", inspection.compositionCount)
            inspectionRow("Layers", inspection.layerCount)
            inspectionRow("Media", inspection.mediaCount)
            inspectionRow("Embedded media eligible", inspection.embeddedMediaEligibleCount)
            inspectionRow("Bookmark sidecars", inspection.bookmarkSuccessCount)
            inspectionRow("Bookmark failures", inspection.bookmarkFailureCount)
            inspectionRow("Discarded Undo / Redo", inspection.discardedUndoCount + inspection.discardedRedoCount)
            inspectionRow("Discarded mutable autosaves", inspection.discardedAutosaveCount)
            inspectionRow("Valid WAL records", inspection.validJournalRecordCount)
            inspectionRow("Ignored WAL records", inspection.ignoredJournalRecordCount)

            HStack {
                Button("Cancel", action: cancel)
                    .buttonStyle(.bordered)
                Button("Convert Copy", action: confirm)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func inspectionRow(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            Spacer()
            Text("\(value)")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.white)
        }
    }
}
