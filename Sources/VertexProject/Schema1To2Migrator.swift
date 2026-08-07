import Foundation
import VertexCore

public struct Schema1To2Migrator: ProjectMigrator {
    public let sourceVersion = 1
    public let destinationVersion = 2

    public init() {}

    public func migrate(_ data: Data) throws -> ProjectMigrationStepResult {
        let legacy = try Schema1ProjectCodec.decode(data)
        var compositions = try makeCompositions(from: legacy)
        guard !compositions.isEmpty else { throw ProjectError.migrationFailure("Schema 1 migration produced no composition.") }

        let activeID = legacy.activeCompositionID.flatMap { candidate in
            compositions.contains(where: { $0.id == candidate }) ? candidate : nil
        } ?? compositions.sorted { $0.id.rawValue < $1.id.rawValue }[0].id

        var layers: [ProjectLayer] = []
        var selectedLayerID: VertexID?
        if let selectedMediaID = legacy.selectedMediaID {
            guard let media = legacy.mediaRegistry.first(where: { $0.id == selectedMediaID }),
                  let compositionIndex = compositions.firstIndex(where: { $0.id == activeID }) else {
                throw ProjectError.migrationFailure("Schema 1 selected media or active composition could not be resolved.")
            }
            let layerID = try DeterministicVertexID.derive(
                domain: "vertex.phase6.migrated-media-layer",
                components: [legacy.projectID.rawValue, activeID.rawValue, selectedMediaID.rawValue]
            )
            let settings = legacy.renderSettings
            let layer = ProjectLayer(
                id: layerID,
                compositionID: activeID,
                name: media.displayName,
                source: .media(mediaID: selectedMediaID, sourceStartTime: .zero),
                timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: compositions[compositionIndex].duration),
                transform: LayerTransform(
                    positionX: 0.5 + settings.translationX,
                    positionY: 0.5 + settings.translationY,
                    anchorX: 0.5,
                    anchorY: 0.5,
                    scaleX: settings.scale,
                    scaleY: settings.scale,
                    rotationDegrees: 0,
                    opacity: settings.opacity
                ),
                blendMode: .normal,
                operations: [
                    .exposure(stops: settings.exposure),
                    .saturation(value: settings.saturation),
                    .invert(enabled: settings.inverted)
                ]
            )
            layers.append(layer)
            compositions[compositionIndex].layerIDs.append(layer.id)
            selectedLayerID = layer.id
        }

        var metadata = legacy.metadata
        metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion
        let migrated = try ProjectDocument(
            schemaVersion: 2,
            minimumReaderVersion: 2,
            projectID: legacy.projectID,
            revision: legacy.revision,
            metadata: metadata,
            settings: legacy.settings,
            mediaRegistry: legacy.mediaRegistry,
            compositionRegistry: compositions,
            layerRegistry: layers,
            activeCompositionID: activeID,
            selectedLayerID: selectedLayerID,
            selectedMediaID: legacy.selectedMediaID
        ).validated()
        return ProjectMigrationStepResult(
            data: try DeterministicProjectCodec().encode(migrated),
            report: ProjectMigrationReport(
                sourceVersion: 1,
                destinationVersion: 2,
                messages: [
                    "Created \(compositions.count) composition record(s).",
                    "Created \(layers.count) migrated media layer(s).",
                    "Global Render Lab state was transferred into composition/layer state."
                ]
            )
        )
    }

    private func makeCompositions(from legacy: Schema1ProjectDocument) throws -> [ProjectComposition] {
        let duration = RationalTime(value: 10, timescale: 1)
        if !legacy.compositionRegistry.isEmpty {
            return legacy.compositionRegistry.map { placeholder in
                ProjectComposition(
                    id: placeholder.id,
                    name: placeholder.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Composition" : placeholder.name,
                    width: legacy.renderSettings.outputWidth,
                    height: legacy.renderSettings.outputHeight,
                    duration: duration,
                    frameRate: legacy.settings.frameRate,
                    color: legacy.settings.color,
                    backgroundColor: .transparent,
                    layerIDs: []
                )
            }
        }
        let id = try DeterministicVertexID.derive(domain: "vertex.phase6.default-composition", components: [legacy.projectID.rawValue])
        return [ProjectComposition(
            id: id,
            name: "Main Composition",
            width: legacy.renderSettings.outputWidth,
            height: legacy.renderSettings.outputHeight,
            duration: duration,
            frameRate: legacy.settings.frameRate,
            color: legacy.settings.color,
            backgroundColor: .transparent,
            layerIDs: []
        )]
    }
}
