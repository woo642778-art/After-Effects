import SwiftUI
import VertexCore
import VertexProject

struct VertexEffectCatalogEntry: Equatable, Identifiable, Sendable {
    let type: ProjectEffectType
    let name: String
    let category: String
    let keywords: [String]
    let description: String

    var id: ProjectEffectType { type }
}

enum VertexEffectCatalog {
    static let entries: [VertexEffectCatalogEntry] = [
        .init(type: .gaussianBlur, name: "Gaussian Blur", category: "Blur & Sharpen", keywords: ["blur", "gaussian", "soften"], description: "True Gaussian blur processed through Core Image in the shared preview/export effect path."),
        .init(type: .sharpen, name: "Sharpen", category: "Blur & Sharpen", keywords: ["sharpen", "sharpness", "detail"], description: "Luminance sharpening with keyframable sharpness."),
        .init(type: .exposure, name: "Exposure", category: "Color Correction", keywords: ["exposure", "ev", "stops", "light"], description: "Exposure adjustment in photographic stops."),
        .init(type: .colorControls, name: "Color Controls", category: "Color Correction", keywords: ["brightness", "contrast", "saturation", "color"], description: "Brightness, contrast, and saturation controls in one stackable effect."),
        .init(type: .hueAdjust, name: "Hue Adjust", category: "Color Correction", keywords: ["hue", "color", "rotate", "angle"], description: "Rotate hue by a keyframable angle."),
        .init(type: .invert, name: "Invert", category: "Channel", keywords: ["invert", "negative", "channel"], description: "Invert image channels using the native pixel processor."),
        .init(type: .depthMap, name: "Depth Map", category: "AI", keywords: ["depth", "depth anything", "z", "3d channel"], description: "Generate an editable depth representation from the selected media layer."),
        .init(type: .cutout, name: "Cutout", category: "AI", keywords: ["cutout", "mask", "foreground", "person", "remove background"], description: "Create a foreground alpha matte with on-device segmentation."),
        .init(type: .upscale, name: "Upscale", category: "AI", keywords: ["upscale", "super resolution", "resolution", "4x"], description: "Increase source detail and resolution with the bundled RealESRGAN model."),
        .init(type: .restore, name: "Restore", category: "AI", keywords: ["restore", "denoise", "deblur", "artifact", "detail"], description: "Denoise and restore compressed or degraded footage.")
    ]

    static func search(_ query: String) -> [VertexEffectCatalogEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return entries }
        return entries
            .compactMap { entry -> (VertexEffectCatalogEntry, Int)? in
                let fields = [entry.name, entry.category] + entry.keywords
                let scores = fields.map { matchScore(query: normalized, candidate: $0.lowercased()) }
                guard let score = scores.max(), score > 0 else { return nil }
                return (entry, score)
            }
            .sorted {
                if $0.1 == $1.1 { return $0.0.name < $1.0.name }
                return $0.1 > $1.1
            }
            .map(\.0)
    }

    private static func matchScore(query: String, candidate: String) -> Int {
        if candidate == query { return 1000 }
        if candidate.hasPrefix(query) { return 800 - max(0, candidate.count - query.count) }
        if candidate.contains(query) { return 600 - max(0, candidate.count - query.count) }

        var queryIndex = query.startIndex
        var matched = 0
        var gapPenalty = 0
        var previousMatch: String.Index?
        for index in candidate.indices where queryIndex < query.endIndex {
            if candidate[index] == query[queryIndex] {
                matched += 1
                if let previousMatch {
                    gapPenalty += candidate.distance(from: candidate.index(after: previousMatch), to: index)
                }
                previousMatch = index
                query.formIndex(after: &queryIndex)
            }
        }
        guard queryIndex == query.endIndex else { return 0 }
        return 300 + matched * 10 - gapPenalty
    }
}

struct EffectsAndPresetsView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var query = ""
    @State private var expandedCategories: Set<String> = ["AI", "Blur & Sharpen", "Color Correction", "Channel"]
    @State private var errorMessage: String?
    @FocusState private var searchFocused: Bool

    private var filtered: [VertexEffectCatalogEntry] { VertexEffectCatalog.search(query) }

    var body: some View {
        VStack(spacing: 0) {
            quickFXHeader
            searchField
            Divider().overlay(AfterEffectsTheme.border)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(categories, id: \.self) { category in categorySection(category) }
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AfterEffectsTheme.elevatedPanel)
            }
        }
        .background(AfterEffectsTheme.panel)
    }

    private var quickFXHeader: some View {
        HStack(spacing: 8) {
            Button {
                query = ""
                searchFocused = true
            } label: {
                Label("Quick FX", systemImage: "bolt.fill")
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AfterEffectsTheme.accent)
            Spacer()
            Text("Search → Apply")
                .font(.system(size: 9))
                .foregroundStyle(AfterEffectsTheme.tertiaryText)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(AfterEffectsTheme.elevatedPanel)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.tertiaryText)
            TextField("Search Effects & Presets", text: $query)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.primaryText)
                .focused($searchFocused)
                .onSubmit {
                    if let first = filtered.first { apply(first) }
                }
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(AfterEffectsTheme.surface)
    }

    private var categories: [String] {
        var seen = Set<String>()
        return filtered.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }

    private func categorySection(_ category: String) -> some View {
        let entries = filtered.filter { $0.category == category }
        return VStack(spacing: 0) {
            Button {
                if expandedCategories.contains(category) { expandedCategories.remove(category) }
                else { expandedCategories.insert(category) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expandedCategories.contains(category) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold)).frame(width: 11)
                    Text(category).font(.caption2.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(AfterEffectsTheme.secondaryText)
                .padding(.horizontal, 7)
                .frame(height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedCategories.contains(category) || !query.isEmpty {
                ForEach(entries) { entry in effectRow(entry) }
            }
        }
    }

    private func effectRow(_ entry: VertexEffectCatalogEntry) -> some View {
        Button { apply(entry) } label: {
            HStack(spacing: 7) {
                Image(systemName: icon(for: entry.type))
                    .font(.caption2).frame(width: 16)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name).font(.caption).foregroundStyle(AfterEffectsTheme.primaryText)
                    Text(entry.description).font(.system(size: 9)).foregroundStyle(AfterEffectsTheme.tertiaryText).lineLimit(1)
                }
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canApplyEffects)
        .help(canApplyEffects ? "Apply \(entry.name) to the selected layer" : "Select a media layer first")
    }

    private var canApplyEffects: Bool {
        guard let layer = workspace.selectedLayer else { return false }
        if case .media = layer.source { return !layer.locked }
        return false
    }

    private func apply(_ entry: VertexEffectCatalogEntry) {
        guard let layer = workspace.selectedLayer else {
            errorMessage = "Select a media layer before applying an effect."
            return
        }
        let effect = ProjectEffect.makeDefault(entry.type)
        workspace.perform(
            .insertLayerEffect(id: layer.id, effect: effect, index: layer.effects.count),
            mergeKey: nil
        )
        query = ""
        searchFocused = false
        errorMessage = nil
    }

    private func icon(for type: ProjectEffectType) -> String {
        switch type {
        case .depthMap: "square.3.layers.3d"
        case .cutout: "person.crop.rectangle"
        case .upscale: "arrow.up.left.and.arrow.down.right"
        case .restore: "wand.and.stars"
        case .gaussianBlur: "drop.halffull"
        case .sharpen: "sparkle.magnifyingglass"
        case .exposure: "sun.max"
        case .colorControls: "slider.horizontal.3"
        case .hueAdjust: "paintpalette"
        case .invert: "circle.lefthalf.filled"
        }
    }
}
