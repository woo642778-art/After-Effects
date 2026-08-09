import SwiftUI
import VertexCore
import VertexProject
import VertexTimeline

struct AETimelineLayerRow: View {
    let layer: ProjectLayer
    let index: Int
    let composition: ProjectComposition
    @ObservedObject var editorState: EditorWorkspaceState
    @Binding var interactionError: String?
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var moveOffset: CGFloat = 0
    @State private var trimInOffset: CGFloat = 0
    @State private var trimOutOffset: CGFloat = 0

    private let transformProperties: [ProjectLayerAnimatableProperty] = [
        .anchorX, .anchorY, .positionX, .positionY, .scaleX, .scaleY, .rotationDegrees, .opacity
    ]

    var body: some View {
        VStack(spacing: 0) {
            layerHeader
            if editorState.expandedLayerIDs.contains(layer.id) {
                groupRow(title: "Transform", expanded: editorState.expandedTransformLayerIDs.contains(layer.id)) {
                    editorState.toggleTransformDisclosure(layer.id)
                }
                if editorState.expandedTransformLayerIDs.contains(layer.id) {
                    ForEach(transformProperties, id: \.self) { property in
                        propertyRow(property)
                    }
                }
                if !layer.effects.isEmpty {
                    groupRow(title: "Effects", expanded: editorState.expandedEffectsLayerIDs.contains(layer.id)) {
                        toggle(&editorState.expandedEffectsLayerIDs)
                    }
                    if editorState.expandedEffectsLayerIDs.contains(layer.id) {
                        ForEach(layer.effects) { effect in
                            simpleSubRow(effectName(effect.type), detail: effect.enabled ? "fx" : "off")
                        }
                    }
                }
                if !layer.masks.isEmpty {
                    groupRow(title: "Masks", expanded: editorState.expandedMasksLayerIDs.contains(layer.id)) {
                        toggle(&editorState.expandedMasksLayerIDs)
                    }
                    if editorState.expandedMasksLayerIDs.contains(layer.id) {
                        ForEach(layer.masks) { mask in simpleSubRow(mask.name, detail: mask.mode.rawValue) }
                    }
                }
            }
        }
        .background(editorState.selectedLayerIDs.contains(layer.id) ? AfterEffectsTheme.selection.opacity(0.55) : Color.clear)
    }

