from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]

def read(path): return (ROOT / path).read_text()
def write(path, text):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)
def replace_once(path, old, new):
    text = read(path)
    if new in text: return
    if old not in text: raise RuntimeError(f"marker not found in {path}: {old[:100]!r}")
    write(path, text.replace(old, new, 1))

# Persisted reversible timeline mutation.
path = "Sources/VertexProject/ProjectTimeline.swift"
text = read(path)
addition = r'''

public struct TimelineProjectMutation: Codable, Equatable, Sendable {
    public var beforeLayers: [ProjectLayer]
    public var afterLayers: [ProjectLayer]
    public var beforeLayerOrder: [VertexID]
    public var afterLayerOrder: [VertexID]
    public var beforeSelectedLayerID: VertexID?
    public var afterSelectedLayerID: VertexID?

    public init(
        beforeLayers: [ProjectLayer],
        afterLayers: [ProjectLayer],
        beforeLayerOrder: [VertexID],
        afterLayerOrder: [VertexID],
        beforeSelectedLayerID: VertexID?,
        afterSelectedLayerID: VertexID?
    ) {
        self.beforeLayers = beforeLayers
        self.afterLayers = afterLayers
        self.beforeLayerOrder = beforeLayerOrder
        self.afterLayerOrder = afterLayerOrder
        self.beforeSelectedLayerID = beforeSelectedLayerID
        self.afterSelectedLayerID = afterSelectedLayerID
    }

    public var inverse: Self {
        Self(
            beforeLayers: afterLayers,
            afterLayers: beforeLayers,
            beforeLayerOrder: afterLayerOrder,
            afterLayerOrder: beforeLayerOrder,
            beforeSelectedLayerID: afterSelectedLayerID,
            afterSelectedLayerID: beforeSelectedLayerID
        )
    }

    public func validated(compositionID: VertexID) throws -> Self {
        try validateSide(layers: beforeLayers, order: beforeLayerOrder, selected: beforeSelectedLayerID, compositionID: compositionID)
        try validateSide(layers: afterLayers, order: afterLayerOrder, selected: afterSelectedLayerID, compositionID: compositionID)
        return self
    }

    private func validateSide(
        layers: [ProjectLayer],
        order: [VertexID],
        selected: VertexID?,
        compositionID: VertexID
    ) throws {
        guard Set(layers.map(\.id)).count == layers.count, Set(order).count == order.count else {
            throw ProjectError.duplicateIdentity("timeline mutation layer")
        }
        guard layers.allSatisfy({ $0.compositionID == compositionID }) else {
            throw ProjectError.invalidValue("Timeline mutation layers must belong to one composition.")
        }
        let layerIDs = Set(layers.map(\.id))
        guard layerIDs == Set(order), layers.count == order.count else {
            throw ProjectError.invalidValue("Timeline mutation layer order must contain exactly its layer snapshot identities.")
        }
        if let selected, !layerIDs.contains(selected) {
            throw ProjectError.invalidValue("Timeline mutation selected layer must belong to its snapshot.")
        }
    }
}
'''
if "public struct TimelineProjectMutation" not in text:
    write(path, text + addition)

# ProjectLayer layer markers with schema 4/5 decode compatibility.
path = "Sources/VertexProject/ProjectLayer.swift"
text = read(path)
if "public var markers: [ProjectMarker]" not in text:
    text = text.replace("    public var parentLayerID: VertexID?\n", "    public var parentLayerID: VertexID?\n    public var markers: [ProjectMarker]\n", 1)
    text = text.replace("        case parentLayerID\n", "        case parentLayerID\n        case markers\n", 1)
    text = text.replace(
        "        parentLayerID: VertexID? = nil\n    ) {",
        "        parentLayerID: VertexID? = nil,\n        markers: [ProjectMarker] = []\n    ) {",
        1,
    )
    text = text.replace("        self.parentLayerID = parentLayerID\n", "        self.parentLayerID = parentLayerID\n        self.markers = markers\n", 1)
    text = text.replace("        parentLayerID = try container.decodeIfPresent(VertexID.self, forKey: .parentLayerID)\n", "        parentLayerID = try container.decodeIfPresent(VertexID.self, forKey: .parentLayerID)\n        markers = try container.decodeIfPresent([ProjectMarker].self, forKey: .markers) ?? []\n", 1)
    text = text.replace("        try container.encodeIfPresent(parentLayerID, forKey: .parentLayerID)\n", "        try container.encodeIfPresent(parentLayerID, forKey: .parentLayerID)\n        try container.encode(markers, forKey: .markers)\n", 1)
