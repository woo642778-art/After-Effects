public enum VertexProjectModule {
    public static let name = "VertexProject"
    public static let schemaVersion = ProjectDocument.currentSchemaVersion
    public static let appVersion = ProjectDocument.currentAppVersion
    public static let guarantees = [
        "Deterministic schema 2 composition and layer persistence",
        "Session-only Undo and Redo",
        "Non-destructive schema 1 migration",
        "No platform, GPU, bookmark bytes, or persistent history in canonical project JSON"
    ]
}
