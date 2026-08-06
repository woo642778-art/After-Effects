# Phase 5 Project Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a recoverable `.aeproject` project system with deterministic schema serialization, command-based undo/redo, write-ahead journaling, atomic saves, autosave recovery, migration, media relinking, and an iOS project workspace, then publish `After-Effects-5.0.0-unsigned.ipa`.

**Architecture:** Add a platform-neutral `VertexProject` module for schema, commands, deterministic encoding, journal records, migration, and relink decisions. Add `VertexProjectFoundation` for package directories, atomic file replacement, snapshots, recovery, bookmarks, embedding, and filesystem validation. The SwiftUI app owns only interaction and document-picker state; it passes portable project values to these modules and continues to render through the existing Phase 4 render graph.

**Tech Stack:** Swift 6, Swift Testing, Foundation, CryptoKit on Apple platforms with portable SHA-256 reuse, SwiftUI, UniformTypeIdentifiers, XcodeGen, GitHub Actions, iOS 17.

## Global Constraints

- Product version is `5.0.0`, build number is `5`, minimum deployment target is iOS `17.0`.
- Project schema version is `1` and is independent from the application version.
- The artifact filename is `After-Effects-5.0.0-unsigned.ipa`.
- `VertexProject` may depend on `VertexCore`, `VertexMedia`, and `VertexRender`, but must not expose AVFoundation, Metal, UIKit, SwiftUI, URL-bookmark APIs, or backend objects.
- Project time values remain exact `RationalTime`; persisted color remains explicit `ColorDescriptor`.
- Project JSON never embeds binary media or absolute sandbox paths.
- Preview and output continue to use the Phase 4 semantic render graph.
- Unknown command types and future schemas are compatibility errors, not silent no-ops.
- Damaged project packages are preserved before recovery writes.
- Every behavior is developed test-first and every task ends with an independently reviewable commit.

---

## File Structure

### Portable module

- `Sources/VertexProject/ProjectError.swift`: stable project error codes and messages.
- `Sources/VertexProject/ProjectSchema.swift`: schema, manifest, metadata, settings, composition placeholders, media references, and validation.
- `Sources/VertexProject/DeterministicProjectCodec.swift`: sorted deterministic JSON, fixed UTC date encoding, decode validation, and checksums.
- `Sources/VertexProject/ProjectCommands.swift`: command operations, records, application, inverse operations, and coalescing.
- `Sources/VertexProject/ProjectHistory.swift`: bounded undo/redo and applied-command identity.
- `Sources/VertexProject/ProjectJournal.swift`: checksummed newline records and replay analysis.
- `Sources/VertexProject/ProjectMigration.swift`: sequential migration registry and future-schema inspection.
- `Sources/VertexProject/MediaRelinking.swift`: strong-identity candidate ranking and portable relink decisions.

### Foundation adapter

- `Sources/VertexProjectFoundation/ProjectPackageLayout.swift`: normalized package paths and traversal rejection.
- `Sources/VertexProjectFoundation/ProjectPackageStore.swift`: package creation, atomic save, manifest replacement, and load.
- `Sources/VertexProjectFoundation/ProjectAutosaveStore.swift`: snapshot rotation and retention.
- `Sources/VertexProjectFoundation/ProjectRecovery.swift`: candidate discovery, ranking, quarantine, and recovery copies.
- `Sources/VertexProjectFoundation/ProjectMediaStore.swift`: fingerprinting, embedding, bookmark creation/resolution, availability, and relinking.

### Application

- `App/ProjectWorkspaceViewModel.swift`: current project session, commands, save/open, autosave, recovery, embed, and relink orchestration.
- `App/ProjectWorkspaceView.swift`: project controls, revision, saved status, Undo/Redo, media availability, recovery status, and system import/export flows.
- `App/ProjectPackageDocument.swift`: SwiftUI `FileDocument` bridge for `.aeproject` directory packages or export staging archives.
- `App/MediaImportView.swift`: expose loaded media to the project workspace without serializing platform objects.
- `App/RenderLabViewModel.swift`: emit and accept portable `ProjectRenderSettings` while continuing to build the existing `RenderRequest`.
- `App/RootView.swift`: present the project workspace in the Phase 5 application shell.

### Tests

- `Tests/VertexProjectTests/ProjectCodecTests.swift`
- `Tests/VertexProjectTests/ProjectCommandTests.swift`
- `Tests/VertexProjectTests/ProjectJournalMigrationTests.swift`
- `Tests/VertexProjectTests/MediaRelinkingTests.swift`
- `Tests/VertexProjectFoundationTests/ProjectPackageStoreTests.swift`
- `Tests/VertexProjectFoundationTests/ProjectRecoveryTests.swift`
- `Tests/VertexCoreTests/MilestoneTests.swift`

