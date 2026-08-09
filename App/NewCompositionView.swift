import SwiftUI
import UIKit
import VertexCore
import VertexProject

enum CompositionFrameRateChoice: String, CaseIterable, Identifiable, Sendable {
    case fps23976
    case fps24
    case fps25
    case fps2997
    case fps30
    case fps50
    case fps5994
    case fps60
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fps23976: "23.976"
        case .fps24: "24"
        case .fps25: "25"
        case .fps2997: "29.97"
        case .fps30: "30"
        case .fps50: "50"
        case .fps5994: "59.94"
        case .fps60: "60"
        case .custom: "Custom"
        }
    }

    func rational(customText: String) throws -> RationalTime {
        switch self {
        case .fps23976: return RationalTime(value: 24_000, timescale: 1_001)
        case .fps24: return RationalTime(value: 24, timescale: 1)
        case .fps25: return RationalTime(value: 25, timescale: 1)
        case .fps2997: return RationalTime(value: 30_000, timescale: 1_001)
        case .fps30: return RationalTime(value: 30, timescale: 1)
        case .fps50: return RationalTime(value: 50, timescale: 1)
        case .fps5994: return RationalTime(value: 60_000, timescale: 1_001)
        case .fps60: return RationalTime(value: 60, timescale: 1)
        case .custom:
            guard let value = Double(customText.trimmingCharacters(in: .whitespacesAndNewlines)),
                  value.isFinite,
                  value >= 1,
                  value <= 240 else {
                throw NewCompositionDraftError.invalidFrameRate
            }
            let denominator: Int32 = 1_000_000
            let numerator = Int64((value * Double(denominator)).rounded())
            guard numerator > 0, numerator <= Int64(Int32.max) else {
                throw NewCompositionDraftError.invalidFrameRate
            }
            return RationalTime(value: numerator, timescale: denominator)
        }
    }
}

enum NewCompositionPreset: String, CaseIterable, Identifiable, Sendable {
    case hdtv10802997
    case hdtv108025
    case hdtv108024
    case uhd4K23976
    case uhd4K2997
    case uhd4K5994
    case vertical108030
    case square108030
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hdtv10802997: "HDTV 1080 29.97"
        case .hdtv108025: "HDTV 1080 25"
        case .hdtv108024: "HDTV 1080 24"
        case .uhd4K23976: "UHD 4K 23.976"
        case .uhd4K2997: "UHD 4K 29.97"
        case .uhd4K5994: "UHD 4K 59.94"
        case .vertical108030: "Vertical 1080 × 1920 30"
        case .square108030: "Square 1080 × 1080 30"
        case .custom: "Custom"
        }
    }
}

enum NewCompositionDraftError: LocalizedError, Equatable {
    case invalidName
    case invalidDimensions
    case invalidFrameRate
    case invalidDuration
    case invalidStartTime
    case invalidBPM
    case timeOverflow

    var errorDescription: String? {
        switch self {
        case .invalidName: "Composition name cannot be empty."
        case .invalidDimensions: "Width and height must be between 1 and 8192 pixels."
        case .invalidFrameRate: "Frame rate must be between 1 and 240 fps."
        case .invalidDuration: "Duration must be a positive finite value."
        case .invalidStartTime: "Start time must be finite."
        case .invalidBPM: "BPM must be empty or within 1...999."
        case .timeOverflow: "The requested time cannot be represented exactly."
        }
    }
}

struct NewCompositionDraft: Equatable, Sendable {
    var name = "Comp 1"
    var preset: NewCompositionPreset = .hdtv10802997
    var width = 1920
    var height = 1080
    var lockAspectRatio = true
    var frameRateChoice: CompositionFrameRateChoice = .fps2997
    var customFrameRateText = "30"
    var durationSeconds = 10.0
    var displayStartSeconds = 0.0
    var previewResolution: ProjectCompositionPreviewResolution = .full
    var bpmText = ""
    var motionBlurShutterAngle = 180.0
    var motionBlurShutterPhase = -90.0