    private var layerHeader: some View {
        HStack(spacing: 0) {
            controls.frame(width: AETimelineView.controlsWidth, height: 34)
            Rectangle().fill(AfterEffectsTheme.border).frame(width: 1)
            timelineBar
                .frame(width: CGFloat(max(600, composition.duration.seconds * editorState.pixelsPerSecond + 80)), height: 34)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editorState.selectLayer(layer.id)
            workspace.selectLayer(layer.id)
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            Button { editorState.toggleLayerDisclosure(layer.id) } label: {
                Image(systemName: editorState.expandedLayerIDs.contains(layer.id) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
            }
            .frame(width: 13)

            Text("\(index + 1)").font(.system(size: 9).monospacedDigit()).frame(width: 20)

            Button { workspace.phase9SetLayerEnabled(layerID: layer.id, value: !layer.enabled) } label: {
                Image(systemName: layer.enabled ? "eye.fill" : "eye.slash")
            }.frame(width: 22)

            Button { workspace.phase9SetLayerSolo(layerID: layer.id, value: !layer.solo) } label: {
                Text("S").font(.system(size: 9, weight: .bold)).foregroundStyle(layer.solo ? .yellow : AfterEffectsTheme.secondaryText)
            }.frame(width: 22)

            Button { workspace.phase9SetLayerLocked(layerID: layer.id, value: !layer.locked) } label: {
                Image(systemName: layer.locked ? "lock.fill" : "lock.open")
            }.frame(width: 22)

            Image(systemName: layer.source.isModelOnly ? "cube" : "square.2.layers.3d")
                .font(.system(size: 9)).frame(width: 22)

            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 1).fill(layerLabelColor).frame(width: 4, height: 19)
                Text(layer.name).font(.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                ForEach(LayerBlendMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue.capitalized) { workspace.phase9SetLayerBlendMode(layerID: layer.id, mode: mode) }
                }
            } label: {
                Text(layer.blendMode.rawValue.prefix(3).uppercased()).font(.system(size: 8).monospaced())
            }.frame(width: 45)

            Menu {
                Button("No Matte") { setMatte(nil) }
                ForEach(workspace.orderedLayers.filter { $0.id != layer.id }) { source in
                    Menu(source.name) {
                        ForEach(ProjectTrackMatteMode.allCases, id: \.self) { mode in
                            Button(matteLabel(mode)) { setMatte(ProjectTrackMatte(sourceLayerID: source.id, mode: mode)) }
                        }
                    }
                }
            } label: {
                Text(layer.trackMatte == nil ? "None" : "Matte").font(.system(size: 8))
            }.frame(width: 48)

            Menu {
                Button("None") { setParent(nil) }
                ForEach(workspace.orderedLayers.filter { $0.id != layer.id }) { candidate in
                    Button(candidate.name) { setParent(candidate.id) }
                }
            } label: {
                Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 9))
            }.frame(width: 48)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AfterEffectsTheme.secondaryText)
        .padding(.horizontal, 2)
    }

    private var timelineBar: some View {
        GeometryReader { _ in
            let startX = CGFloat(layer.timing.inPoint.seconds * editorState.pixelsPerSecond)
            let width = CGFloat(max(4, (layer.timing.outPoint.seconds - layer.timing.inPoint.seconds) * editorState.pixelsPerSecond))
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.015))
                RoundedRectangle(cornerRadius: 2)
                    .fill(layerLabelColor.opacity(layer.enabled ? 0.58 : 0.18))
                    .overlay(alignment: .top) { Rectangle().fill(layerLabelColor.opacity(0.9)).frame(height: 2) }
                    .frame(width: width, height: 24)
                    .offset(x: startX + moveOffset)
                    .gesture(moveGesture)
                    .overlay(alignment: .leading) {
                        Color.clear.frame(width: 10).contentShape(Rectangle()).offset(x: trimInOffset).gesture(trimGesture(edge: .in))
                    }
                    .overlay(alignment: .trailing) {
                        Color.clear.frame(width: 10).contentShape(Rectangle()).offset(x: trimOutOffset).gesture(trimGesture(edge: .out))
                    }
                Rectangle().fill(AfterEffectsTheme.accent.opacity(0.75)).frame(width: 1)
                    .offset(x: CGFloat(editorState.playhead.seconds * editorState.pixelsPerSecond))
            }
        }
    }

    private func groupRow(title: String, expanded: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 5) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.system(size: 7, weight: .bold))
                    Text(title).font(.system(size: 10, weight: .medium))
                    Spacer()
                }
                .padding(.leading, 26)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .frame(width: AETimelineView.controlsWidth, height: 25)
            Rectangle().fill(AfterEffectsTheme.border).frame(width: 1)
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.01))
                Rectangle().fill(AfterEffectsTheme.accent.opacity(0.55)).frame(width: 1)
                    .offset(x: CGFloat(editorState.playhead.seconds * editorState.pixelsPerSecond))
            }
            .frame(width: CGFloat(max(600, composition.duration.seconds * editorState.pixelsPerSecond + 80)), height: 25)
        }
    }

    private func propertyRow(_ property: ProjectLayerAnimatableProperty) -> some View {
        let channel = layer.animationChannels.first { $0.property == .layer(property) }
        return HStack(spacing: 0) {
            HStack(spacing: 5) {
                Button { ensureAnimated(property) } label: {
                    Image(systemName: channel == nil ? "stopwatch" : "stopwatch.fill")
                        .foregroundStyle(channel == nil ? AfterEffectsTheme.tertiaryText : AfterEffectsTheme.accent)
                }
                .buttonStyle(.plain)

                Text(propertyDisplayName(property)).font(.system(size: 10)).frame(width: 74, alignment: .leading)
                Text(propertyValueText(property, channel: channel))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                    .lineLimit(1)
                Spacer()
                if channel != nil {
                    Button { toggleKeyframe(property, channel: channel) } label: {
                        Image(systemName: hasKeyframeAtPlayhead(channel) ? "diamond.fill" : "diamond")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 43)
            .padding(.trailing, 7)
            .foregroundStyle(AfterEffectsTheme.primaryText)
            .frame(width: AETimelineView.controlsWidth, height: 24)

            Rectangle().fill(AfterEffectsTheme.border).frame(width: 1)
            keyframeTrack(channel)
                .frame(width: CGFloat(max(600, composition.duration.seconds * editorState.pixelsPerSecond + 80)), height: 24)
        }
    }

    private func keyframeTrack(_ channel: ProjectAnimationChannel?) -> some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color.white.opacity(0.008))
            if let channel {
                ForEach(channel.keyframes) { keyframe in
                    Button {
                        editorState.selectKeyframe(keyframe.id)
                        editorState.setPlayhead(keyframe.time, composition: composition)
                    } label: {
                        Rectangle()
                            .rotation(.degrees(45))
                            .fill(editorState.selectedKeyframeIDs.contains(keyframe.id) ? AfterEffectsTheme.accent : Color.white.opacity(0.78))
                            .frame(width: 7, height: 7)
                    }
                    .buttonStyle(.plain)
                    .offset(x: CGFloat(keyframe.time.seconds * editorState.pixelsPerSecond) - 3.5)
                }
            }
            Rectangle().fill(AfterEffectsTheme.accent.opacity(0.75)).frame(width: 1)
                .offset(x: CGFloat(editorState.playhead.seconds * editorState.pixelsPerSecond))
        }
    }

    private func simpleSubRow(_ title: String, detail: String) -> some View {
        HStack(spacing: 0) {
            HStack {
                Text(title).font(.system(size: 10)); Spacer(); Text(detail).font(.system(size: 8)).foregroundStyle(AfterEffectsTheme.tertiaryText)
            }
            .padding(.leading, 43).padding(.trailing, 7)
            .frame(width: AETimelineView.controlsWidth, height: 23)
            Rectangle().fill(AfterEffectsTheme.border).frame(width: 1)
            Rectangle().fill(Color.white.opacity(0.008))
                .frame(width: CGFloat(max(600, composition.duration.seconds * editorState.pixelsPerSecond + 80)), height: 23)
        }
        .foregroundStyle(AfterEffectsTheme.secondaryText)
    }

    private func ensureAnimated(_ property: ProjectLayerAnimatableProperty) {
        guard layer.animationChannels.first(where: { $0.property == .layer(property) }) == nil else { return }
        do {
            let key = ProjectKeyframe(time: editorState.playhead, value: .scalar(staticValue(property)), interpolation: .linear)
            let channel = ProjectAnimationChannel(property: .layer(property), keyframes: [key])
            try workspace.setAnimationChannels(layerID: layer.id, channels: layer.animationChannels + [channel])
            interactionError = nil
        } catch { interactionError = error.localizedDescription }
    }

    private func toggleKeyframe(_ property: ProjectLayerAnimatableProperty, channel: ProjectAnimationChannel?) {
        guard let channel else { ensureAnimated(property); return }
        do {
            var channels = layer.animationChannels
            guard let channelIndex = channels.firstIndex(where: { $0.id == channel.id }) else { return }
            if let existing = channel.keyframes.first(where: { $0.time == editorState.playhead }) {
                if channel.keyframes.count == 1 {
                    channels.remove(at: channelIndex)
                } else {
                    channels[channelIndex] = try AnimationEditEngine().removeKeyframes(ids: [existing.id], from: channel)
                }
            } else {
                let value = try channel.evaluatedValue(at: editorState.playhead)
                let key = ProjectKeyframe(time: editorState.playhead, value: value, interpolation: .linear)
                channels[channelIndex] = try AnimationEditEngine().addKeyframe(key, to: channel)
            }
            try workspace.setAnimationChannels(layerID: layer.id, channels: channels)
            interactionError = nil
        } catch { interactionError = error.localizedDescription }
    }

    private func hasKeyframeAtPlayhead(_ channel: ProjectAnimationChannel?) -> Bool {
        channel?.keyframes.contains(where: { $0.time == editorState.playhead }) == true
    }

    private func propertyValueText(_ property: ProjectLayerAnimatableProperty, channel: ProjectAnimationChannel?) -> String {
        let value: Double
        if let channel, case .scalar(let evaluated) = try? channel.evaluatedValue(at: editorState.playhead) { value = evaluated }
        else { value = staticValue(property) }
        switch property {
        case .opacity: return String(format: "%.1f%%", value * 100)
        case .rotationDegrees: return String(format: "%.1f°", value)
        case .scaleX, .scaleY: return String(format: "%.1f%%", value * 100)
        default: return String(format: "%.3f", value)
        }
    }

    private func staticValue(_ property: ProjectLayerAnimatableProperty) -> Double {
        switch property {
        case .positionX: layer.transform.positionX
        case .positionY: layer.transform.positionY
        case .anchorX: layer.transform.anchorX
        case .anchorY: layer.transform.anchorY
        case .scaleX: layer.transform.scaleX
        case .scaleY: layer.transform.scaleY
        case .rotationDegrees: layer.transform.rotationDegrees
        case .opacity: layer.transform.opacity
        }
    }

    private func propertyDisplayName(_ property: ProjectLayerAnimatableProperty) -> String {
        switch property {
        case .positionX: "Position X"; case .positionY: "Position Y"; case .anchorX: "Anchor X"; case .anchorY: "Anchor Y"
        case .scaleX: "Scale X"; case .scaleY: "Scale Y"; case .rotationDegrees: "Rotation"; case .opacity: "Opacity"
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { moveOffset = $0.translation.width }
            .onEnded { value in
                defer { moveOffset = 0 }
                guard !layer.locked else { return }
                do {
                    let delta = try AETimelineInteractionModel.exactDelta(points: Double(value.translation.width), pixelsPerSecond: editorState.pixelsPerSecond, frameRate: composition.frameRate)
                    let edit: TimelineEdit
                    switch editorState.activeTool {
                    case .selection:
                        let selection = editorState.selectedLayerIDs.contains(layer.id) ? editorState.selectedLayerIDs.sorted(by: { $0.rawValue < $1.rawValue }) : [layer.id]
                        edit = .move(layerIDs: selection, delta: delta)
                    case .slip: edit = .slip(layerID: layer.id, sourceDelta: delta)
                    case .slide:
                        let layers = workspace.orderedLayers
                        edit = .slide(layerID: layer.id, delta: delta, previousLayerID: index > 0 ? layers[index - 1].id : nil, nextLayerID: index + 1 < layers.count ? layers[index + 1].id : nil)
                    case .roll:
                        guard index > 0 else { throw ProjectError.invalidOperation("Roll needs a layer immediately before the selected layer.") }
                        edit = .roll(leftLayerID: workspace.orderedLayers[index - 1].id, rightLayerID: layer.id, boundary: try layer.timing.inPoint.adding(delta))
                    case .ripple: throw ProjectError.invalidOperation("Use a layer trim handle while Ripple is selected.")
                    }
                    try workspace.commitTimelineEdit(edit, compositionID: composition.id); interactionError = nil
                } catch { interactionError = error.localizedDescription }
            }
    }

    private func trimGesture(edge: TimelineEdge) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in if edge == .in { trimInOffset = value.translation.width } else { trimOutOffset = value.translation.width } }
            .onEnded { value in
                defer { trimInOffset = 0; trimOutOffset = 0 }
                guard !layer.locked else { return }
                do {
                    let delta = try AETimelineInteractionModel.exactDelta(points: Double(value.translation.width), pixelsPerSecond: editorState.pixelsPerSecond, frameRate: composition.frameRate)
                    let proposed = edge == .in ? try layer.timing.inPoint.adding(delta) : try layer.timing.outPoint.adding(delta)
                    let edit: TimelineEdit
                    if editorState.activeTool == .ripple {
                        let boundary = edge == .in ? layer.timing.inPoint : layer.timing.outPoint
                        let affected = workspace.orderedLayers.filter { $0.id != layer.id && $0.timing.inPoint >= boundary }.map(\.id)
                        edit = .ripple(layerID: layer.id, edge: edge, to: proposed, affectedLayerIDs: affected)
                    } else { edit = edge == .in ? .trimIn(layerID: layer.id, to: proposed) : .trimOut(layerID: layer.id, to: proposed) }
                    try workspace.commitTimelineEdit(edit, compositionID: composition.id); interactionError = nil
                } catch { interactionError = error.localizedDescription }
            }
    }

    private func setParent(_ parentID: VertexID?) { workspace.setLayerParent(layerID: layer.id, parentLayerID: parentID); interactionError = nil }
    private func setMatte(_ matte: ProjectTrackMatte?) { do { try workspace.phase9SetTrackMatte(layerID: layer.id, matte: matte); interactionError = nil } catch { interactionError = error.localizedDescription } }
    private func matteLabel(_ mode: ProjectTrackMatteMode) -> String { switch mode { case .alpha: "Alpha"; case .alphaInverted: "Alpha Inverted"; case .luma: "Luma"; case .lumaInverted: "Luma Inverted" } }
    private func effectName(_ type: ProjectEffectType) -> String { type.displayName }
    private var layerLabelColor: Color { switch index % 8 { case 0: .blue; case 1: .purple; case 2: .green; case 3: .orange; case 4: .pink; case 5: .cyan; case 6: .yellow; default: .indigo } }
    private func toggle(_ set: inout Set<VertexID>) { if set.remove(layer.id) == nil { set.insert(layer.id) } }
}
