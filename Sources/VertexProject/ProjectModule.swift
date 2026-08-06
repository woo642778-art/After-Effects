public enum VertexProjectModule {
    public static let name = "VertexProject"
    public static let schemaVersion = ProjectDocument.currentSchemaVersion
    public static let appVersion = ProjectDocument.currentAppVersion
    public static let guarantees = [
        "Deterministic schema 2 composition and layer persistence",
        "Non-destructive schema 1 migration",
        "Durable journal-first composition and layer commands",
        "No platform, GPU, or absolute sandbox objects in project JSON"
    ]
}
