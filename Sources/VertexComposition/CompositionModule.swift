public enum VertexCompositionModule {
    public static let name = "VertexComposition"
    public static let compilerVersion = CompositionGraphCompiler.compilerVersion
    public static let guarantees = [
        "Exact RationalTime compilation",
        "Authoritative top-to-bottom layer order",
        "One backend-neutral preview and output graph",
        "Deterministic nested composition expansion"
    ]
}
