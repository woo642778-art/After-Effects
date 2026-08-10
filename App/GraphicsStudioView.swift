import SwiftUI
import UIKit
import VertexProject

struct GraphicsStudioView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var kind: ProjectGraphicKind = .text
    @State private var text = "Vertex"
    @State private var fontSize = 140.0
    @State private var tracking = 0.0
    @State private var lineSpacing = 0.0
    @State private var arcDegrees = 0.0
    @State private var alignment = "center"
    @State private var fillColor = Color.white
    @State private var gradientColor = Color.cyan
    @State private var usesGradient = false
    @State private var gradientAngle = 0.0
    @State private var strokeColor = Color.black
    @State private var strokeWidth = 0.0
    @State private var cornerRadius = 40.0
    @State private var starPoints = 5.0
    @State private var innerRadius = 0.45
    @State private var trimStart = 0.0
    @State private var trimEnd = 1.0
    @State private var repeaterCount = 1.0
    @State private var repeaterRotation = 0.0
    @State private var repeaterOffsetX = 0.0
    @State private var repeaterOffsetY = 0.0
    @State private var previewData: Data?
    @State private var errorMessage: String?

    var body: some View {
        studioBody
            .background(AfterEffectsTheme.background)
            .task { refreshPreview() }
            .onChange(of: previewVersion) { _, _ in refreshPreview() }
    }

    private var studioBody: some View {
        HStack(spacing: 0) {
            controls
                .frame(width: 340)
            Rectangle()
                .fill(AfterEffectsTheme.border)
                .frame(width: 1)
            preview
        }
    }

    private var previewVersion: String {
        [
            kind.rawValue,
            text,
            String(fontSize),
            String(tracking),
            String(lineSpacing),
            String(arcDegrees),
            alignment,
            String(describing: fillColor),
            String(describing: gradientColor),
            String(usesGradient),
            String(gradientAngle),
            String(describing: strokeColor),
            String(strokeWidth),
            String(cornerRadius),
            String(starPoints),
            String(innerRadius),
            String(trimStart),
            String(trimEnd),
            String(repeaterCount),
            String(repeaterRotation),
            String(repeaterOffsetX),
            String(repeaterOffsetY),
            String(workspace.activeComposition?.width ?? 0),
            String(workspace.activeComposition?.height ?? 0)
        ].joined(separator: "|")
    }

    private var controls: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TEXT & VECTOR")
                    .font(.caption.bold())
                    .foregroundStyle(AfterEffectsTheme.accent)
                Spacer()
                Text("v13")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(AfterEffectsTheme.elevatedPanel)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Type", selection: $kind) {
                        Text("Text").tag(ProjectGraphicKind.text)
                        Text("Rectangle").tag(ProjectGraphicKind.rectangle)
                        Text("Ellipse").tag(ProjectGraphicKind.ellipse)
                        Text("Star").tag(ProjectGraphicKind.star)
                    }
                    .pickerStyle(.segmented)

                    if kind == .text { textControls } else { vectorControls }
                    fillControls
                    strokeControls

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    Button {
                        addToTimeline()
                    } label: {
                        Label("Add as Editable Timeline Graphic", systemImage: "plus.rectangle.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(workspace.activeComposition == nil)

                    Text("The graphic is rendered at the active composition resolution, registered as project media, and inserted into the real layer/timeline pipeline. Layer transforms, masks, keyframes, blending and effects remain available after insertion.")
                        .font(.caption2)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
                .padding(12)
            }
        }
        .background(AfterEffectsTheme.panel)
    }

    private var textControls: some View {
        Group {
            TextField("Text", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            Picker("Alignment", selection: $alignment) {
                Text("Left").tag("left")
                Text("Center").tag("center")
                Text("Right").tag("right")
            }
            .pickerStyle(.segmented)
            labeledSlider("Font Size", value: $fontSize, range: 8...700, format: "%.0f")
            labeledSlider("Tracking", value: $tracking, range: -40...120, format: "%.1f")
            labeledSlider("Line Spacing", value: $lineSpacing, range: -20...160, format: "%.1f")
            labeledSlider("Text on Path Arc", value: $arcDegrees, range: -300...300, format: "%.0f°")
        }
    }

    private var vectorControls: some View {
        Group {
            if kind == .rectangle {
                labeledSlider("Corner Radius", value: $cornerRadius, range: 0...400, format: "%.0f")
            }
            if kind == .star {
                labeledSlider("Star Points", value: $starPoints, range: 3...20, step: 1, format: "%.0f")
                labeledSlider("Inner Radius", value: $innerRadius, range: 0.1...0.9, format: "%.2f")
            }
            labeledSlider("Trim Start", value: $trimStart, range: 0...trimEnd, format: "%.2f")
            labeledSlider("Trim End", value: $trimEnd, range: trimStart...1, format: "%.2f")
            labeledSlider("Repeater", value: $repeaterCount, range: 1...24, step: 1, format: "%.0f")
            labeledSlider("Repeat Rotation", value: $repeaterRotation, range: -180...180, format: "%.0f°")
            labeledSlider("Repeat X", value: $repeaterOffsetX, range: -300...300, format: "%.0f")
            labeledSlider("Repeat Y", value: $repeaterOffsetY, range: -300...300, format: "%.0f")
        }
    }

    private var fillControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Gradient Fill", isOn: $usesGradient)
                .font(.caption)
            ColorPicker("Fill", selection: $fillColor, supportsOpacity: true)
                .font(.caption)
            if usesGradient {
                ColorPicker("Gradient End", selection: $gradientColor, supportsOpacity: true)
                    .font(.caption)
                labeledSlider("Gradient Angle", value: $gradientAngle, range: -180...180, format: "%.0f°")
            }
        }
        .padding(10)
        .background(AfterEffectsTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var strokeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            ColorPicker("Stroke", selection: $strokeColor, supportsOpacity: true)
                .font(.caption)
            labeledSlider("Stroke Width", value: $strokeWidth, range: 0...80, format: "%.1f")
        }
        .padding(10)
        .background(AfterEffectsTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var preview: some View {
        VStack(spacing: 0) {
            HStack {
                Text("GRAPHIC PREVIEW")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                Spacer()
                if let composition = workspace.activeComposition {
                    Text("\(composition.width) × \(composition.height)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AfterEffectsTheme.tertiaryText)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(AfterEffectsTheme.elevatedPanel)

            GeometryReader { proxy in
                ZStack {
                    Color.black.opacity(0.78)
                    checkerboard
                    if let previewData, let image = UIImage(data: previewData) {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .padding(30)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let cell: CGFloat = 18
            for y in stride(from: 0.0, to: size.height, by: cell) {
                for x in stride(from: 0.0, to: size.width, by: cell) {
                    let even = (Int(x / cell) + Int(y / cell)).isMultiple(of: 2)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: cell, height: cell)),
                        with: .color(even ? .white.opacity(0.035) : .white.opacity(0.07))
                    )
                }
            }
        }
    }

    private func labeledSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double? = nil,
        format: String
    ) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.primaryText)
            }
            if let step {
                Slider(value: value, in: range, step: step)
            } else {
                Slider(value: value, in: range)
            }
        }
    }

    private func document() throws -> ProjectGraphicDocument {
        let width = workspace.activeComposition?.width ?? 1920
        let height = workspace.activeComposition?.height ?? 1080
        let primary = projectColor(fillColor)
        let fill: ProjectGraphicFill = usesGradient
            ? .linearGradient(start: primary, end: projectColor(gradientColor), angleDegrees: gradientAngle)
            : .solid(primary)
        let stroke = ProjectGraphicStroke(color: projectColor(strokeColor), width: strokeWidth)
        if kind == .text {
            return try ProjectGraphicDocument(
                kind: .text,
                canvasWidth: width,
                canvasHeight: height,
                fill: fill,
                stroke: stroke,
                text: ProjectTextGraphic(
                    text: text,
                    fontSize: fontSize,
                    tracking: tracking,
                    lineSpacing: lineSpacing,
                    alignment: alignment,
                    pathArcDegrees: arcDegrees
                )
            ).validated()
        }
        return try ProjectGraphicDocument(
            kind: kind,
            canvasWidth: width,
            canvasHeight: height,
            fill: fill,
            stroke: stroke,
            vector: ProjectVectorGraphic(
                cornerRadius: cornerRadius,
                starPoints: Int(starPoints.rounded()),
                innerRadius: innerRadius,
                trimStart: trimStart,
                trimEnd: trimEnd,
                repeaterCount: Int(repeaterCount.rounded()),
                repeaterRotationDegrees: repeaterRotation,
                repeaterOffsetX: repeaterOffsetX,
                repeaterOffsetY: repeaterOffsetY
            )
        ).validated()
    }

    private func refreshPreview() {
        do {
            previewData = try GeneratedGraphicRenderer.pngData(for: document())
            errorMessage = nil
        } catch {
            previewData = nil
            errorMessage = error.localizedDescription
        }
    }

    private func addToTimeline() {
        do {
            let document = try document()
            let name = kind == .text ? String(text.prefix(32)) : kind.rawValue.capitalized
            workspace.addGeneratedGraphic(document, name: name.isEmpty ? "Text" : name)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func projectColor(_ color: Color) -> ProjectRGBAColor {
        let resolved = UIColor(color)
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return ProjectRGBAColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