---

### Task 1: Portable project schema and deterministic codec

**Files:**
- Modify: `Package.swift`
- Create: `Sources/VertexProject/ProjectError.swift`
- Create: `Sources/VertexProject/ProjectSchema.swift`
- Create: `Sources/VertexProject/DeterministicProjectCodec.swift`
- Create: `Tests/VertexProjectTests/ProjectCodecTests.swift`

**Interfaces:**
- Consumes: `VertexID`, `RationalTime`, `ColorDescriptor`, `MediaAssetDescriptor`, and `RenderOutputSpecification`.
- Produces: `ProjectDocument`, `ProjectManifest`, `ProjectRenderSettings`, `MediaReference`, `DeterministicProjectCodec.encode(_:)`, `DeterministicProjectCodec.decode(_:supportedSchema:)`, and `ProjectError`.

- [ ] **Step 1: Add the target and write failing deterministic-codec tests**

Add `VertexProject` and `VertexProjectTests` to `Package.swift`. Create tests containing these assertions:

```swift
import Foundation
import Testing
@testable import VertexProject
import VertexCore

@Test("Equal project states encode to identical bytes")
func equalProjectsEncodeIdentically() throws {
    let project = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "50000000-0000-0000-0000-000000000001"),
        name: "Deterministic",
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let codec = DeterministicProjectCodec()
    #expect(try codec.encode(project) == codec.encode(project))
    #expect(try codec.checksum(project).count == 64)
}

@Test("Registry insertion order does not affect project bytes")
func registryOrderIsStable() throws {
    let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
    let a = MediaReference.fixture(id: "50000000-0000-0000-0000-000000000010", name: "A.mov")
    let b = MediaReference.fixture(id: "50000000-0000-0000-0000-000000000011", name: "B.mov")
    let first = try ProjectDocument.makeFixture(timestamp: timestamp, media: [a, b])
    let second = try ProjectDocument.makeFixture(timestamp: timestamp, media: [b, a])
    let codec = DeterministicProjectCodec()
    #expect(try codec.encode(first) == codec.encode(second))
}

@Test("Non-finite render values are rejected")
func invalidFloatingPointIsRejected() throws {
    var project = try ProjectDocument.makeNew(name: "Invalid")
    project.renderSettings.exposure = .infinity
    #expect(throws: ProjectError.self) { try project.validated() }
}
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
swift test --filter ProjectCodecTests
```

Expected: compilation fails because `ProjectDocument`, `MediaReference`, and `DeterministicProjectCodec` do not exist.

- [ ] **Step 3: Implement the schema and validation**

Define the core schema with stable arrays rather than unordered dictionaries:

```swift
public struct ProjectDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public var schemaVersion: Int
    public var minimumReaderVersion: Int
    public var projectID: VertexID
    public var revision: UInt64
    public var metadata: ProjectMetadata
    public var settings: ProjectSettings
    public var mediaRegistry: [MediaReference]
    public var compositionRegistry: [ProjectCompositionPlaceholder]
    public var activeCompositionID: VertexID?
    public var selectedMediaID: VertexID?
    public var renderSettings: ProjectRenderSettings
    public var appliedCommandIDs: [VertexID]
    public var undoHistory: [ProjectCommandRecord]
    public var redoHistory: [ProjectCommandRecord]

    public func validated() throws -> Self {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ProjectError.unsupportedSchema(found: schemaVersion, supported: Self.currentSchemaVersion)
        }
        guard revision >= 0 else { throw ProjectError.invalidRevision }
        guard renderSettings.allValuesAreFinite else { throw ProjectError.invalidValue("Render settings must be finite.") }
        guard Set(mediaRegistry.map(\.id)).count == mediaRegistry.count else { throw ProjectError.duplicateIdentity("media") }
        return self
    }
}
```

Use `ProjectRenderSettings` fields `exposure`, `saturation`, `opacity`, `inverted`, `scale`, `translationX`, `translationY`, `outputWidth`, and `outputHeight`. Clamp only at render execution; reject non-finite persistence values and non-positive scale or dimensions.

- [ ] **Step 4: Implement deterministic encoding and checksum**

Use one configured encoder and decoder:

```swift
public struct DeterministicProjectCodec: Sendable {
    public init() {}

    public func encode(_ document: ProjectDocument) throws -> Data {
        let normalized = try document.normalized().validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        encoder.nonConformingFloatEncodingStrategy = .throw
        return try encoder.encode(normalized)
    }

    public func checksum(_ document: ProjectDocument) throws -> String {
        StableProjectSHA256.hexDigest(try encode(document))
    }

    public func decode(_ data: Data, supportedSchema: Int = ProjectDocument.currentSchemaVersion) throws -> ProjectDocument {
        let header = try ProjectSchemaHeader.decode(from: data)
        guard header.schemaVersion <= supportedSchema else {
            throw ProjectError.unsupportedSchema(found: header.schemaVersion, supported: supportedSchema)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        return try decoder.decode(ProjectDocument.self, from: data).validated()
    }
}
```

Normalize registries and ID sets by lowercase ID order and encode dates as UTC `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`.

- [ ] **Step 5: Run tests and commit**

Run:

```bash
swift test --filter ProjectCodecTests
swift test
```

Expected: all codec tests and existing Phase 4 tests pass.

Commit:

```bash
git add Package.swift Sources/VertexProject Tests/VertexProjectTests/ProjectCodecTests.swift
git commit -m "feat: add deterministic project schema"
```

---

### Task 2: Command application, coalescing, Undo, and Redo

**Files:**
- Create: `Sources/VertexProject/ProjectCommands.swift`
- Create: `Sources/VertexProject/ProjectHistory.swift`
- Create: `Tests/VertexProjectTests/ProjectCommandTests.swift`

**Interfaces:**
- Consumes: validated `ProjectDocument` and `ProjectRenderSettings` from Task 1.
- Produces: `ProjectOperation`, `ProjectCommandRecord`, `ProjectCommandEngine.apply(_:to:)`, `ProjectHistoryController.perform(_:)`, `undo()`, `redo()`, and `coalesce(_:with:within:)`.

- [ ] **Step 1: Write failing command tests**

```swift
@Test("A command increments revision exactly once and is idempotent")
func commandRevisionAndIdentity() throws {
    let project = try ProjectDocument.makeNew(name: "Command")
    let record = ProjectCommandRecord.settingExposure(
        project: project,
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000020"),
        from: 0,
        to: 1.25,
        timestamp: Date(timeIntervalSince1970: 1_700_000_001)
    )
    let changed = try ProjectCommandEngine().apply(record, to: project)
    #expect(changed.revision == project.revision + 1)
    #expect(changed.renderSettings.exposure == 1.25)
    #expect(throws: ProjectError.self) { try ProjectCommandEngine().apply(record, to: changed) }
}

@Test("Undo and redo restore render settings")
func undoRedoRoundTrip() throws {
    let controller = try ProjectHistoryController(project: .makeNew(name: "History"))
    try controller.perform(.setRenderParameter(.exposure, before: 0, after: 2), mergeKey: "render.exposure")
    #expect(controller.project.renderSettings.exposure == 2)
    try controller.undo()
    #expect(controller.project.renderSettings.exposure == 0)
    try controller.redo()
    #expect(controller.project.renderSettings.exposure == 2)
}

@Test("Slider commands coalesce into one undo entry")
func sliderCommandsCoalesce() throws {
    let controller = try ProjectHistoryController(project: .makeNew(name: "Coalesce"), coalescingInterval: 0.5)
    try controller.perform(.setRenderParameter(.exposure, before: 0, after: 0.4), mergeKey: "render.exposure", timestamp: .init(timeIntervalSince1970: 10))
    try controller.perform(.setRenderParameter(.exposure, before: 0.4, after: 1.2), mergeKey: "render.exposure", timestamp: .init(timeIntervalSince1970: 10.2))
    #expect(controller.undoCount == 1)
    try controller.undo()
    #expect(controller.project.renderSettings.exposure == 0)
}
```

- [ ] **Step 2: Run RED tests**

Run:

```bash
swift test --filter ProjectCommandTests
```

Expected: missing command and history types.

- [ ] **Step 3: Implement operations and strict application**

Define a Codable enum with explicit associated values:

```swift
public enum ProjectOperation: Codable, Equatable, Sendable {
    case renameProject(before: String, after: String)
    case registerMedia(MediaReference)
    case removeMedia(MediaReference)
    case relinkMedia(mediaID: VertexID, before: MediaLocator, after: MediaLocator)
    case setEmbeddedPath(mediaID: VertexID, before: String?, after: String?)
    case selectMedia(before: VertexID?, after: VertexID?)
    case setRenderParameter(ProjectRenderParameter, before: Double, after: Double)
    case setRenderBoolean(ProjectRenderBooleanParameter, before: Bool, after: Bool)
    case setOutputDimensions(beforeWidth: Int, beforeHeight: Int, afterWidth: Int, afterHeight: Int)
    case setProjectColor(before: ColorDescriptor, after: ColorDescriptor)
}
```

