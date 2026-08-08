from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(path):
    return (ROOT / path).read_text()

def write(path, text):
    (ROOT / path).write_text(text)

# Harden the generated coordinator with an injectable live AVFoundation validator.
p = "App/AIEffectBakeCoordinator.swift"
t = read(p)
anchor = '''protocol AIEffectBakeProcessing: Sendable {
    func process(
        sourceURL: URL,
        effect: ProjectEffect,
        outputRoot: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> AIEffectBakeProcessedOutput
}
'''
addition = anchor + r'''

protocol AIEffectBakeOutputValidating: Sendable {
    func validate(sourceURL: URL, outputURL: URL) async throws
}

struct LiveAIEffectBakeOutputValidator: AIEffectBakeOutputValidating {
    func validate(sourceURL: URL, outputURL: URL) async throws {
        guard sourceURL.isFileURL, outputURL.isFileURL else {
            throw AIError.invalidJobState("Bake validation requires file URLs.")
        }
        let source = try await AIVideoSourceInspector.inspect(url: sourceURL)
        let output = try await AIVideoSourceInspector.inspect(url: outputURL)
        guard output.frameCount == source.frameCount else {
            throw AIError.invalidJobState(
                "Baked AI output frame count mismatch: expected \(source.frameCount), got \(output.frameCount)."
            )
        }
        let frameDuration = source.duration.seconds / Double(source.frameCount)
        let tolerance = max(frameDuration, 1.0 / 120.0)
        guard abs(output.duration.seconds - source.duration.seconds) <= tolerance else {
            throw AIError.invalidJobState(
                "Baked AI output duration mismatch: expected \(source.duration.seconds)s, got \(output.duration.seconds)s."
            )
        }
    }
}
'''
if "protocol AIEffectBakeOutputValidating" not in t:
    if anchor not in t:
        raise RuntimeError("Task 9 review validator protocol anchor missing")
    t = t.replace(anchor, addition, 1)

old = '''    private let processor: any AIEffectBakeProcessing
    private let commit: Commit
    private(set) var progress: Double = 0

    init(processor: any AIEffectBakeProcessing = LiveAIEffectBakeProcessor(), commit: @escaping Commit) {
        self.processor = processor
        self.commit = commit
    }
'''
new = '''    private let processor: any AIEffectBakeProcessing
    private let validator: any AIEffectBakeOutputValidating
    private let commit: Commit
    private(set) var progress: Double = 0

    init(
        processor: any AIEffectBakeProcessing = LiveAIEffectBakeProcessor(),
        validator: any AIEffectBakeOutputValidating = LiveAIEffectBakeOutputValidator(),
        commit: @escaping Commit
    ) {
        self.processor = processor
        self.validator = validator
        self.commit = commit
    }
'''
if old in t:
    t = t.replace(old, new, 1)
elif "private let validator: any AIEffectBakeOutputValidating" not in t:
    raise RuntimeError("Task 9 review coordinator initializer anchor missing")

old = '''        try Task.checkCancellation()
        guard FileManager.default.fileExists(atPath: processed.finalVideoURL.path) else {
            throw AIError.inferenceFailed("Baked AI output file is missing.")
        }
        let data = try Data(contentsOf: processed.finalVideoURL, options: [.mappedIfSafe])
'''
new = '''        try Task.checkCancellation()
        guard FileManager.default.fileExists(atPath: processed.finalVideoURL.path) else {
            throw AIError.inferenceFailed("Baked AI output file is missing.")
        }
        try await validator.validate(sourceURL: sourceURL, outputURL: processed.finalVideoURL)
        try Task.checkCancellation()
        let data = try Data(contentsOf: processed.finalVideoURL, options: [.mappedIfSafe])
'''
if old in t:
    t = t.replace(old, new, 1)
elif "validator.validate(sourceURL:" not in t:
    raise RuntimeError("Task 9 review output-validation anchor missing")

old = '''        let embedded = try EmbeddedMediaStore().embed(reference: draftMedia, sourceURL: processed.finalVideoURL, packageURL: packageURL)
        let recipeReference = ProjectAIRecipeReference(
'''
new = '''        let embedded = try EmbeddedMediaStore().embed(reference: draftMedia, sourceURL: processed.finalVideoURL, packageURL: packageURL)
        guard let embeddedPath = embedded.locator.embeddedPath,
              embeddedPath.hasPrefix("Media/"),
              !embeddedPath.hasPrefix("/"),
              !embeddedPath.split(separator: "/").contains("..") else {
            throw ProjectError.invalidPackagePath("Baked AI media did not resolve to a package-relative Media path.")
        }
        let recipeReference = ProjectAIRecipeReference(
'''
if old in t:
    t = t.replace(old, new, 1)
elif "Baked AI media did not resolve" not in t:
    raise RuntimeError("Task 9 review package-path anchor missing")
write(p, t)

# Make tests explicitly exercise validation failure without requiring a real encoded movie fixture.
p = "Tests/VertexAppTests/AIEffectBakeCoordinatorTests.swift"
t = read(p)
insert_anchor = '''private actor FakeBakeProcessor: AIEffectBakeProcessing {
'''
validator_fixture = r'''private struct FakeBakeOutputValidator: AIEffectBakeOutputValidating {
    enum Mode { case accept, reject }
    let mode: Mode
    func validate(sourceURL: URL, outputURL: URL) async throws {
        if mode == .reject {
            throw AIError.invalidJobState("malformed baked movie fixture")
        }
    }
}

'''
if "FakeBakeOutputValidator" not in t:
    if insert_anchor not in t:
        raise RuntimeError("Task 9 review test validator anchor missing")
    t = t.replace(insert_anchor, validator_fixture + insert_anchor, 1)

t = t.replace(
    'AIEffectBakeCoordinator(processor: FakeBakeProcessor(mode: .success, result: fixture.4)) { commits.append($0) }',
    'AIEffectBakeCoordinator(processor: FakeBakeProcessor(mode: .success, result: fixture.4), validator: FakeBakeOutputValidator(mode: .accept)) { commits.append($0) }'
)
t = t.replace(
    'AIEffectBakeCoordinator(processor: FakeBakeProcessor(mode: mode, result: fixture.4)) { _ in commitCount += 1 }',
    'AIEffectBakeCoordinator(processor: FakeBakeProcessor(mode: mode, result: fixture.4), validator: FakeBakeOutputValidator(mode: .accept)) { _ in commitCount += 1 }'
)

if "coordinatorRejectsMalformedFinalMedia" not in t:
    t += r'''

@Test("Malformed finalized media is rejected before the project command")
@MainActor func coordinatorRejectsMalformedFinalMedia() async throws {
    let fixture = try coordinatorFixture()
    var commitCount = 0
    let coordinator = AIEffectBakeCoordinator(
        processor: FakeBakeProcessor(mode: .success, result: fixture.4),
        validator: FakeBakeOutputValidator(mode: .reject)
    ) { _ in
        commitCount += 1
    }
    do {
        try await coordinator.bake(
            project: fixture.0,
            packageURL: fixture.3,
            layerID: fixture.1.id,
            effectID: fixture.2.id
        )
        Issue.record("Expected malformed output validation failure")
    } catch {}
    #expect(commitCount == 0)
}
'''
write(p, t)
print("Task 9 review hardening applied: AVFoundation output validation + malformed-media atomicity test")
