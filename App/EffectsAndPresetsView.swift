import SwiftUI
import VertexCore
import VertexProject

struct VertexEffectCatalogEntry: Equatable, Identifiable, Sendable {
    let descriptor: ProjectEffectDescriptor
    var id: ProjectEffectType { descriptor.type }
    var type: ProjectEffectType { descriptor.type }
    var name: String { descriptor.displayName }
    var category: String { descriptor.category.displayName }
    var keywords: [String] { descriptor.keywords }
    var description: String { descriptor.summary }
}

struct VertexEffectBrowserEntry: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let category: String
    let product: String
    let status: EffectCompatibilityStatus
    let type: ProjectEffectType?
    let description: String
    var isImplemented: Bool { type != nil }
}

enum VertexEffectCatalog {
    static let entries: [VertexEffectCatalogEntry] = ProjectEffectDescriptorRegistry.all.map(VertexEffectCatalogEntry.init)

    static let browserEntries: [VertexEffectBrowserEntry] = {
        let indexed = EffectIndexedCatalog.entries.map { entry in
            VertexEffectBrowserEntry(
                id: "indexed.\(entry.id)", name: entry.name, category: entry.category, product: entry.product,
                status: entry.status, type: entry.implementedType,
                description: entry.isImplemented ? (entry.implementedType?.descriptor.summary ?? "Implemented in Vertex2.") : "Indexed reference from the verified effects encyclopedia. Not claimed as a native implementation."
            )
        }
        let indexedTypes = Set(indexed.compactMap(\.type))
        let vertexOnly = entries.filter { !indexedTypes.contains($0.type) }.map { entry in
            VertexEffectBrowserEntry(
                id: "vertex.\(entry.type.rawValue)", name: entry.name, category: entry.category, product: "Vertex2",
                status: entry.type.isNativePixelEffect ? .nativeImplemented : .aiImplemented,
                type: entry.type, description: entry.description
            )
        }
        return vertexOnly + indexed
    }()

