import Foundation
import VertexCore

public struct Schema1To2Migrator: ProjectMigrator {
    public let sourceVersion = 1
    public let destinationVersion = 2

    public init() {}

    public func migrate(_ data: Data) throws -> ProjectMigrationStepResult {
        let legacy = try Schema1ProjectCodec.decode(data)
        var compositions = try makeCompositions(from: legacy)
        guard !compositions.isEmpty else {
            throw ProjectError.migrationFailure("Schema 1 migration did not produce a composition.")
        }

        let activeID = legacy.activeCompositionID.flatMap { candidate in
            compositions.contains(where: { $0.id == candidate }) ? candidate : nil
        } ?? compositions.sorted { $0.id.rawValue < $1.id.rawValue }[0].id
        guard let compositionIndex = compositions.firstIndex(where: { $0.id == activeID }) else {
            throw ProjectError.migrationFailure("Schema 1 active composition could not be resolved.")
        }

        var layers: [ProjectLayer] = []
        var selectedLayerID: VertexID?
        if let selectedMediaID = legacy.selectedMediaID,
           let reference = legacy.mediaRegistry.first(where: { $0.id == selectedMediaID }) {
            let layer = try makeMigratedLayer(
                projectID: legacy.projectID,
                composition: compositions[compositionIndex],
                media: reference,
                settings: legacy.renderSettings
            )
            layers.append(layer)
            compositions[compositionIndex].layerIDs = [layer.id]
            selectedLayerID = layer.id
        } else if needsAdjustmentLayer(legacy.renderSettings) {
            let layer = try makeAdjustmentLayer(
                projectID: legacy.projectID,
                composition: compositions[compositionIndex],
                settings: legacy.renderSettings
            )
            layers.append(layer)
            compositions[compositionIndex].layerIDs = [layer.id]
            selectedLayerID = layer.id
        }

        var metadata = legacy.metadata
        metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion
        let migrated = try ProjectDocument(
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
        ).normalized().validated()
        let output = try DeterministicProjectCodec().encode(migrated)
        return ProjectMigrationStepResult(
            data: output,
            report: ProjectMigrationReport(
                sourceVersion: 1,
                destinationVersion: 2,
                messages: ["Converted schema 1 Render Lab state into canonical composition and layer data."]
            )
        )
    }

    private func makeCompositions(from legacy: Schema1ProjectDocument) throws -> [ProjectComposition] {
        let placeholders: [ProjectCompositionPlaceholder]
        if legacy.compositionRegistry.isEmpty {
            let id = try DeterministicVertexID.derive(
                domain: "vertex.phase6.migrated-main-composition",
                components: [legacy.projectID.rawValue]
            )
            placeholders = [ProjectCompositionPlaceholder(id: id, name: "Main Composition")]
        } else {
            placeholders = legacy.compositionRegistry
        }
        return placeholders.map { placeholder in
            ProjectComposition(
                id: placeholder.id,
                name: placeholder.name,
                width: legacy.renderSettings.outputWidth,
                height: legacy.renderSettings.outputHeight,
                duration: RationalTime(value: 10, timescale: 1),
                frameRate: legacy.settings.frameRate,
                color: legacy.settings.color,
                backgroundColor: .transparent,
                layerIDs: []
            )
        }
    }

    private func makeMigratedLayer(
        projectID: VertexID,
        composition: ProjectComposition,
        media: MediaReference,
        settings: ProjectRenderSettings
    ) throws -> ProjectLayer {
        ProjectLayer(
            id: try DeterministicVertexID.derive(
                domain: "vertex.phase6.migrated-media-layer",
                components: [projectID.rawValue, composition.id.rawValue, media.id.rawValue]
            ),
            compositionID: composition.id,
            name: media.displayName,
            source: .media(mediaID: media.id, sourceStartTime: .zero),
            timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration),
            transform: migratedTransform(settings),
            operations: migratedOperations(settings)
        )
    }

    private func makeAdjustmentLayer(
        projectID: VertexID,
        composition: ProjectComposition,
        settings: ProjectRenderSettings
    ) throws -> ProjectLayer {
        ProjectLayer(
            id: try DeterministicVertexID.derive(
                domain: "vertex.phase6.migrated-adjustment-layer",
                components: [projectID.rawValue, composition.id.rawValue]
            ),
            compositionID: composition.id,
            name: "Migrated Render Settings",
            source: .adjustment(scope: .belowAll),
            timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration),
            transform: migratedTransform(settings),
            operations: migratedOperations(settings)
        )
    }

    private func migratedTransform(_ settings: ProjectRenderSettings) -> LayerTransform {
        LayerTransform(
            positionX: 0.5 + settings.translationX,
            positionY: 0.5 + settings.translationY,
            anchorX: 0.5,
            anchorY: 0.5,
            scaleX: settings.scale,
            scaleY: settings.scale,
            rotationDegrees: 0,
            opacity: settings.opacity
        )
    }

    private func migratedOperations(_ settings: ProjectRenderSettings) -> [LayerOperation] {
        [
            .exposure(stops: settings.exposure),
            .saturation(value: settings.saturation),
            .invert(enabled: settings.inverted)
        ]
    }

    private func needsAdjustmentLayer(_ settings: ProjectRenderSettings) -> Bool {
        settings.exposure != 0
            || settings.saturation != 1
            || settings.opacity != 1
            || settings.inverted
            || settings.scale != 1
            || settings.translationX != 0
            || settings.translationY != 0
    }
}