validation_anchor = "        _ = try animationChannels.validatedAnimationChannels(for: masks)\n"
marker_validation = r'''        _ = try animationChannels.validatedAnimationChannels(for: masks)
        guard Set(markers.map(\.id)).count == markers.count else {
            throw ProjectError.duplicateIdentity("layer marker")
        }
        for marker in markers { _ = try marker.validated(compositionDuration: composition.duration) }
'''
if marker_validation not in text:
    if validation_anchor not in text: raise RuntimeError("ProjectLayer validation anchor missing")
    text = text.replace(validation_anchor, marker_validation, 1)
write(path, text)

# Payloads.
path = "Sources/VertexProject/ProjectCommandPayload.swift"
text = read(path)
anchor = "    case setCompositionBackground(id: VertexID, color: ProjectRGBAColor)\n"
insert = anchor + "    case setCompositionWorkArea(id: VertexID, workArea: ProjectWorkArea?)\n    case setCompositionMarkers(id: VertexID, markers: [ProjectMarker])\n    case applyTimelineEdit(compositionID: VertexID, result: TimelineProjectMutation)\n"
if "case applyTimelineEdit" not in text:
    if anchor not in text: raise RuntimeError("payload composition anchor missing")
    text = text.replace(anchor, insert, 1)
anchor2 = "    case setLayerSource(id: VertexID, source: LayerSource)\n"
insert2 = anchor2 + "    case setLayerMarkers(id: VertexID, markers: [ProjectMarker])\n    case setLayerParent(id: VertexID, parentLayerID: VertexID?)\n"
if "case setLayerMarkers" not in text:
    if anchor2 not in text: raise RuntimeError("payload layer anchor missing")
    text = text.replace(anchor2, insert2, 1)
write(path, text)

# Mutations and inverses.
path = "Sources/VertexProject/ProjectMutation.swift"
text = read(path)
anchor = "    case setCompositionBackground(compositionID: VertexID, before: ProjectRGBAColor, after: ProjectRGBAColor)\n"
insert = anchor + "    case setCompositionWorkArea(compositionID: VertexID, before: ProjectWorkArea?, after: ProjectWorkArea?)\n    case setCompositionMarkers(compositionID: VertexID, before: [ProjectMarker], after: [ProjectMarker])\n    case applyTimelineEdit(compositionID: VertexID, change: TimelineProjectMutation)\n"
if "case applyTimelineEdit" not in text:
    if anchor not in text: raise RuntimeError("mutation composition anchor missing")
    text = text.replace(anchor, insert, 1)
anchor2 = "    case setLayerSource(layerID: VertexID, before: LayerSource, after: LayerSource)\n"
insert2 = anchor2 + "    case setLayerMarkers(layerID: VertexID, before: [ProjectMarker], after: [ProjectMarker])\n    case setLayerParent(layerID: VertexID, before: VertexID?, after: VertexID?)\n"
if "case setLayerMarkers" not in text:
    if anchor2 not in text: raise RuntimeError("mutation layer anchor missing")
    text = text.replace(anchor2, insert2, 1)
inv_anchor = "        case .setCompositionBackground(let id, let before, let after): .setCompositionBackground(compositionID: id, before: after, after: before)\n"
inv_insert = inv_anchor + "        case .setCompositionWorkArea(let id, let before, let after): .setCompositionWorkArea(compositionID: id, before: after, after: before)\n        case .setCompositionMarkers(let id, let before, let after): .setCompositionMarkers(compositionID: id, before: after, after: before)\n        case .applyTimelineEdit(let id, let change): .applyTimelineEdit(compositionID: id, change: change.inverse)\n"
if "case .applyTimelineEdit" not in text:
    if inv_anchor not in text: raise RuntimeError("mutation inverse comp anchor missing")
    text = text.replace(inv_anchor, inv_insert, 1)
inv_anchor2 = "        case .setLayerSource(let id, let before, let after): .setLayerSource(layerID: id, before: after, after: before)\n"
inv_insert2 = inv_anchor2 + "        case .setLayerMarkers(let id, let before, let after): .setLayerMarkers(layerID: id, before: after, after: before)\n        case .setLayerParent(let id, let before, let after): .setLayerParent(layerID: id, before: after, after: before)\n"
if "case .setLayerMarkers" not in text:
    if inv_anchor2 not in text: raise RuntimeError("mutation inverse layer anchor missing")
    text = text.replace(inv_anchor2, inv_insert2, 1)
write(path, text)

