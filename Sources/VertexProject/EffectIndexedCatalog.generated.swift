import Foundation

public struct EffectIndexedCatalogEntry: Equatable, Sendable, Identifiable {
    public let id: String
    public let product: String
    public let category: String
    public let name: String

    public init(id: String, product: String, category: String, name: String) {
        self.id = id
        self.product = product
        self.category = category
        self.name = name
    }

    public var implementedType: ProjectEffectType? {
        guard product == "Adobe After Effects" else { return nil }
        return ProjectEffectDescriptorRegistry.all.first {
            $0.displayName.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }?.type
    }

    public var status: EffectCompatibilityStatus {
        if let type = implementedType {
            return type.isNativePixelEffect ? .nativeImplemented : .aiImplemented
        }
        switch product {
        case "Extensions":
            return .workflowExtension
        case "Scripts":
            return .scriptCommand
        case "BCC obsolete / legacy", "Maxon legacy Keying Suite 11":
            return .legacyReference
        default:
            return .cleanRoomPlanned
        }
    }

    public var isImplemented: Bool {
        status == .nativeImplemented || status == .aiImplemented
    }
}

public enum EffectIndexedCatalog {
    public static let entries: [EffectIndexedCatalogEntry] = {
        let shards: [(offset: Int, raw: String)] = [
            (EffectIndexedCatalogShard0.offset, EffectIndexedCatalogShard0.raw),
            (EffectIndexedCatalogShard1.offset, EffectIndexedCatalogShard1.raw),
            (EffectIndexedCatalogShard2.offset, EffectIndexedCatalogShard2.raw),
            (EffectIndexedCatalogShard3.offset, EffectIndexedCatalogShard3.raw),
            (EffectIndexedCatalogShard4.offset, EffectIndexedCatalogShard4.raw),
            (EffectIndexedCatalogShard5.offset, EffectIndexedCatalogShard5.raw),
            (EffectIndexedCatalogShard6.offset, EffectIndexedCatalogShard6.raw),
            (EffectIndexedCatalogShard7.offset, EffectIndexedCatalogShard7.raw)
        ]
        return shards.flatMap { shard in
            shard.raw.split(separator: "\n", omittingEmptySubsequences: true).enumerated().compactMap { localIndex, row in
                let parts = row.split(separator: "|", omittingEmptySubsequences: false)
                guard parts.count == 3 else { return nil }
                return EffectIndexedCatalogEntry(
                    id: String(format: "%04d", shard.offset + localIndex),
                    product: String(parts[0]),
                    category: String(parts[1]),
                    name: String(parts[2])
                )
            }
        }
    }()

    public static func search(_ query: String) -> [EffectIndexedCatalogEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return entries }
        return entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(normalized)
                || entry.category.localizedCaseInsensitiveContains(normalized)
                || entry.product.localizedCaseInsensitiveContains(normalized)
        }
    }
}