`ProjectCommandEngine.apply` must verify project ID, exact base revision, unseen command ID, and operation preconditions before mutating a copy. It appends the command ID, increments revision once, and caps applied IDs and histories using deterministic oldest-first removal.

- [ ] **Step 4: Implement inverse operations and bounded history**

`ProjectCommandRecord` stores both forward and inverse operations. `ProjectHistoryController` is a reference type used only as a portable state coordinator; it has no filesystem or UI dependency. New commands clear redo. Undo applies the stored inverse as a new state transition while retaining the original command for redo. Cap each history at 200 entries.

Coalesce only adjacent `setRenderParameter` or `setRenderBoolean` records with equal non-nil merge keys and timestamps within the configured interval. Preserve the first `before` value and the last `after` value.

- [ ] **Step 5: Run tests and commit**

```bash
swift test --filter ProjectCommandTests
swift test

git add Sources/VertexProject/ProjectCommands.swift Sources/VertexProject/ProjectHistory.swift Tests/VertexProjectTests/ProjectCommandTests.swift
git commit -m "feat: add project commands and undo history"
```

---

### Task 3: Journal, migration, and strong media relinking

**Files:**
- Create: `Sources/VertexProject/ProjectJournal.swift`
- Create: `Sources/VertexProject/ProjectMigration.swift`
- Create: `Sources/VertexProject/MediaRelinking.swift`
- Create: `Tests/VertexProjectTests/ProjectJournalMigrationTests.swift`
- Create: `Tests/VertexProjectTests/MediaRelinkingTests.swift`

**Interfaces:**
- Consumes: `ProjectCommandRecord`, `ProjectDocument`, `MediaReference`, deterministic codec.
- Produces: `ProjectJournalRecord`, `ProjectJournalCodec`, `ProjectJournalReplayResult`, `ProjectMigrationRegistry`, `ProjectMigrationReport`, `MediaRelinkCandidate`, and `MediaRelinkDecision`.

- [ ] **Step 1: Write failing journal and migration tests**

```swift
@Test("Journal records are independently checksummed and replay idempotently")
func journalReplayIsIdempotent() throws {
    let project = try ProjectDocument.makeNew(name: "Journal")
    let command = ProjectCommandRecord.settingExposure(project: project, from: 0, to: 1)
    let record = try ProjectJournalRecord(sequence: 1, command: command)
    let line = try ProjectJournalCodec().encodeLine(record)
    let decoded = try ProjectJournalCodec().decodeLine(line)
    #expect(decoded.checksum == record.checksum)
    let once = try ProjectJournalReplayer().replay([decoded], onto: project)
    let twice = try ProjectJournalReplayer().replay([decoded], onto: once.project)
    #expect(twice.project == once.project)
}

@Test("A corrupt final journal line is excluded but a sequence gap stops replay")
func journalCorruptionRules() throws {
    let valid = try ProjectJournalRecord.fixture(sequence: 1)
    let bytes = try ProjectJournalCodec().encodeLines([valid]) + Data("{truncated".utf8)
    let analysis = ProjectJournalCodec().analyze(bytes)
    #expect(analysis.validRecords.count == 1)
    #expect(analysis.discardedTrailingBytes > 0)
    #expect(throws: ProjectError.self) {
        try ProjectJournalReplayer().replay([valid, try .fixture(sequence: 3)], onto: .makeNew(name: "Gap"))
    }
}

@Test("Future schemas are inspected but never decoded as writable projects")
func futureSchemaIsNonDestructive() throws {
    let data = Data(#"{"schemaVersion":99,"minimumReaderVersion":99,"projectID":"50000000-0000-0000-0000-000000000001","metadata":{"name":"Future","lastSavedByAppVersion":"99.0.0"}}"#.utf8)
    let info = try ProjectMigrationRegistry.current.inspect(data)
    #expect(info.schemaVersion == 99)
    #expect(throws: ProjectError.self) { try DeterministicProjectCodec().decode(data) }
}
```

- [ ] **Step 2: Write failing relink tests**