    mutating func apply(_ preset: NewCompositionPreset) {
        self.preset = preset
        switch preset {
        case .hdtv10802997:
            width = 1920; height = 1080; frameRateChoice = .fps2997
        case .hdtv108025:
            width = 1920; height = 1080; frameRateChoice = .fps25
        case .hdtv108024:
            width = 1920; height = 1080; frameRateChoice = .fps24
        case .uhd4K23976:
            width = 3840; height = 2160; frameRateChoice = .fps23976
        case .uhd4K2997:
            width = 3840; height = 2160; frameRateChoice = .fps2997
        case .uhd4K5994:
            width = 3840; height = 2160; frameRateChoice = .fps5994
        case .vertical108030:
            width = 1080; height = 1920; frameRateChoice = .fps30
        case .square108030:
            width = 1080; height = 1080; frameRateChoice = .fps30
        case .custom:
            break
        }
    }

    func makeComposition(
        color: ColorDescriptor,
        backgroundColor: ProjectRGBAColor
    ) throws -> ProjectComposition {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw NewCompositionDraftError.invalidName }
        guard (1...8192).contains(width), (1...8192).contains(height) else {
            throw NewCompositionDraftError.invalidDimensions
        }
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw NewCompositionDraftError.invalidDuration
        }
        guard displayStartSeconds.isFinite else {
            throw NewCompositionDraftError.invalidStartTime
        }

        let frameRate = try frameRateChoice.rational(customText: customFrameRateText)
        let duration = try exactFrameTime(seconds: durationSeconds, frameRate: frameRate)
        let startTime = try exactFrameTime(seconds: displayStartSeconds, frameRate: frameRate)

        let bpm: Double?
        let trimmedBPM = bpmText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBPM.isEmpty {
            bpm = nil
        } else if let value = Double(trimmedBPM), value.isFinite, (1...999).contains(value) {
            bpm = value
        } else {
            throw NewCompositionDraftError.invalidBPM
        }

        return try ProjectComposition(
            name: trimmedName,
            width: width,
            height: height,
            duration: duration,
            frameRate: frameRate,
            color: color,
            backgroundColor: backgroundColor,
            layerIDs: [],
            displayStartTime: startTime,
            pixelAspectRatio: 1,
            previewResolution: previewResolution,
            bpm: bpm,
            motionBlurShutterAngle: motionBlurShutterAngle,
            motionBlurShutterPhase: motionBlurShutterPhase,
            rendererMode: .classic2D
        ).validated(layerByID: [:])
    }

    private func exactFrameTime(seconds: Double, frameRate: RationalTime) throws -> RationalTime {
        let frameCount = (seconds * frameRate.seconds).rounded()
        guard frameCount.isFinite,
              frameCount >= Double(Int64.min),
              frameCount <= Double(Int64.max),
              frameRate.value > 0,
              frameRate.value <= Int64(Int32.max) else {
            throw NewCompositionDraftError.timeOverflow
        }
        let numerator = Int64(frameCount).multipliedReportingOverflow(by: Int64(frameRate.timescale))
        guard !numerator.overflow else { throw NewCompositionDraftError.timeOverflow }
        return RationalTime(value: numerator.partialValue, timescale: Int32(frameRate.value))
    }
}

private enum NewCompositionTab: String, CaseIterable, Identifiable {
    case basic = "Basic"
    case advanced = "Advanced"
    case renderer = "3D Renderer"
    var id: String { rawValue }
}

