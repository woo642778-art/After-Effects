import Foundation
import VertexCore
import VertexProject

@MainActor
extension ProjectWorkspaceViewModel {
    func applyMotionTrack(
        _ track: ProjectMotionTrack,
        mode: ProjectTrackingApplicationMode,
        minimumConfidence: Double
    ) throws {
        guard let project, let layer = selectedLayer else {
            throw ProjectError.invalidOperation("Select a layer before applying tracking data.")
        }
        guard !layer.locked else {
            throw ProjectError.invalidOperation("Unlock the layer before applying tracking data.")
        }
        guard case .media = layer.source else {
            throw ProjectError.invalidOperation("Tracking transforms currently require a media-backed layer.")
        }

        let generated: [ProjectAnimationChannel]
        if track.kind == .planar {
            let uniformBaseScale = sqrt(layer.transform.scaleX * layer.transform.scaleY)
            generated = try track.planarTransformChannels(
                mode: mode,
                basePosition: .init(x: layer.transform.positionX, y: layer.transform.positionY),
                baseScale: uniformBaseScale,
                baseRotationDegrees: layer.transform.rotationDegrees,
                minimumConfidence: minimumConfidence
            )
        } else {
            generated = try track.transformChannels(
                mode: mode,
                basePosition: .init(x: layer.transform.positionX, y: layer.transform.positionY),
                minimumConfidence: minimumConfidence
            )
        }

        let replacedKeys = Set(generated.map { $0.property.stableSortKey })
        let preserved = layer.animationChannels.filter { !replacedKeys.contains($0.property.stableSortKey) }
        let channels = (preserved + generated).sorted { $0.property.stableSortKey < $1.property.stableSortKey }

        var candidate = layer
        candidate.animationChannels = channels
        _ = try candidate.validated(in: project)
        perform(
            .setLayerMotionState(
                id: layer.id,
                animationChannels: channels,
                masks: layer.masks,
                trackMatte: layer.trackMatte
            ),
            mergeKey: nil
        )
    }

    @discardableResult
    func applyTrackedRotoscope(
        _ track: ProjectMotionTrack,
        referencePath: ProjectBezierPath,
        referenceTime: RationalTime,
        minimumConfidence: Double,
        refinements: [ProjectRotoscopeRefinement],
        maskID requestedMaskID: VertexID? = nil
    ) throws -> VertexID {
        guard let project, let layer = selectedLayer else {
            throw ProjectError.invalidOperation("Select a layer before creating a tracked mask.")
        }
        guard !layer.locked else {
            throw ProjectError.invalidOperation("Unlock the layer before creating a tracked mask.")
        }
        guard case .media = layer.source else {
            throw ProjectError.invalidOperation("Tracked masks currently require a media-backed layer.")
        }

        let maskID = requestedMaskID ?? VertexID()
        let rotoscope = try track.propagatedRotoscope(
            name: "Tracked Rotoscope",
            referencePath: referencePath,
            referenceTime: referenceTime,
            minimumConfidence: minimumConfidence,
            refinements: refinements
        )
        guard let firstPath = rotoscope.keyframes.first?.path else {
            throw ProjectError.invalidOperation("Tracked mask propagation produced no keyframes.")
        }
        let mask = try ProjectMask(
            id: maskID,
            name: "Tracked Rotoscope",
            path: firstPath,
            mode: .add,
            opacity: 1,
            featherPixels: 0,
            expansionPixels: 0,
            inverted: false,
            enabled: true
        ).validated()

        var masks = layer.masks
        if let index = masks.firstIndex(where: { $0.id == maskID }) {
            masks[index] = mask
        } else {
            guard masks.count < ProjectMask.maximumMasksPerLayer else {
                throw ProjectError.invalidOperation("The layer already contains the maximum number of masks.")
            }
            masks.append(mask)
        }

        let pathChannel = try rotoscope.maskAnimationChannel(maskID: maskID)
        let channels = layer.animationChannels.filter { channel in
            if case .mask(let existingMaskID, let property) = channel.property {
                return existingMaskID != maskID || property != .path
            }
            return true
        } + [pathChannel]

        var candidate = layer
        candidate.masks = masks
        candidate.animationChannels = channels
        _ = try candidate.validated(in: project)
        perform(
            .setLayerMotionState(
                id: layer.id,
                animationChannels: channels,
                masks: masks,
                trackMatte: layer.trackMatte
            ),
            mergeKey: nil
        )
        return maskID
    }
}
