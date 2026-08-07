import Foundation
import SwiftUI
import VertexCore
import VertexProject
import VertexProjectPersistence

@MainActor
final class ProjectWorkspaceViewModel: ObservableObject {
    enum OperationKind: String, Equatable, Sendable {
        case createProject
        case openProject
        case save
        case autosave
        case legacyInspection
        case legacyImport
        case pendingRecovery
        case mediaImport
        case relink
        case embed
        case export
        case edit
        case undo
        case redo
    }

    enum OperationState: Equatable {
        case idle
        case running(OperationKind)
        case succeeded(String)
        case failed(String)
        case cancelled
    }

    @Published var projectNameInput = "Untitled Project"
    @Published private(set) var project: ProjectDocument?
    @Published private(set) var packageURL: URL?
    @Published private(set) var status: OperationState = .idle
    @Published private(set) var lastSavedAt: Date?
    @Published private(set) var missingMediaIDs: Set<VertexID> = []
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var hasUnsavedChanges = false
    @Published private(set) var legacyInspection: LegacyImportInspection?
    @Published private(set) var pendingDecision: PendingSnapshotDecisionContext?
    @Published var exportDocument: ProjectPackageFileDocument?

    private let sessionActor = ProjectSessionActor()
    private var legacySourceURL: URL?
    private var autosaveTask: Task<Void, Never>?
    private var commandCountSinceAutosave = 0
    private var publicationGate = PublicationGate()

    var renderSettings: ProjectRenderSettings {
        project?.renderSettings ?? ProjectRenderSettings()
    }

    var revisionText: String {
        guard let project else { return "No project" }
        return "Revision \(project.revision) · Schema \(project.schemaVersion)"
    }

    var selectedMedia: MediaReference? {
        guard let project, let selectedID = project.selectedMediaID else { return nil }
        return project.mediaRegistry.first { $0.id == selectedID }
    }

    var activeComposition: ProjectComposition? {
        guard let project, let id = project.activeCompositionID else { return nil }
        return project.composition(id: id)
    }

    var orderedLayers: [ProjectLayer] {
        guard let project, let composition = activeComposition else { return [] }
        return project.layers(in: composition.id)
    }

    var selectedLayer: ProjectLayer? {
        guard let project, let id = project.selectedLayerID else { return nil }
        return project.layer(id: id)
    }

