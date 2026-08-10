import Foundation
import VertexCore
import VertexProject

@MainActor
extension ProjectWorkspaceViewModel {
    func addGeneratedGraphic(_ document: ProjectGraphicDocument, name: String) {
        guard let composition = activeComposition, let project else { return }
        let existingMediaIDs = Set(project.mediaRegistry.map(\.id))
        do {
            let data = try GeneratedGraphicRenderer.pngData(for: document)
            let root = try generatedMediaRootURL()
            let safeName = name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "\\", with: "-")
            let filename = "\(safeName.isEmpty ? "Graphic" : safeName)-\(UUID().uuidString.lowercased()).png"
            let url = root.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            registerImportedMedia(from: url)

            Task { @MainActor [weak self] in
                guard let self else { return }
                for _ in 0..<120 {
                    if let imported = self.project?.mediaRegistry.first(where: { !existingMediaIDs.contains($0.id) }) {
                        let layer = ProjectLayer(
                            compositionID: composition.id,
                            name: safeName.isEmpty ? "Graphic" : safeName,
                            source: .media(mediaID: imported.id, sourceStartTime: .zero),
                            timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration)
                        )
                        self.perform(.insertLayer(layer, index: 0), mergeKey: nil)
                        self.selectLayer(layer.id)
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
        } catch {
            assertionFailure("Generated graphic failed: \(error)")
        }
    }

    private func generatedMediaRootURL() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ProjectError.packageCorruption("Application Support directory is unavailable.")
        }
        let root = applicationSupport
            .appendingPathComponent("Vertex2", isDirectory: true)
            .appendingPathComponent("GeneratedMedia", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