```swift
@Test("Filename alone is not a strong relink")
func filenameAloneIsRejected() {
    let reference = MediaReference.fixture(name: "clip.mov", fileSize: 100, fingerprint: "abc")
    let weak = MediaRelinkCandidate(displayName: "clip.mov", fileSize: 999, modificationDate: nil, fingerprint: nil, locatorToken: "weak")
    #expect(MediaRelinker().decide(reference: reference, candidates: [weak]) == .requiresUserSelection([weak]))
}

@Test("Matching fingerprint produces an automatic relink")
func fingerprintMatchIsStrong() {
    let reference = MediaReference.fixture(name: "clip.mov", fileSize: 100, fingerprint: "abc")
    let strong = MediaRelinkCandidate(displayName: "renamed.mov", fileSize: 100, modificationDate: nil, fingerprint: "abc", locatorToken: "strong")
    #expect(MediaRelinker().decide(reference: reference, candidates: [strong]) == .automatic(strong))
}
```

- [ ] **Step 3: Implement deterministic newline journal records**

Encode a journal record without its checksum, hash those bytes, then encode the complete record as one sorted-key JSON line ending in `\n`. Analysis may discard only trailing bytes after the last complete newline. A malformed complete line, sequence gap, checksum failure, stale base revision, or unknown operation throws a structured `ProjectError` and preserves remaining bytes for recovery.

- [ ] **Step 4: Implement migration registry and inspection**

Define:

```swift
public protocol ProjectMigrator: Sendable {
    var sourceVersion: Int { get }
    var destinationVersion: Int { get }
    func migrate(_ data: Data) throws -> ProjectMigrationStepResult
}
```

`ProjectMigrationRegistry.migrate` walks one version at a time and refuses missing links. Since Phase 5 current schema is 1, the production registry has no transformations yet; tests use a deterministic fixture migrator from schema 0 to 1. `inspect(_:)` decodes only a safe header containing schema, minimum reader, project ID, name, and last-saved app version.

- [ ] **Step 5: Implement relink ranking**

Rank embedded location as strongest, then a resolved bookmark confirmed by fingerprint, then relative candidates confirmed by fingerprint. File size plus modification date may narrow candidates but cannot automatically relink without fingerprint equality. Return `.automatic`, `.requiresUserSelection`, or `.missing`.

- [ ] **Step 6: Run tests and commit**

```bash
swift test --filter ProjectJournalMigrationTests
swift test --filter MediaRelinkingTests
swift test

git add Sources/VertexProject/ProjectJournal.swift Sources/VertexProject/ProjectMigration.swift Sources/VertexProject/MediaRelinking.swift Tests/VertexProjectTests
git commit -m "feat: add project journal migration and relinking"
```

---

### Task 4: Atomic package store, autosaves, recovery, bookmarks, and media embedding

**Files:**
- Modify: `Package.swift`
- Create: `Sources/VertexProjectFoundation/ProjectPackageLayout.swift`
- Create: `Sources/VertexProjectFoundation/ProjectPackageStore.swift`
- Create: `Sources/VertexProjectFoundation/ProjectAutosaveStore.swift`
- Create: `Sources/VertexProjectFoundation/ProjectRecovery.swift`
- Create: `Sources/VertexProjectFoundation/ProjectMediaStore.swift`
- Create: `Tests/VertexProjectFoundationTests/ProjectPackageStoreTests.swift`
- Create: `Tests/VertexProjectFoundationTests/ProjectRecoveryTests.swift`

**Interfaces:**
- Consumes: all portable `VertexProject` values.
- Produces: `ProjectPackageLayout`, `ProjectPackageStore.create(at:document:)`, `save(_:to:committedJournalSequence:)`, `load(from:)`, `appendJournal(_:to:)`, `ProjectAutosaveStore.rotate`, `ProjectRecoveryEngine.inspect`, `ProjectMediaStore.embed`, `makeBookmark`, `resolveBookmark`, and `relink`.

- [ ] **Step 1: Add target and write failing atomic-save tests**

```swift
@Test("Interrupted temporary writes preserve the previous project")
func interruptedWritePreservesCurrent() throws {
    let fixture = try TemporaryProjectPackage()
    let store = ProjectPackageStore(fileSystem: .faulting(afterOperation: .writeTemporaryProject))
    let original = try ProjectDocument.makeNew(name: "Original")
    try ProjectPackageStore().create(at: fixture.url, document: original)
    var changed = original
    changed.metadata.name = "Changed"
    #expect(throws: ProjectError.self) { try store.save(changed, to: fixture.url, committedJournalSequence: 0) }
    #expect(try ProjectPackageStore().load(from: fixture.url).document.metadata.name == "Original")
}

@Test("Atomic save produces matching manifest and project checksum")
func manifestMatchesProject() throws {
    let fixture = try TemporaryProjectPackage()
    let document = try ProjectDocument.makeNew(name: "Atomic")
    let result = try ProjectPackageStore().create(at: fixture.url, document: document)
    #expect(result.manifest.projectChecksum == DeterministicProjectCodec().checksum(result.document))
}

@Test("Package-relative paths cannot escape the package")
func pathTraversalIsRejected() throws {
    let layout = try ProjectPackageLayout(root: URL(fileURLWithPath: "/tmp/Test.aeproject"))
    #expect(throws: ProjectError.self) { try layout.embeddedMediaURL(relativePath: "../escape.mov") }
}
```