# Command engine prepare/apply.
path = "Sources/VertexProject/ProjectCommands.swift"
text = read(path)
prepare_anchor = '''        case .setCompositionBackground(let id, let color):
            guard let composition = document.composition(id: id), color != composition.backgroundColor else { throw ProjectError.invalidOperation("Composition background is unchanged or composition is missing.") }
            _ = try color.validated()
            forward = .setCompositionBackground(compositionID: id, before: composition.backgroundColor, after: color)
'''
prepare_insert = prepare_anchor + r'''
        case .setCompositionWorkArea(let id, let workArea):
            guard let composition = document.composition(id: id), composition.workArea != workArea else {
                throw ProjectError.invalidOperation("Composition work area is unchanged or composition is missing.")
            }
            if let workArea { _ = try workArea.validated(compositionDuration: composition.duration) }
            forward = .setCompositionWorkArea(compositionID: id, before: composition.workArea, after: workArea)

        case .setCompositionMarkers(let id, let markers):
            guard let composition = document.composition(id: id), composition.markers != markers else {
                throw ProjectError.invalidOperation("Composition markers are unchanged or composition is missing.")
            }
            guard Set(markers.map(\.id)).count == markers.count else { throw ProjectError.duplicateIdentity("composition marker") }
            for marker in markers { _ = try marker.validated(compositionDuration: composition.duration) }
            forward = .setCompositionMarkers(compositionID: id, before: composition.markers, after: markers)

        case .applyTimelineEdit(let compositionID, let result):
            _ = try result.validated(compositionID: compositionID)
            guard let composition = document.composition(id: compositionID),
                  composition.layerIDs == result.beforeLayerOrder,
                  document.layers(in: compositionID) == result.beforeLayers,
                  document.selectedLayerID == result.beforeSelectedLayerID else {
                throw ProjectError.invalidOperation("Timeline mutation precondition does not match the current project.")
            }
            let mutation = ProjectMutation.applyTimelineEdit(compositionID: compositionID, change: result)
            var candidate = document
            try apply(mutation, to: &candidate)
            _ = try candidate.validated()
            forward = mutation
'''
if "case .applyTimelineEdit(let compositionID" not in text:
    if prepare_anchor not in text: raise RuntimeError("prepare comp anchor missing")
    text = text.replace(prepare_anchor, prepare_insert, 1)

prepare_anchor2 = '''        case .setLayerSource(let id, let source):
            let layer = try editableLayer(id, in: document)
            guard source != layer.source else { throw ProjectError.invalidOperation("Layer source is unchanged.") }
            forward = .setLayerSource(layerID: id, before: layer.source, after: source)
'''
prepare_insert2 = prepare_anchor2 + r'''

        case .setLayerMarkers(let id, let markers):
            let layer = try editableLayer(id, in: document)
            guard layer.markers != markers, let composition = document.composition(id: layer.compositionID) else {
                throw ProjectError.invalidOperation("Layer markers are unchanged or owner composition is missing.")
            }
            guard Set(markers.map(\.id)).count == markers.count else { throw ProjectError.duplicateIdentity("layer marker") }
            for marker in markers { _ = try marker.validated(compositionDuration: composition.duration) }
            forward = .setLayerMarkers(layerID: id, before: layer.markers, after: markers)

        case .setLayerParent(let id, let parentLayerID):
            let layer = try editableLayer(id, in: document)
            guard layer.parentLayerID != parentLayerID else { throw ProjectError.invalidOperation("Layer parent is unchanged.") }
            var candidate = layer
            candidate.parentLayerID = parentLayerID
            var candidateDocument = document
            if let index = candidateDocument.layerRegistry.firstIndex(where: { $0.id == id }) {
                candidateDocument.layerRegistry[index] = candidate
            }
            _ = try candidate.validated(in: candidateDocument)
            forward = .setLayerParent(layerID: id, before: layer.parentLayerID, after: parentLayerID)
'''
if "case .setLayerMarkers(let id" not in text:
    if prepare_anchor2 not in text: raise RuntimeError("prepare layer anchor missing")
    text = text.replace(prepare_anchor2, prepare_insert2, 1)