struct NewCompositionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    let onSubmitted: (VertexID) -> Void

    @State private var draft = NewCompositionDraft()
    @State private var selectedTab: NewCompositionTab = .basic
    @State private var backgroundColor = Color.black
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Composition Settings")
                    .font(.headline)
                    .foregroundStyle(AfterEffectsTheme.primaryText)
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 48)
            .background(AfterEffectsTheme.elevatedPanel)

            Picker("Settings", selection: $selectedTab) {
                ForEach(NewCompositionTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            ScrollView {
                Group {
                    switch selectedTab {
                    case .basic: basicSettings
                    case .advanced: advancedSettings
                    case .renderer: rendererSettings
                    }
                }
                .padding(18)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
            }

            Divider().overlay(AfterEffectsTheme.border)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("OK") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(AfterEffectsTheme.accent)
            }
            .padding(14)
            .background(AfterEffectsTheme.elevatedPanel)
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 520, idealHeight: 610)
        .background(AfterEffectsTheme.panel)
        .preferredColorScheme(.dark)
    }

    private var basicSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingRow("Composition Name") {
                TextField("Comp 1", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
            }

            settingRow("Preset") {
                Picker("Preset", selection: presetBinding) {
                    ForEach(NewCompositionPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .labelsHidden()
            }

            HStack(spacing: 12) {
                settingRow("Width") {
                    TextField("1920", value: widthBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
                settingRow("Height") {
                    TextField("1080", value: heightBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Toggle("Lock Aspect Ratio", isOn: $draft.lockAspectRatio)
                .font(.caption)

            settingRow("Pixel Aspect Ratio") {
                Text("Square Pixels (1.0)")
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }

            settingRow("Frame Rate") {
                HStack {
                    Picker("Frame Rate", selection: $draft.frameRateChoice) {
                        ForEach(CompositionFrameRateChoice.allCases) { rate in
                            Text(rate.title).tag(rate)
                        }
                    }
                    .labelsHidden()
                    if draft.frameRateChoice == .custom {
                        TextField("fps", text: $draft.customFrameRateText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }
            }

            settingRow("Duration (seconds)") {
                TextField("10", value: $draft.durationSeconds, format: .number.precision(.fractionLength(0...3)))
                    .textFieldStyle(.roundedBorder)
            }

            settingRow("Start Time (seconds)") {
                TextField("0", value: $draft.displayStartSeconds, format: .number.precision(.fractionLength(0...3)))
                    .textFieldStyle(.roundedBorder)
            }

            settingRow("Background Color") {
                ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)
                    .labelsHidden()
            }
        }
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingRow("Preview Resolution") {
                Picker("Preview Resolution", selection: $draft.previewResolution) {
                    Text("Full").tag(ProjectCompositionPreviewResolution.full)
                    Text("Half").tag(ProjectCompositionPreviewResolution.half)
                    Text("Third").tag(ProjectCompositionPreviewResolution.third)
                    Text("Quarter").tag(ProjectCompositionPreviewResolution.quarter)
                }
                .labelsHidden()
            }

            settingRow("BPM") {
                TextField("Optional", text: $draft.bpmText)
                    .textFieldStyle(.roundedBorder)
            }

            settingRow("Shutter Angle") {
                TextField("180", value: $draft.motionBlurShutterAngle, format: .number)
                    .textFieldStyle(.roundedBorder)
            }

            settingRow("Shutter Phase") {
                TextField("-90", value: $draft.motionBlurShutterPhase, format: .number)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var rendererSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingRow("Renderer") {
                Text("Classic 2D")
                    .foregroundStyle(AfterEffectsTheme.primaryText)
            }
            Text("Vertex2 11.0 keeps the canonical timeline renderer in the verified 2D composition pipeline. The dedicated 3D Scene workspace remains separate until later 3D timeline integration is release-qualified.")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var presetBinding: Binding<NewCompositionPreset> {
        Binding(
            get: { draft.preset },
            set: { draft.apply($0) }
        )
    }

    private var widthBinding: Binding<Int> {
        Binding(
            get: { draft.width },
            set: { newValue in
                let oldWidth = max(1, draft.width)
                let ratio = Double(draft.height) / Double(oldWidth)
                draft.width = newValue
                if draft.lockAspectRatio {
                    draft.height = max(1, Int((Double(newValue) * ratio).rounded()))
                }
                draft.preset = .custom
            }
        )
    }

    private var heightBinding: Binding<Int> {
        Binding(
            get: { draft.height },
            set: { newValue in
                let oldHeight = max(1, draft.height)
                let ratio = Double(draft.width) / Double(oldHeight)
                draft.height = newValue
                if draft.lockAspectRatio {
                    draft.width = max(1, Int((Double(newValue) * ratio).rounded()))
                }
                draft.preset = .custom
            }
        )
    }

    private func settingRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
                .frame(width: 150, alignment: .trailing)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func submit() {
        guard let project = workspace.project else {
            errorMessage = "No project is open."
            return
        }
        do {
            let composition = try draft.makeComposition(
                color: project.settings.color,
                backgroundColor: rgba(from: backgroundColor)
            )
            try workspace.insertNewComposition(composition)
            onSubmitted(composition.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rgba(from color: Color) -> ProjectRGBAColor {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .black
        }
        return ProjectRGBAColor(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
    }
}