- [ ] **Step 2: Write failing recovery and autosave tests**

```swift
@Test("A corrupt current project recovers from a valid backup without modifying the source first")
func backupRecoveryCreatesCopy() throws {
    let fixture = try RecoveryPackageFixture.corruptCurrentValidBackup()
    let inspection = try ProjectRecoveryEngine().inspect(packageURL: fixture.url)
    #expect(inspection.candidates.contains { $0.source == .backup && $0.isValid })
    let recoveredURL = try ProjectRecoveryEngine().recover(inspection.bestCandidate!, preserving: fixture.url)
    #expect(recoveredURL != fixture.url)
    #expect(FileManager.default.fileExists(atPath: fixture.url.path))
}

@Test("Autosave rotation keeps current previous and two hourly snapshots")
func autosaveRetentionIsBounded() throws {
    let fixture = try TemporaryProjectPackage()
    let autosaves = ProjectAutosaveStore()
    for revision in 1...8 {
        try autosaves.rotate(document: .fixture(revision: UInt64(revision)), in: fixture.url, timestamp: Date(timeIntervalSince1970: Double(revision * 3600)))
    }
    #expect(try autosaves.snapshotURLs(in: fixture.url).count <= 4)
}
```

- [ ] **Step 3: Implement normalized layout and atomic save protocol**

Create all specified directories. Write project and manifest temporary files in the package root, flush with `FileHandle.synchronize()`, decode and checksum temporary bytes, copy the previous verified `project.json` to `project.json.backup`, then use `FileManager.replaceItemAt` or same-volume rename. If project replacement succeeds but manifest replacement fails, loading detects checksum disagreement and exposes recovery candidates rather than reporting success.

Inject a small `ProjectFileSystem` protocol so tests can fail at named operations without relying on timing or process crashes.

- [ ] **Step 4: Implement journal append and autosave rotation**

Append complete encoded journal lines through `FileHandle`, synchronize before returning, and never truncate uncommitted records. Rotate `snapshot-current` to `snapshot-previous`, store two deterministic hourly slots keyed by UTC hour, and quarantine invalid existing snapshots before replacement.

- [ ] **Step 5: Implement recovery candidate ranking**

Inspect current, backup, current autosave, previous autosave, hourly snapshots, and valid snapshot-plus-journal replay. Rank by validity, document revision, committed sequence, and source priority. Automatically choose only one strict best candidate. Before writing a recovered result, copy the complete damaged package to a sibling name ending `-recovery-source-<UTC timestamp>.aeproject`; write the recovered project to a different sibling package.

- [ ] **Step 6: Implement media fingerprint, bookmark, embedding, and relink**

Fingerprint external media with streamed SHA-256 over file bytes. Store security bookmark bytes only in `MediaLocator.bookmarkData`. Embed by sanitizing the base filename, adding a deterministic media-ID suffix on collisions, copying to `media/`, hashing the copy, and rejecting mismatch. Resolve bookmarks with stale-bookmark reporting and map failures to `ProjectError.bookmarkFailure`. On Linux, compile portable stubs that report bookmark unavailability while package and file tests remain usable.

- [ ] **Step 7: Run package tests and commit**

```bash
swift test --filter VertexProjectFoundationTests
swift test

git add Package.swift Sources/VertexProjectFoundation Tests/VertexProjectFoundationTests
git commit -m "feat: add atomic project package storage"
```

---

### Task 5: SwiftUI project workspace vertical slice

**Files:**
- Create: `App/ProjectPackageDocument.swift`
- Create: `App/ProjectWorkspaceViewModel.swift`
- Create: `App/ProjectWorkspaceView.swift`
- Modify: `App/MediaImportView.swift`
- Modify: `App/RenderLabViewModel.swift`
- Modify: `App/RenderLabView.swift`
- Modify: `App/RootView.swift`
- Modify: `project.yml`

**Interfaces:**
- Consumes: `ProjectHistoryController`, `ProjectPackageStore`, `ProjectMediaStore`, loaded `MediaAssetDescriptor`, selected media URL while security access is valid, and `ProjectRenderSettings`.
- Produces: a real create/save/open/autosave/Undo/Redo/embed/relink/recovery UI that updates the existing Render Lab through portable settings.

