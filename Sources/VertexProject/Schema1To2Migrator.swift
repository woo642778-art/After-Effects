import Foundation
import VertexCore

public struct Schema1To2Migrator: ProjectMigrator {
    public let sourceVersion = 1
    public let destinationVersion = 2

    public init() {}

    public func migrate(_ data: Data) throws -> ProjectMigrationStepResult {
        let legacy = try Schema1ProjectCodec.decode(data)
        _ = try legacy.renderSettings.validated()
        for media in legacy.mediaRegistry { _ = try media.validated() }

        var compositions = try makeCompositions(from: legacy)
        guard !compositions.isEmpty else {
            throw ProjectError.migrationFailure("Schema 1 migration did not produce a composition.")
        }

        let validLegacyActive = legacy.activeCompositionID.flatMap { candidate in
            compositions.contains(where: { $0.id == candidate }) ? candidate : nil
        }
        let activeID = validLegacyActive ?? compositions.sorted { $0.id.rawValue < $1.id.rawValue }[0].id

        var layers: [ProjectLayer] = []
        var selectedLayerID: VertexID?
        var legacyRenderSettings: ProjectRenderSettings? = legacy.renderSettings

        if let selectedMediaID = legacy.selectedMediaID {
            guard legacy.mediaRegistry.contains(where: { $0.id == selectedMediaID }) else {
                throw ProjectError.migrationFailure("Schema 1 selected media is missing from the media registry.")
            }
            guard let compositionIndex = compositions.firstIndex(where: { $0.id == activeID }) else {
                throw ProjectError.migrationFailure("Schema 1 active composition could not be resolved.")
            }
            let layerID = try DeterministicVertexID.derive(
                domain: "vertex.phase6.migrated-media-layer",
                components: [legacy.projectID.rawValue, activeID.rawValue, selectedMediaID.rawValue]
            )
            let settings = legacy.renderSettings
            let layer = ProjectLayer(
                id: layerID,
                compositionID: activeID,
                name: legacy.mediaRegistry.first(where: { $0.id == selectedMediaID })?.displayName ?? "Migrated Media",
                source: .media(mediaID: selectedMediaID, sourceStartTime: .zero),
                enabled: true,
                locked: false,
                solo: false,
                timing: LayerTiming(
                    startTime: .zero,
                    inPoint: .zero,
                    outPoint: compositions[compositionIndex].duration
                ),
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
            legacyRenderSettings = nil
        }

        var metadata = legacy.metadata
        metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion
        let migrated = ProjectDocument(
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
            selectedMediaID: legacy.selectedMediaID,
            legacyRenderSettings: legacyRenderSettings,
            appliedCommandIDs: legacy.appliedCommandIDs
        )
        let encoded = try DeterministicProjectCodec().encode(migrated)
        return ProjectMigrationStepResult(
            data: encoded,
            report: ProjectMigrationReport(
                sourceVersion: 1,
                destinationVersion: 2,
                messages: [
                    "Created \(compositions.count) composition record(s).",
                    "Created \(layers.count) migrated media layer(s).",
                    "Schema 1 Undo/Redo and journal records require package-level reset."
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
                    name: placeholder.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Composition"
                        : placeholder.name,
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

        let id = try DeterministicVertexID.derive(
            domain: "vertex.phase6.default-composition",
            components: [legacy.projectID.rawValue]
        )
        return [
            ProjectComposition(
                id: id,
                name: "Main Composition",
                width: legacy.renderSettings.outputWidth,
                height: legacy.renderSettings.outputHeight,
                duration: duration,
                frameRate: legacy.settings.frameRate,
                color: legacy.settings.color,
                backgroundColor: .transparent,
                layerIDs: []
            )
        ]
    }
}
