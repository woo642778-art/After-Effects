import SwiftUI
import VertexCore
import VertexProject

enum GraphEditorMathError: Error, Equatable {
    case nonFiniteHandle
}

struct GraphEditorMath {
    static func temporalHandle(x: Double, y: Double) throws -> ProjectBezierHandle {
        guard x.isFinite, y.isFinite else { throw GraphEditorMathError.nonFiniteHandle }
        return try ProjectBezierHandle(x: min(max(x, 0), 1), y: y).validated()
    }

    static func adjustedInfluence(
        _ source: ProjectBezierHandle,
        deltaX: Double,
        deltaY: Double
    ) throws -> ProjectBezierHandle {
        try temporalHandle(x: source.x + deltaX, y: source.y + deltaY)
    }

    static func scalar(_ value: ProjectAnimatableValue) -> Double? {
        guard case .scalar(let scalar) = value else { return nil }
        return scalar
    }

    static func segmentSpeed(left: ProjectKeyframe, right: ProjectKeyframe) -> Double? {
        guard let lhs = scalar(left.value), let rhs = scalar(right.value) else { return nil }
        let dt = right.time.seconds - left.time.seconds
        guard dt.isFinite, dt > 0 else { return nil }
        let value = (rhs - lhs) / dt
        return value.isFinite ? value : nil
    }
}

struct GraphEditorView: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GRAPH EDITOR")
                    .font(.caption.bold())
                    .foregroundStyle(AfterEffectsTheme.accent)
                Spacer()
                Picker("Graph", selection: graphMode) {
                    Text("Value").tag(GraphEditorMode.value)
                    Text("Speed").tag(GraphEditorMode.speed)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 190)
            }

            if let layer = workspace.selectedLayer {
                let channels = scalarChannels(layer)
                if channels.isEmpty {
                    Text("Selected layer has no scalar keyframe channels.")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    ForEach(channels) { channel in
                        channelEditor(layer: layer, channel: channel)
                    }
                }
            } else {
                Text("Select a layer to edit animation curves.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
    }

    private var graphMode: Binding<GraphEditorMode> {
        Binding(
            get: { editorState.graphMode ?? .value },
            set: { editorState.graphMode = $0 }
        )
    }

    private func scalarChannels(_ layer: ProjectLayer) -> [ProjectAnimationChannel] {
        layer.animationChannels.filter { channel in
            channel.property.expectedValueKind == .scalar && channel.keyframes.count >= 2
        }
    }

    private func channelEditor(layer: ProjectLayer, channel: ProjectAnimationChannel) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(channel.property.stableSortKey)
                .font(.caption2.monospaced())
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            GeometryReader { proxy in
                let values = channel.keyframes.compactMap { GraphEditorMath.scalar($0.value) }
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 1
                let valueSpan = max(0.000_001, maxValue - minValue)
                ZStack {
                    Canvas { context, size in
                        guard channel.keyframes.count >= 2 else { return }
                        var path = Path()
                        for (index, keyframe) in channel.keyframes.enumerated() {
                            let x = xPosition(keyframe.time, width: size.width)
                            let y = yPosition(
                                keyframe: keyframe,
                                channel: channel,
                                mode: graphMode.wrappedValue,
                                minValue: minValue,
                                span: valueSpan,
                                height: size.height
                            )
                            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        context.stroke(path, with: .color(AfterEffectsTheme.accent), lineWidth: 1.5)
                    }

                    ForEach(channel.keyframes) { keyframe in
                        let x = xPosition(keyframe.time, width: proxy.size.width)
                        let y = yPosition(
                            keyframe: keyframe,
                            channel: channel,
                            mode: graphMode.wrappedValue,
                            minValue: minValue,
                            span: valueSpan,
                            height: proxy.size.height
                        )
                        Circle()
                            .fill(editorState.selectedKeyframeIDs.contains(keyframe.id) ? AfterEffectsTheme.accent : Color.white)
                            .frame(width: 9, height: 9)
                            .position(x: x, y: y)
                            .contentShape(Rectangle().inset(by: -10))
                            .onTapGesture {
                                editorState.selectedKeyframeIDs = [keyframe.id]
                            }
                            .gesture(handleGesture(layer: layer, channel: channel, keyframe: keyframe))
                    }
                }
            }
            .frame(height: 130)
            .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private func handleGesture(
        layer: ProjectLayer,
        channel: ProjectAnimationChannel,
        keyframe: ProjectKeyframe
    ) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onEnded { drag in
                do {
                    let base = keyframe.outgoingTemporalHandle ?? ProjectBezierHandle(x: 1.0 / 3.0, y: 1.0 / 3.0)
                    let updated = try GraphEditorMath.adjustedInfluence(
                        base,
                        deltaX: Double(drag.translation.width) / 180,
                        deltaY: -Double(drag.translation.height) / 120
                    )
                    try workspace.phase9UpdateTemporalHandle(
                        layerID: layer.id,
                        channelID: channel.id,
                        keyframeID: keyframe.id,
                        incoming: keyframe.incomingTemporalHandle,
                        outgoing: updated
                    )
                    editorState.selectedKeyframeIDs = [keyframe.id]
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
    }

    private func xPosition(_ time: RationalTime, width: CGFloat) -> CGFloat {
        guard let composition = workspace.activeComposition, composition.duration.seconds > 0 else { return 0 }
        return CGFloat(min(max(time.seconds / composition.duration.seconds, 0), 1)) * width
    }

    private func yPosition(
        keyframe: ProjectKeyframe,
        channel: ProjectAnimationChannel,
        mode: GraphEditorMode,
        minValue: Double,
        span: Double,
        height: CGFloat
    ) -> CGFloat {
        let normalized: Double
        switch mode {
        case .value:
            let scalar = GraphEditorMath.scalar(keyframe.value) ?? minValue
            normalized = min(max((scalar - minValue) / span, 0), 1)
        case .speed:
            guard let index = channel.keyframes.firstIndex(where: { $0.id == keyframe.id }) else { return height / 2 }
            let speed: Double
            if index + 1 < channel.keyframes.count {
                speed = GraphEditorMath.segmentSpeed(left: keyframe, right: channel.keyframes[index + 1]) ?? 0
            } else if index > 0 {
                speed = GraphEditorMath.segmentSpeed(left: channel.keyframes[index - 1], right: keyframe) ?? 0
            } else { speed = 0 }
            normalized = 0.5 + 0.5 * tanh(speed / max(span, 0.000_001))
        }
        return height * CGFloat(1 - normalized)
    }
}