- [ ] **Step 1: Add app dependencies and a testable workspace state model**

Add `VertexProject` and `VertexProjectFoundation` package products to the app target and test target. Define these observable values:

```swift
@MainActor
final class ProjectWorkspaceViewModel: ObservableObject {
    @Published private(set) var project: ProjectDocument?
    @Published private(set) var packageURL: URL?
    @Published private(set) var saveState: SaveState = .notCreated
    @Published private(set) var mediaAvailability: [VertexID: MediaAvailabilityStatus] = [:]
    @Published var recoveryPresentation: RecoveryPresentation?

    func createProject(name: String, media: ImportedMediaContext?) throws
    func performRenderSettingsChange(_ settings: ProjectRenderSettings, mergeKey: String?) throws
    func undo() throws
    func redo() throws
    func save(to url: URL) async throws
    func open(from url: URL) async throws
    func embedSelectedMedia() async throws
    func relink(mediaID: VertexID, to url: URL) async throws
    func applicationDidEnterBackground() async
}
```

Use dependency injection for stores and a deterministic clock in tests or Swift previews.

- [ ] **Step 2: Connect portable Render Lab settings**

Add:

```swift
var projectRenderSettings: ProjectRenderSettings { get }
func apply(projectSettings: ProjectRenderSettings)
var onCommittedSettingsChange: ((ProjectRenderSettings, String) -> Void)?
```

Keep Phase 4 rendering unchanged. Slider previews may update continuously; invoke `onCommittedSettingsChange` through the existing 120 ms debounce with merge keys such as `render.exposure` and `render.scale`. Applying loaded project settings must not recursively create commands.

- [ ] **Step 3: Expose imported media safely**

Create a portable `ImportedMediaContext` containing the descriptor, a locator token or bookmark data created while the URL is accessible, file size, modification date, fingerprint, and optional source URL held only by the view model for the current session. Do not put the URL into `ProjectDocument`.

- [ ] **Step 4: Build the workspace UI**

The view must contain:

- New Project with validated name entry;
- current project name, schema `1`, revision, save state, and last saved UTC time;
- Save Project and Open Project document controls;
- Undo and Redo buttons disabled from actual history state;
- selected media availability with `External`, `Embedded`, or `Missing` badge;
- Embed Media and Relink Media actions when applicable;
- an autosave or recovery status banner;
- a recovery choice sheet listing source, revision, timestamp, and whether the original will be preserved.

Do not add timeline, layers, fake compositions, or decorative controls for unimplemented systems.

- [ ] **Step 5: Implement autosave triggers and lifecycle handling**

Debounce normal project changes by two seconds, save immediately at twenty commands, and call autosave on `scenePhase == .background`. Explicit save cancels a pending autosave only after success. Show failures without marking the project saved.

- [ ] **Step 6: Compile the app and commit**

Run locally on macOS when available:

```bash
bash Tools/generate_app_assets.sh
xcodegen generate
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO clean build
```

Expected: successful iOS 17 compilation with no platform object crossing into `VertexProject`.

Commit:

```bash
git add App project.yml
git commit -m "feat: add recoverable project workspace"
```

---

### Task 6: Phase 5 milestone, version, tests, and workflow

**Files:**
- Modify: `Sources/VertexCore/Milestone.swift`
- Modify: `Tests/VertexCoreTests/CoreArchitectureTests.swift`
- Modify: `Tests/VertexCoreTests/MilestoneTests.swift`
- Modify: `project.yml`
- Modify: `.github/workflows/phase-build.yml`
- Modify: `README.md`
- Modify: `Documentation/VERSIONING_AND_ARTIFACTS.md`

**Interfaces:**
- Consumes: completed Phase 5 modules and app.
- Produces: honest Phase 5 status, `5.0.0 (5)` product metadata, and the named unsigned artifact.

- [ ] **Step 1: Write failing Phase 5 milestone assertions**

```swift
@Test("Phase 5 is the active implemented milestone")
func phaseFiveIsActive() {
    let milestone = MilestoneCatalog.current
    #expect(milestone.number == 5)
    #expect(milestone.title == "Project Persistence")
    #expect(milestone.deliverables.contains { $0.contains("atomic") })
    #expect(milestone.deliverables.contains { $0.contains("5.0.0") })
    #expect(milestone.artifactPolicy.contains("After-Effects-5.0.0-unsigned.ipa"))
}
```

Run `swift test --filter VertexCoreTests` and verify it fails against Phase 4.

- [ ] **Step 2: Update milestone and product version**

Set:

```yaml
MARKETING_VERSION: 5.0.0
CURRENT_PROJECT_VERSION: 5
```