    static func search(_ query: String) -> [VertexEffectCatalogEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return entries }
        return entries.compactMap { entry -> (VertexEffectCatalogEntry, Int)? in
            let score = ([entry.name, entry.category] + entry.keywords).map { matchScore(query: normalized, candidate: $0.lowercased()) }.max() ?? 0
            return score > 0 ? (entry, score) : nil
        }.sorted { $0.1 == $1.1 ? $0.0.name < $1.0.name : $0.1 > $1.1 }.map(\.0)
    }

    static func searchAll(_ query: String) -> [VertexEffectBrowserEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return browserEntries.sorted {
                if $0.isImplemented != $1.isImplemented { return $0.isImplemented && !$1.isImplemented }
                if $0.product != $1.product { return $0.product < $1.product }
                return $0.name < $1.name
            }
        }
        return browserEntries.compactMap { entry -> (VertexEffectBrowserEntry, Int)? in
            let fields = [entry.name, entry.category, entry.product] + (entry.type?.descriptor.keywords ?? [])
            let score = fields.map { matchScore(query: normalized, candidate: $0.lowercased()) }.max() ?? 0
            guard score > 0 else { return nil }
            return (entry, score + (entry.isImplemented ? 50 : 0))
        }.sorted { $0.1 == $1.1 ? $0.0.name < $1.0.name : $0.1 > $1.1 }.map(\.0)
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
                if let previousMatch { gapPenalty += candidate.distance(from: candidate.index(after: previousMatch), to: index) }
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
    @State private var expandedGroups: Set<String> = ["Vertex2", "Adobe After Effects"]
    @State private var errorMessage: String?
    @FocusState private var searchFocused: Bool

    private var filtered: [VertexEffectBrowserEntry] { VertexEffectCatalog.searchAll(query) }

    var body: some View {
        VStack(spacing: 0) {
            quickFXHeader
            searchField
            Divider().overlay(AfterEffectsTheme.border)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groups, id: \.self) { group in groupSection(group) }
                }
            }
            if let errorMessage {
                Text(errorMessage).font(.caption2).foregroundStyle(.orange).padding(.horizontal, 8).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading).background(AfterEffectsTheme.elevatedPanel)
            }
        }.background(AfterEffectsTheme.panel)
    }

    private var quickFXHeader: some View {
        HStack(spacing: 8) {
            Button { query = ""; searchFocused = true } label: { Label("Quick FX", systemImage: "bolt.fill") }
                .buttonStyle(.plain).font(.caption.weight(.semibold)).foregroundStyle(AfterEffectsTheme.accent)
            Spacer()
            Text("\(VertexEffectCatalog.entries.count) implemented · \(EffectIndexedCatalog.entries.count) indexed")
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(AfterEffectsTheme.tertiaryText)
        }.padding(.horizontal, 8).frame(height: 26).background(AfterEffectsTheme.elevatedPanel)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.caption2).foregroundStyle(AfterEffectsTheme.tertiaryText)
            TextField("Search 1,568 Effects, Plugins & Tools", text: $query)
                .textFieldStyle(.plain).font(.caption).foregroundStyle(AfterEffectsTheme.primaryText).focused($searchFocused)
                .onSubmit { if let first = filtered.first(where: { $0.isImplemented }) { apply(first) } }
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(AfterEffectsTheme.tertiaryText)
            }
        }.padding(.horizontal, 8).frame(height: 30).background(AfterEffectsTheme.surface)
    }

    private var groups: [String] {
        if !query.isEmpty { return ["Search Results"] }
        var seen = Set<String>()
        return filtered.compactMap { seen.insert($0.product).inserted ? $0.product : nil }
    }

    private func groupSection(_ group: String) -> some View {
        let entries = group == "Search Results" ? filtered : filtered.filter { $0.product == group }
        let expanded = group == "Search Results" || expandedGroups.contains(group)
        return VStack(spacing: 0) {
            Button {
                guard group != "Search Results" else { return }
                if expandedGroups.contains(group) { expandedGroups.remove(group) } else { expandedGroups.insert(group) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.system(size: 8, weight: .bold)).frame(width: 11)
                    Text(group).font(.caption2.weight(.semibold))
                    Text("\(entries.count)").font(.system(size: 9, design: .monospaced)).foregroundStyle(AfterEffectsTheme.tertiaryText)
                    Spacer()
                }.foregroundStyle(AfterEffectsTheme.secondaryText).padding(.horizontal, 7).frame(height: 24).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if expanded { ForEach(entries) { entry in effectRow(entry) } }
        }
    }

    private func effectRow(_ entry: VertexEffectBrowserEntry) -> some View {
        Button { apply(entry) } label: {
            HStack(spacing: 7) {
                Image(systemName: icon(for: entry)).font(.caption2).frame(width: 16)
                    .foregroundStyle(entry.isImplemented ? AfterEffectsTheme.accent : AfterEffectsTheme.secondaryText)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) { Text(entry.name).font(.caption).foregroundStyle(AfterEffectsTheme.primaryText); statusBadge(entry.status) }
                    Text(entry.isImplemented ? entry.description : "\(entry.category) · \(entry.product)")
                        .font(.system(size: 9)).foregroundStyle(AfterEffectsTheme.tertiaryText).lineLimit(1)
                }
                Spacer(minLength: 4)
            }.padding(.horizontal, 10).frame(height: 36).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .help(entry.isImplemented ? "Apply \(entry.name) to the selected layer" : "Indexed reference; not implemented natively in Vertex2 yet")
    }

    private func statusBadge(_ status: EffectCompatibilityStatus) -> some View {
        Text(statusLabel(status)).font(.system(size: 7, weight: .bold, design: .monospaced)).padding(.horizontal, 4).padding(.vertical, 2)
            .background(Color.white.opacity(0.07), in: Capsule())
            .foregroundStyle(status == .nativeImplemented || status == .aiImplemented ? AfterEffectsTheme.accent : AfterEffectsTheme.tertiaryText)
    }

    private var canApplyEffects: Bool {
        guard let layer = workspace.selectedLayer else { return false }
        if case .media = layer.source { return !layer.locked }
        return false
    }

    private func apply(_ entry: VertexEffectBrowserEntry) {
        guard let type = entry.type else {
            errorMessage = "\(entry.name) is indexed for compatibility/reference, but it is not a native Vertex2 implementation yet."
            return
        }
        guard canApplyEffects, let layer = workspace.selectedLayer else {
            errorMessage = "Select an unlocked media layer before applying an effect."
            return
        }
        workspace.perform(.insertLayerEffect(id: layer.id, effect: ProjectEffect.makeDefault(type), index: layer.effects.count), mergeKey: nil)
        query = ""; searchFocused = false; errorMessage = nil
    }

    private func statusLabel(_ status: EffectCompatibilityStatus) -> String {
        switch status {
        case .nativeImplemented: "NATIVE"
        case .aiImplemented: "AI"
        case .cleanRoomPlanned: "INDEXED"
        case .workflowExtension: "EXT"
        case .scriptCommand: "SCRIPT"
        case .legacyReference: "LEGACY"
        case .unsupportedExternal: "EXTERNAL"
        }
    }

    private func icon(for entry: VertexEffectBrowserEntry) -> String {
        guard let type = entry.type else {
            switch entry.status {
            case .workflowExtension: return "square.grid.2x2"
            case .scriptCommand: return "terminal"
            case .legacyReference: return "archivebox"
            default: return "fx"
            }
        }
        switch type {
        case .depthMap: return "square.3.layers.3d"
        case .cutout: return "person.crop.rectangle"
        case .upscale: return "arrow.up.left.and.arrow.down.right"
        case .restore: return "wand.and.stars"
        case .gaussianBlur: return "drop.halffull"
        case .fastBoxBlur: return "rectangle.stack"
        case .directionalBlur: return "wind"
        case .sharpen: return "sparkle.magnifyingglass"
        case .median: return "square.grid.3x3"
        case .noiseReduction: return "waveform.path.ecg.rectangle"
        case .exposure: return "sun.max"
        case .colorControls: return "slider.horizontal.3"
        case .hueAdjust: return "paintpalette"
        case .vibrance: return "paintpalette.fill"
        case .gammaAdjust: return "circle.lefthalf.filled.inverse"
        case .highlightShadow: return "circle.righthalf.filled"
        case .sepiaTone: return "camera.filters"
        case .invert: return "circle.lefthalf.filled"
        case .posterize: return "square.grid.2x2"
        case .mosaic: return "square.grid.4x3.fill"
        case .findEdges: return "scribble.variable"
        case .glow: return "sun.max.fill"
        case .vignette: return "viewfinder.circle"
        case .cartoon: return "wand.and.stars"
        case .twirl: return "tornado"
        }
    }
}