# remove layer must respect parenting.
old_guard = '''            guard !document.layerRegistry.contains(where: { $0.trackMatte?.sourceLayerID == id }) else {
                throw ProjectError.invalidOperation("A layer used as a track matte cannot be removed until matte references are cleared.")
            }
            forward = .removeLayer(layer, compositionID: composition.id, index: index)
'''
new_guard = '''            guard !document.layerRegistry.contains(where: { $0.trackMatte?.sourceLayerID == id }) else {
                throw ProjectError.invalidOperation("A layer used as a track matte cannot be removed until matte references are cleared.")
            }
            guard !document.layerRegistry.contains(where: { $0.parentLayerID == id }) else {
                throw ProjectError.invalidOperation("A parent layer cannot be removed until child parent links are cleared.")
            }
            forward = .removeLayer(layer, compositionID: composition.id, index: index)
'''
if new_guard not in text:
    if old_guard not in text: raise RuntimeError("remove layer guard marker missing")
    text = text.replace(old_guard, new_guard, 1)

apply_anchor = '''        case .setCompositionBackground(let id, let before, let after):
            let index = try compositionIndex(id, in: document); guard document.compositionRegistry[index].backgroundColor == before else { throw ProjectError.invalidOperation("Composition background precondition did not match.") }; document.compositionRegistry[index].backgroundColor = after
'''
apply_insert = apply_anchor + r'''        case .setCompositionWorkArea(let id, let before, let after):
            let index = try compositionIndex(id, in: document)
            guard document.compositionRegistry[index].workArea == before else { throw ProjectError.invalidOperation("Composition work-area precondition did not match.") }
            document.compositionRegistry[index].workArea = after
        case .setCompositionMarkers(let id, let before, let after):
            let index = try compositionIndex(id, in: document)
            guard document.compositionRegistry[index].markers == before else { throw ProjectError.invalidOperation("Composition-marker precondition did not match.") }
            document.compositionRegistry[index].markers = after
        case .applyTimelineEdit(let compositionID, let change):
            let compIndex = try compositionIndex(compositionID, in: document)
            guard document.compositionRegistry[compIndex].layerIDs == change.beforeLayerOrder,
                  document.layers(in: compositionID) == change.beforeLayers,
                  document.selectedLayerID == change.beforeSelectedLayerID else {
                throw ProjectError.invalidOperation("Timeline mutation apply precondition did not match.")
            }
            document.layerRegistry.removeAll { $0.compositionID == compositionID }
            document.layerRegistry.append(contentsOf: change.afterLayers)
            document.compositionRegistry[compIndex].layerIDs = change.afterLayerOrder
            document.selectedLayerID = change.afterSelectedLayerID
'''
if "case .setCompositionWorkArea(let id, let before, let after):" not in text:
    if apply_anchor not in text: raise RuntimeError("apply comp anchor missing")
    text = text.replace(apply_anchor, apply_insert, 1)
apply_anchor2 = '''        case .setLayerSource(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].source == before else { throw ProjectError.invalidOperation("Layer source precondition did not match.") }; document.layerRegistry[index].source = after
'''
apply_insert2 = apply_anchor2 + '''        case .setLayerMarkers(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].markers == before else { throw ProjectError.invalidOperation("Layer-marker precondition did not match.") }; document.layerRegistry[index].markers = after
        case .setLayerParent(let id, let before, let after): let index = try layerIndex(id, in: document); guard document.layerRegistry[index].parentLayerID == before else { throw ProjectError.invalidOperation("Layer-parent precondition did not match.") }; document.layerRegistry[index].parentLayerID = after
'''
if "case .setLayerMarkers(let id, let before, let after):" not in text:
    if apply_anchor2 not in text: raise RuntimeError("apply layer anchor missing")
    text = text.replace(apply_anchor2, apply_insert2, 1)
write(path, text)

# Timeline whole-layer moves also move layer markers.
path = "Sources/VertexTimeline/TimelineEngine.swift"
text = read(path)
anchor = '''        result.animationChannels = try result.animationChannels.map { channel in
            var shiftedChannel = channel
            shiftedChannel.keyframes = try channel.keyframes.map { keyframe in
                var shiftedKeyframe = keyframe
                shiftedKeyframe.time = try add(keyframe.time, delta)
                guard shiftedKeyframe.time >= .zero else {
                    throw ProjectError.invalidOperation("Moving the layer would place an animation keyframe before composition time zero.")
                }
                return shiftedKeyframe
            }
            return try shiftedChannel.validated()
        }
        return result
'''
replacement = '''        result.animationChannels = try result.animationChannels.map { channel in
            var shiftedChannel = channel
            shiftedChannel.keyframes = try channel.keyframes.map { keyframe in
                var shiftedKeyframe = keyframe
                shiftedKeyframe.time = try add(keyframe.time, delta)
                guard shiftedKeyframe.time >= .zero else {
                    throw ProjectError.invalidOperation("Moving the layer would place an animation keyframe before composition time zero.")
                }
                return shiftedKeyframe
            }
            return try shiftedChannel.validated()
        }
        result.markers = try result.markers.map { marker in
            var shiftedMarker = marker
            shiftedMarker.time = try add(marker.time, delta)
            return try shiftedMarker.validated(compositionDuration: composition.duration)
        }
        return result
'''
if "result.markers = try result.markers.map" not in text:
    if anchor not in text: raise RuntimeError("shiftedLayer marker anchor missing")
    text = text.replace(anchor, replacement, 1)