Update the milestone deliverables to schema, deterministic serialization, commands, journal, atomic saves, autosaves, recovery, migration, relinking, embedding, and the unsigned 5.0.0 artifact. Preserve honest statements that layers, timeline, playback, and video export are not implemented.

- [ ] **Step 3: Update CI gates**

The workflow must run all portable tests, Foundation package tests on macOS, native Metal tests, asset generation, XcodeGen, iOS Release build, and verify:

```bash
test "$VERSION" = "5.0.0"
test "$BUILD" = "5"
test "$BUNDLE_ID" = "com.woo642778.aftereffects"
test -f "$APP_PATH/Vertex_VertexRenderMetal.bundle/default.metallib"
```

Package and upload:

```bash
After-Effects-5.0.0-unsigned.ipa
After-Effects-5.0.0-unsigned.ipa.sha256
```

- [ ] **Step 4: Run all tests and commit**

```bash
swift test

git add Sources/VertexCore Tests/VertexCoreTests project.yml .github/workflows/phase-build.yml README.md Documentation/VERSIONING_AND_ARTIFACTS.md
git commit -m "chore: publish Phase 5 version metadata"
```

---

### Task 7: Draft PR, remote verification, artifact inspection, and persistent handoff

**Files:**
- Create: `Documentation/PROJECT_PERSISTENCE_ARCHITECTURE.md`
- Create: `Documentation/PROJECT_TEST_MATRIX.md`
- Create: `Documentation/PHASE_5_COMPLETION.md`
- Modify: `Documentation/WORK_LOG.md`
- Modify: `Documentation/HANDOFF.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: final source/config commit and GitHub Actions outputs.
- Produces: Draft PR #5, verified unsigned IPA, checksum, artifact ZIP, completion record, and Phase 6 start gate.

- [ ] **Step 1: Open the stacked Draft PR**

Create a draft PR from `agent/phase-5-project-persistence` to `agent/phase-4-gpu-render-graph` titled:

```text
Phase 5: recoverable project persistence and 5.0.0 IPA
```

Its body must list implemented persistence behavior, platform boundaries, exact exclusions, and the verification gate.

- [ ] **Step 2: Run remote CI and fix failures by root cause**

Wait for portable, Foundation, Metal, and iOS jobs. For each failure, inspect the complete job log before editing. Add a regression test for every behavioral defect. Do not weaken iOS 17, deterministic encoding, checksum, recovery-copy, or preview/output invariants to make CI pass.

- [ ] **Step 3: Download and inspect the artifact**

After the final successful source/config HEAD, download the Actions artifact and verify:

```text
Payload/AfterEffects.app/AfterEffects
Mach-O 64-bit arm64
CFBundleDisplayName = After Effects
CFBundleIdentifier = com.woo642778.aftereffects
CFBundleShortVersionString = 5.0.0
CFBundleVersion = 5
MinimumOSVersion = 17.0
Assets.car exists
default.metallib exists
```

Recompute the extracted IPA SHA-256 and compare it with the uploaded `.sha256` file.

- [ ] **Step 4: Write completion and handoff records**

Record the final product/CI SHA, workflow run ID, test counts, artifact ID, archive digest, IPA digest, executable identity, implemented features, known limitations, and exact Phase 6 gate. Documentation-only commits must not trigger a new product artifact.

- [ ] **Step 5: Final verification and PR comment**

Run or confirm fresh evidence for:

```bash
swift test
xcodebuild ... clean build
shasum -a 256 After-Effects-5.0.0-unsigned.ipa
```

Post the verification summary to the draft PR. Leave the PR draft and unmerged because the repository uses a stacked PR sequence.

- [ ] **Step 6: Commit documentation**

```bash
git add Documentation README.md
git commit -m "docs: record Phase 5 verification and handoff"
```

## Plan Self-Review

- Spec coverage: schema, manifest, deterministic encoding, hybrid media references, commands, coalescing, Undo/Redo, journal, atomic save, autosaves, recovery, migration, future schemas, relinking, embedding, privacy boundaries, app flows, CI, IPA, and handoff each map to a task.
- Placeholder scan: the plan contains no `TBD`, `TODO`, unspecified error handling, or unnamed test work.
- Type consistency: `ProjectDocument`, `ProjectRenderSettings`, `ProjectCommandRecord`, `ProjectHistoryController`, `ProjectJournalRecord`, `ProjectPackageStore`, and `ProjectWorkspaceViewModel` are defined once and reused with matching names.
- Scope: Phase 5 reserves composition identity but does not implement layers, a timeline, playback, or video export.