    func createProject(named name: String? = nil) {
        let token = beginPublishedOperation(.createProject)
        let requested = (name ?? projectNameInput)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        Task { [weak self] in
            guard let self else { return }
            do {
                let projectID = VertexID()
                let url = try self.localPackageURL(for: projectID)
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                let snapshot = try await self.sessionActor.create(
                    name: requested.isEmpty ? "Untitled Project" : requested,
                    packageURL: url
                )
                self.publish(snapshot, token: token, message: "New .vertexproject created")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func renameProject() {
        guard let current = project?.metadata.name else { return }
        let next = projectNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.isEmpty, next != current else { return }
        perform(.renameProject(to: next), mergeKey: nil)
    }

    func openProject(from externalURL: URL) {
        switch externalURL.pathExtension.lowercased() {
        case ProjectDocumentTypes.canonicalExtension:
            openCanonicalProject(from: externalURL)
        case ProjectDocumentTypes.legacyExtension:
            inspectLegacyProject(from: externalURL)
        default:
            status = .failed("Only .vertexproject packages and import-only .aeproject packages are supported.")
        }
    }

    func confirmLegacyImport() {
        guard let sourceURL = legacySourceURL else { return }
        let token = beginPublishedOperation(.legacyImport)

        Task { [weak self] in
            guard let self else { return }
            let hasScope = sourceURL.startAccessingSecurityScopedResource()
            defer { if hasScope { sourceURL.stopAccessingSecurityScopedResource() } }
            do {
                let destination = try self.uniqueImportedPackageURL(
                    baseName: sourceURL.deletingPathExtension().lastPathComponent
                )
                let snapshot = try await self.sessionActor.importLegacy(
                    sourceURL: sourceURL,
                    destinationURL: destination
                )
                self.legacySourceURL = nil
                self.legacyInspection = nil
                self.publish(snapshot, token: token, message: "Legacy project converted non-destructively")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func cancelLegacyImport() {
        _ = publicationGate.begin()
        legacySourceURL = nil
        legacyInspection = nil
        status = .cancelled
    }

    func applyPendingSnapshot() {
        guard let context = pendingDecision else { return }
        let token = beginPublishedOperation(.pendingRecovery)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.applyPendingAndOpen(
                    packageURL: context.packageURL
                )
                self.pendingDecision = nil
                self.publish(snapshot, token: token, message: "Pending snapshot applied")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func discardPendingSnapshot() {
        guard let context = pendingDecision else { return }
        let token = beginPublishedOperation(.pendingRecovery)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.discardPendingAndOpen(
                    packageURL: context.packageURL
                )
                self.pendingDecision = nil
                self.publish(snapshot, token: token, message: "Pending snapshot discarded")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func registerImportedMedia(from url: URL) {
        if project == nil {
            status = .failed("Create or open a project before importing media.")
            return
        }
        let token = beginPublishedOperation(.mediaImport)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.registerExternalMedia(from: url)
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "External media registered")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func setRenderParameter(_ parameter: ProjectRenderParameter, to value: Double) {
        guard project?.renderSettings.value(for: parameter) != value else { return }
        perform(
            .setRenderParameter(parameter, value: value),
            mergeKey: "render.\(parameter.rawValue)"
        )
    }

    func setInverted(_ value: Bool) {
        guard project?.renderSettings.inverted != value else { return }
        perform(
            .setRenderBoolean(.inverted, value: value),
            mergeKey: "render.inverted"
        )
    }

    func setOutputDimensions(width: Int, height: Int) {
        guard let settings = project?.renderSettings,
              settings.outputWidth != width || settings.outputHeight != height else { return }
        perform(
            .setOutputDimensions(width: width, height: height),
            mergeKey: "render.output"
        )
    }

    func createComposition(name: String = "Composition") {
        guard let project else { return }
        let basis = activeComposition
        let composition = ProjectComposition(
            name: name,
            width: basis?.width ?? 1080,
            height: basis?.height ?? 1080,
            duration: basis?.duration ?? RationalTime(value: 10, timescale: 1),
            frameRate: basis?.frameRate ?? project.settings.frameRate,
            color: basis?.color ?? project.settings.color,
            backgroundColor: .transparent,
            layerIDs: []
        )
        perform(.insertComposition(composition, ownedLayers: [], index: project.compositionRegistry.count), mergeKey: nil)
        selectComposition(composition.id)
    }

    func duplicateActiveComposition() {
        guard let project, let source = activeComposition else { return }
        let duplicateID = VertexID()
        var duplicate = source
        duplicate.id = duplicateID
        duplicate.name = source.name + " Copy"
        var layers: [ProjectLayer] = []
        for sourceLayer in project.layers(in: source.id) {
            var layer = sourceLayer
            layer.id = VertexID()
            layer.compositionID = duplicateID
            layer.name = sourceLayer.name + " Copy"
            layers.append(layer)
        }
        duplicate.layerIDs = layers.map(\.id)
        perform(.insertComposition(duplicate, ownedLayers: layers, index: project.compositionRegistry.count), mergeKey: nil)
        selectComposition(duplicate.id)
    }

    func selectComposition(_ id: VertexID) {
        guard project?.activeCompositionID != id else { return }
        let token = beginPublishedOperation(.edit)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.setActiveComposition(id)
                self.publish(snapshot, token: token, message: "Active composition changed")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func removeActiveComposition() {
        guard let project, let composition = activeComposition,
              project.compositionRegistry.count > 1 else { return }
        let isReferenced = project.layerRegistry.contains { layer in
            guard layer.compositionID != composition.id,
                  case .composition(let target, _) = layer.source else { return false }
            return target == composition.id
        }
        guard !isReferenced,
              let replacement = project.compositionRegistry.first(where: { $0.id != composition.id }) else { return }
        let token = beginPublishedOperation(.edit)
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.sessionActor.setActiveComposition(replacement.id)
                let snapshot = try await self.sessionActor.apply(.removeComposition(id: composition.id), mergeKey: nil)
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "Composition removed")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func renameActiveComposition(_ name: String) {
        guard let composition = activeComposition else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != composition.name else { return }
        perform(.renameComposition(id: composition.id, to: trimmed), mergeKey: nil)
    }

    func setActiveCompositionDimensions(width: Int, height: Int) {
        guard let composition = activeComposition,
              width != composition.width || height != composition.height else { return }
        perform(
            .setCompositionDimensions(id: composition.id, width: width, height: height),
            mergeKey: "composition.\(composition.id.rawValue).dimensions"
        )
    }

    func setActiveCompositionDuration(seconds: Double) {
        guard let composition = activeComposition,
              let value = exactTime(seconds: seconds, frameRate: composition.frameRate),
              value > .zero,
              value != composition.duration,
              orderedLayers.allSatisfy({ $0.timing.outPoint <= value }) else { return }
        perform(
            .setCompositionDuration(id: composition.id, duration: value),
            mergeKey: "composition.\(composition.id.rawValue).duration"
        )
    }

    func setActiveCompositionFrameRate(_ frameRate: RationalTime) {
        guard let composition = activeComposition, frameRate > .zero, frameRate != composition.frameRate else { return }
        perform(.setCompositionFrameRate(id: composition.id, frameRate: frameRate), mergeKey: nil)
    }

    func setActiveCompositionBackground(_ color: ProjectRGBAColor) {
        guard let composition = activeComposition, composition.backgroundColor != color else { return }
        perform(.setCompositionBackground(id: composition.id, color: color), mergeKey: nil)
    }

    func addSelectedMediaLayer() {
        guard let composition = activeComposition, let media = selectedMedia else { return }
        insertLayer(ProjectLayer(
            compositionID: composition.id,
            name: media.displayName,
            source: .media(mediaID: media.id, sourceStartTime: .zero),
            timing: fullTiming(composition)
        ))
    }

    func addAdjustmentLayer() {
        guard let composition = activeComposition else { return }
        insertLayer(ProjectLayer(
            compositionID: composition.id,
            name: "Adjustment Layer",
            source: .adjustment(scope: .belowAll),
            timing: fullTiming(composition)
        ))
    }

    func addNullLayer() { addModelLayer(name: "Null", source: .null) }
    func addGuideLayer() { addModelLayer(name: "Guide", source: .guide) }
    func addCameraLayer() { addModelLayer(name: "Camera", source: .camera(.default)) }
    func addLightLayer() { addModelLayer(name: "Light", source: .light(.default)) }

    func addNestedCompositionLayer(sourceCompositionID: VertexID) {
        guard let composition = activeComposition,
              sourceCompositionID != composition.id,
              let source = project?.composition(id: sourceCompositionID) else { return }
        insertLayer(ProjectLayer(
            compositionID: composition.id,
            name: source.name,
            source: .composition(compositionID: sourceCompositionID, sourceStartTime: .zero),
            timing: fullTiming(composition)
        ))
    }

    func selectLayer(_ id: VertexID?) {
        guard project?.selectedLayerID != id else { return }
        let mediaID: VertexID? = id.flatMap { candidate in
            guard let layer = project?.layer(id: candidate), case .media(let mediaID, _) = layer.source else { return nil }
            return mediaID
        }
        let token = beginPublishedOperation(.edit)
        Task { [weak self] in
            guard let self else { return }
            do {
                var snapshot = try await self.sessionActor.setSelectedLayer(id)
                if let mediaID, snapshot.document.selectedMediaID != mediaID {
                    snapshot = try await self.sessionActor.setSelectedMedia(mediaID)
                }
                self.publish(snapshot, token: token, message: "Layer selection changed")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func removeSelectedLayer() {
        guard let layer = selectedLayer else { return }
        perform(.removeLayer(id: layer.id), mergeKey: nil)
    }

    func duplicateSelectedLayer() {
        guard let project, let layer = selectedLayer,
              let composition = project.composition(id: layer.compositionID),
              let index = composition.layerIDs.firstIndex(of: layer.id) else { return }
        var duplicate = layer
        duplicate.id = VertexID()
        duplicate.name += " Copy"
        perform(.insertLayer(duplicate, index: min(index + 1, composition.layerIDs.count)), mergeKey: nil)
        selectLayer(duplicate.id)
    }

    func moveLayer(_ id: VertexID, to newIndex: Int) {
        guard let composition = activeComposition,
              composition.layerIDs.indices.contains(newIndex),
              composition.layerIDs.firstIndex(of: id) != newIndex else { return }
        perform(.reorderLayer(id: id, toIndex: newIndex), mergeKey: nil)
    }

    func setLayerLocked(_ value: Bool) {
        guard let layer = selectedLayer, layer.locked != value else { return }
        perform(.setLayerLocked(id: layer.id, value: value), mergeKey: nil)
    }

    func setLayerEnabled(_ value: Bool) {
        guard let layer = selectedLayer, layer.enabled != value else { return }
        perform(.setLayerEnabled(id: layer.id, value: value), mergeKey: nil)
    }

    func setLayerSolo(_ value: Bool) {
        guard let layer = selectedLayer, layer.solo != value else { return }
        perform(.setLayerSolo(id: layer.id, value: value), mergeKey: nil)
    }

    func renameSelectedLayer(_ name: String) {
        guard let layer = selectedLayer else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != layer.name else { return }
        perform(.renameLayer(id: layer.id, to: trimmed), mergeKey: nil)
    }

    func setLayerTransform(_ transform: LayerTransform, mergeKey: String) {
        guard let layer = selectedLayer, layer.transform != transform else { return }
        perform(
            .setLayerTransform(id: layer.id, transform: transform),
            mergeKey: "layer.\(layer.id.rawValue).\(mergeKey)"
        )
    }

    func setLayerTiming(_ timing: LayerTiming) {
        guard let layer = selectedLayer, layer.timing != timing else { return }
        perform(
            .setLayerTiming(id: layer.id, timing: timing),
            mergeKey: "layer.\(layer.id.rawValue).timing"
        )
    }

    func setLayerBlendMode(_ mode: LayerBlendMode) {
        guard let layer = selectedLayer, layer.blendMode != mode else { return }
        perform(.setLayerBlendMode(id: layer.id, mode: mode), mergeKey: nil)
    }

    func setLayerSource(_ source: LayerSource) {
        guard let layer = selectedLayer, layer.source != source else { return }
        perform(.setLayerSource(id: layer.id, source: source), mergeKey: nil)
    }

    func setLayerExposure(_ value: Double) {
        setLayerOperation(exposure: value, saturation: nil, inverted: nil)
    }

    func setLayerSaturation(_ value: Double) {
        setLayerOperation(exposure: nil, saturation: value, inverted: nil)
    }

    func setLayerInverted(_ value: Bool) {
        setLayerOperation(exposure: nil, saturation: nil, inverted: value)
    }

    func resolveMediaURL(_ mediaID: VertexID) async -> URL? {
        try? await sessionActor.resolveMediaURL(mediaID)
    }

    func undo() {
        let token = beginPublishedOperation(.undo)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.undo()
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "Undo applied")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func redo() {
        let token = beginPublishedOperation(.redo)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.redo()
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "Redo applied")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func saveNow() {
        let token = beginPublishedOperation(.save)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.save()
                self.commandCountSinceAutosave = 0
                self.publish(snapshot, token: token, message: "Project saved atomically")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func prepareExport() {
        let token = beginPublishedOperation(.export)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.save()
                let document = try ProjectPackageFileDocument(packageURL: snapshot.packageURL)
                guard self.publicationGate.accepts(token) else { return }
                self.commandCountSinceAutosave = 0
                self.apply(snapshot)
                self.exportDocument = document
                self.status = .succeeded("Verified project package ready to export")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func embedSelectedMedia() {
        guard let mediaID = selectedMedia?.id else { return }
        let token = beginPublishedOperation(.embed)
        Task { [weak self] in
            guard let self else { return }
            do {
                guard let sourceURL = try await self.sessionActor.resolveExternalMedia(mediaID) else {
                    throw ProjectError.missingMedia("Relink the media before embedding it.")
                }
                let snapshot = try await self.sessionActor.embed(mediaID: mediaID, from: sourceURL)
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "Media embedded and verified")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func relinkSelectedMedia(to url: URL) {
        guard let mediaID = selectedMedia?.id else { return }
        let token = beginPublishedOperation(.relink)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.relink(mediaID: mediaID, to: url)
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "Media bookmark sidecar replaced")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    func flushAutosave() {
        autosaveTask?.cancel()
        autosaveTask = nil
        guard project != nil else { return }
        let token = beginPublishedOperation(.autosave)
        Task { [weak self] in
            guard let self else { return }
            do {
                if try await self.sessionActor.autosave(reason: .manualFlush) != nil {
                    self.commandCountSinceAutosave = 0
                    guard self.publicationGate.accepts(token) else { return }
                    self.status = .succeeded("Immutable recovery snapshot created")
                } else if self.publicationGate.accepts(token) {
                    self.status = .succeeded("No new autosave was needed")
                }
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    private func insertLayer(_ layer: ProjectLayer) {
        perform(.insertLayer(layer, index: 0), mergeKey: nil)
        selectLayer(layer.id)
    }

    private func addModelLayer(name: String, source: LayerSource) {
        guard let composition = activeComposition else { return }
        insertLayer(ProjectLayer(
            compositionID: composition.id,
            name: name,
            source: source,
            timing: fullTiming(composition)
        ))
    }

    private func fullTiming(_ composition: ProjectComposition) -> LayerTiming {
        LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration)
    }

    private func setLayerOperation(exposure: Double?, saturation: Double?, inverted: Bool?) {
        guard let layer = selectedLayer else { return }
        var currentExposure = 0.0
        var currentSaturation = 1.0
        var currentInvert = false
        for operation in layer.operations {
            switch operation {
            case .exposure(let value): currentExposure = value
            case .saturation(let value): currentSaturation = value
            case .invert(let value): currentInvert = value
            }
        }
        let operations: [LayerOperation] = [
            .exposure(stops: exposure ?? currentExposure),
            .saturation(value: saturation ?? currentSaturation),
            .invert(enabled: inverted ?? currentInvert)
        ]
        guard operations != layer.operations else { return }
        perform(
            .setLayerOperations(id: layer.id, operations: operations),
            mergeKey: "layer.\(layer.id.rawValue).operations"
        )
    }

    func exactTime(seconds: Double, frameRate: RationalTime) -> RationalTime? {
        guard seconds.isFinite, seconds >= 0,
              frameRate.value > 0,
              frameRate.value <= Int64(Int32.max) else { return nil }
        let frame = (seconds * frameRate.seconds).rounded()
        guard frame <= Double(Int64.max) else { return nil }
        let numerator = Int64(frame).multipliedReportingOverflow(by: Int64(frameRate.timescale))
        guard !numerator.overflow else { return nil }
        return RationalTime(value: numerator.partialValue, timescale: Int32(frameRate.value))
    }

    private func perform(_ payload: ProjectCommandPayload, mergeKey: String?) {
        let token = beginPublishedOperation(.edit)
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.sessionActor.apply(payload, mergeKey: mergeKey)
                self.commandCountSinceAutosave += 1
                self.publish(snapshot, token: token, message: "Session change applied")
                self.scheduleAutosaveOrFlush()
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    private func openCanonicalProject(from externalURL: URL) {
        let token = beginPublishedOperation(.openProject)
        Task { [weak self] in
            guard let self else { return }
            let hasScope = externalURL.startAccessingSecurityScopedResource()
            defer { if hasScope { externalURL.stopAccessingSecurityScopedResource() } }
            do {
                let destination = try self.copyCanonicalIntoWorkspace(externalURL)
                switch try await self.sessionActor.openCanonical(packageURL: destination) {
                case .opened(let snapshot):
                    self.publish(snapshot, token: token, message: "Canonical project opened")
                case .pendingDecision(let context):
                    guard self.publicationGate.accepts(token) else { return }
                    self.pendingDecision = context
                    self.status = .succeeded("Pending save needs an explicit recovery decision")
                }
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    private func inspectLegacyProject(from externalURL: URL) {
        let token = beginPublishedOperation(.legacyInspection)
        Task { [weak self] in
            guard let self else { return }
            let hasScope = externalURL.startAccessingSecurityScopedResource()
            defer { if hasScope { externalURL.stopAccessingSecurityScopedResource() } }
            do {
                let inspection = try await self.sessionActor.inspectLegacy(packageURL: externalURL)
                guard self.publicationGate.accepts(token) else { return }
                self.legacySourceURL = externalURL
                self.legacyInspection = inspection
                self.status = .succeeded("Legacy import ready for review")
            } catch {
                self.publish(error, token: token)
            }
        }
    }

    private func scheduleAutosaveOrFlush() {
        autosaveTask?.cancel()
        if commandCountSinceAutosave >= 20 {
            autosaveTask = Task { [weak self] in
                guard let self else { return }
                do {
                    if try await self.sessionActor.autosave(reason: .commandThreshold) != nil {
                        self.commandCountSinceAutosave = 0
                    }
                } catch {
                    self.status = .failed(error.localizedDescription)
                }
            }
            return
        }

        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            do {
                if try await self.sessionActor.autosave(reason: .idleDelay) != nil {
                    self.commandCountSinceAutosave = 0
                }
            } catch {
                self.status = .failed(error.localizedDescription)
            }
        }
    }

    private func beginPublishedOperation(_ kind: OperationKind) -> Int {
        let token = publicationGate.begin()
        status = .running(kind)
        return token
    }

    private func publish(
        _ snapshot: ProjectSessionSnapshot,
        token: Int,
        message: String
    ) {
        guard publicationGate.accepts(token) else { return }
        apply(snapshot)
        status = .succeeded(message)
    }

    private func publish(_ error: Error, token: Int) {
        guard publicationGate.accepts(token) else { return }
        status = .failed(error.localizedDescription)
    }

    private func apply(_ snapshot: ProjectSessionSnapshot) {
        project = snapshot.document
        packageURL = snapshot.packageURL
        projectNameInput = snapshot.document.metadata.name
        lastSavedAt = snapshot.lastSavedAt
        missingMediaIDs = snapshot.missingMediaIDs
        canUndo = snapshot.canUndo
        canRedo = snapshot.canRedo
        hasUnsavedChanges = snapshot.hasUnsavedChanges
        pendingDecision = nil
    }

    private func projectsRootURL() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ProjectError.packageCorruption("Application Support directory is unavailable.")
        }
        let root = applicationSupport.appendingPathComponent("After Effects/Projects", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func localPackageURL(for projectID: VertexID) throws -> URL {
        try projectsRootURL()
            .appendingPathComponent(projectID.rawValue)
            .appendingPathExtension(ProjectDocumentTypes.canonicalExtension)
    }

    private func uniqueImportedPackageURL(baseName: String) throws -> URL {
        let safe = baseName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        return try projectsRootURL()
            .appendingPathComponent("\(safe)-\(UUID().uuidString.lowercased())")
            .appendingPathExtension(ProjectDocumentTypes.canonicalExtension)
    }

    private func copyCanonicalIntoWorkspace(_ sourceURL: URL) throws -> URL {
        let destination = try uniqueImportedPackageURL(
            baseName: sourceURL.deletingPathExtension().lastPathComponent
        )
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }
}