write(path, text)

# View model wrappers / imports. These compile only in Xcode, but remain thin command adapters.
path = "App/ProjectWorkspaceViewModel.swift"
text = read(path)
if "import VertexTimeline" not in text:
    text = text.replace("import VertexProjectPersistence\n", "import VertexProjectPersistence\nimport VertexTimeline\n", 1)
insert_anchor = '''    func setLayerTiming(_ timing: LayerTiming) {
        guard let layer = selectedLayer, layer.timing != timing else { return }
        perform(
            .setLayerTiming(id: layer.id, timing: timing),
            mergeKey: "layer.\(layer.id.rawValue).timing"
        )
    }
'''
wrappers = insert_anchor + r'''

    func commitTimelineEdit(_ edit: TimelineEdit, compositionID: VertexID) throws {
        guard let project, let composition = project.composition(id: compositionID) else { return }
        let beforeLayers = project.layers(in: compositionID)
        let result = try TimelineEngine().apply(edit, to: project, compositionID: compositionID)
        var byID = Dictionary(uniqueKeysWithValues: beforeLayers.map { ($0.id, $0) })
        for removed in result.removedLayerIDs { byID.removeValue(forKey: removed) }
        for layer in result.updatedLayers { byID[layer.id] = layer }
        for layer in result.insertedLayers { byID[layer.id] = layer }
        let afterLayers = try result.resultingLayerOrder.map { id -> ProjectLayer in
            guard let layer = byID[id] else { throw ProjectError.invalidOperation("Timeline result omitted a layer snapshot.") }
            return layer
        }
        let afterSelected: VertexID?
        switch edit {
        case .split:
            afterSelected = result.insertedLayers.first?.id ?? project.selectedLayerID
        default:
            afterSelected = project.selectedLayerID
        }
        let mutation = TimelineProjectMutation(
            beforeLayers: beforeLayers,
            afterLayers: afterLayers,
            beforeLayerOrder: composition.layerIDs,
            afterLayerOrder: result.resultingLayerOrder,
            beforeSelectedLayerID: project.selectedLayerID,
            afterSelectedLayerID: afterSelected
        )
        let mergeKey: String?
        switch edit {
        case .move(let ids, _): mergeKey = "timeline.move." + ids.map(\.rawValue).sorted().joined(separator: ".")
        case .trimIn(let id, _), .trimOut(let id, _): mergeKey = "timeline.trim.\(id.rawValue)"
        default: mergeKey = nil
        }
        perform(.applyTimelineEdit(compositionID: compositionID, result: mutation), mergeKey: mergeKey)
    }

    func setLayerParent(layerID: VertexID, parentLayerID: VertexID?) {
        perform(.setLayerParent(id: layerID, parentLayerID: parentLayerID), mergeKey: nil)
    }

    func setWorkArea(_ workArea: ProjectWorkArea?) {
        guard let composition = activeComposition else { return }
        perform(.setCompositionWorkArea(id: composition.id, workArea: workArea), mergeKey: "timeline.workarea.\(composition.id.rawValue)")
    }

    func setCompositionMarkers(_ markers: [ProjectMarker]) {
        guard let composition = activeComposition else { return }
        perform(.setCompositionMarkers(id: composition.id, markers: markers), mergeKey: nil)
    }

    func setLayerMarkers(_ markers: [ProjectMarker]) {
        guard let layer = selectedLayer else { return }
        perform(.setLayerMarkers(id: layer.id, markers: markers), mergeKey: nil)
    }
'''
if "func commitTimelineEdit" not in text:
    if insert_anchor not in text: raise RuntimeError("viewmodel wrapper anchor missing")
    text = text.replace(insert_anchor, wrappers, 1)
write(path, text)

# Xcode project target dependencies.
path = "project.yml"
text = read(path)
needle = '''      - package: Vertex
        product: VertexProject
'''
with_timeline = needle + '''      - package: Vertex
        product: VertexTimeline
'''
if text.count("product: VertexTimeline") < 2:
    # add after VertexProject for app and tests
    text = text.replace(needle, with_timeline, 2)
write(path, text)

print("Task 4 GREEN implementation applied")
