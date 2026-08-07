# Phase 5–6 Persistence Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the draft `.aeproject` WAL/history dialect with the approved `.vertexproject` full-snapshot contract, then reintegrate and reverify Phase 6 without weakening Layers, Compositions, Metal rendering, or preview/PNG parity.

**Architecture:** `VertexProject` owns canonical portable project data, desired-state command requests, engine-derived transitions, and one in-memory editing session. `VertexProjectPersistence` owns the filesystem package, pending-save recovery, immutable autosaves, bookmark sidecars, embedded media, and import-only legacy readers. The correction lands on `agent/phase-5-project-persistence` first; that branch is merged into `agent/phase-6-layers-compositions`, which restores canonical Schema 2 and produces the replacement 6.0.0 IPA.

**Tech Stack:** Swift 6, Swift Package Manager, Foundation, Swift Concurrency actors, SwiftUI, UniformTypeIdentifiers, Swift Testing/XCTest, Metal, XcodeGen, GitHub Actions, iOS 17 arm64.

## Global Constraints

- Canonical writable extension: `.vertexproject`.
- Legacy `.aeproject`: import and convert only; never modify the source.
- Final corrected product: `6.0.0 (6)` and `After-Effects-6.0.0-unsigned.ipa`.
- Final corrected Phase 6 project schema: 2.
- `VertexProject` exposes no file URLs, bookmark bytes, security-scoped objects, file descriptors, AVFoundation, Metal, UIKit, SwiftUI, or absolute paths.
- The public filesystem module is `VertexProjectPersistence`; `VertexProjectFoundation` is removed.
- Canonical JSON and autosaves contain no `bookmarkData`, `appliedCommandIDs`, `legacyRenderSettings`, Undo, Redo, command inverse, or operation WAL.
- Undo/Redo are session-only: at most 200 entries per stack. Recent command IDs are session-only: at most 512.
- Workspace selection may persist but never enters edit Undo/Redo and never clears Redo.
- New saves use one full `Journal/pending-save.json` envelope.
- Autosaves are immutable full-document snapshots; retain the eight newest valid unique snapshots.
- Bookmark bytes exist only at `Bookmarks/<lowercase-mediaID>.bookmark`.
- Existing Phase 6 blend, adjustment, nested composition, compiler, Metal, preview, and PNG tests remain active.
- PR #5 and PR #6 remain Draft and unmerged.
- Every earlier 6.0 artifact remains a superseded draft artifact and cannot be the Phase 7 base.

## Locked File Boundaries

### `VertexProject`

- `ProjectSchema.swift`: canonical product data only.
- `ProjectCommandPayload.swift`: desired values requested by callers.
- `ProjectMutation.swift`: exact state transitions with previous and next values.
- `ProjectTransition.swift`: command metadata plus engine-derived forward/inverse mutations.
- `ProjectCommands.swift`: request validation, inverse derivation, and mutation application.
- `ProjectEditingSession.swift`: working document, loaded snapshot, session history, command-ID set, coalescing, navigation, and save markers.

### `VertexProjectPersistence`

- `ProjectPersistenceError.swift`: stable package errors.
- `VertexProjectPackageLayout.swift`: extension, paths, and allowlist.
- `DurableFileIO.swift`: synchronized temporary write, atomic rename, directory sync, and injected failures.
- `VertexProjectManifest.swift`: package manifest with no WAL sequence.
- `PendingSaveEnvelope.swift`: exact project and manifest bytes plus independent checksums.
- `VertexProjectPackageStore.swift`: create, open, save, pending classification, and verified recovery.
- `ImmutableAutosaveStore.swift`: immutable sequence/checksum snapshots.
- `BookmarkSidecarStore.swift`: raw sidecar I/O and Apple bookmark adapter.
- `EmbeddedMediaStore.swift`: verified media copy and resolution.
- `LegacyImport/*`: internal `.aeproject` DTOs, manifest, journal reader, source digest, inspection, and conversion.

### App

- `ProjectDocumentTypes.swift`: canonical and legacy UTTypes.
- `ProjectSessionActor.swift`: serial project operations.
- `ProjectWorkspaceViewModel.swift`: MainActor presentation state.
- `LegacyProjectImportView.swift`: inspection report and explicit conversion.
- `ProjectPackageFileDocument.swift`: canonical export wrapper only.
- `VertexApp.swift`: bounded startup independent of recovery, Metal, and release phase.
- `Tests/VertexAppTests/*`: Xcode app-target tests; these are not SwiftPM test targets.

---

# Segment A — Correct PR #5

### Task 0: Freeze draft baselines and enable correction CI

**Files:**
- Modify: `.github/workflows/phase-build.yml`
- Modify: `Documentation/VERSIONING_AND_ARTIFACTS.md`
- Modify: `Documentation/HANDOFF.md`

**Produces:** immutable safety refs and PR-triggered correction CI.

- [ ] Record and archive the current heads.

```bash
git fetch origin
git rev-parse origin/agent/phase-5-project-persistence
git rev-parse origin/agent/phase-6-layers-compositions
git branch agent/archive/phase-5-pre-correction origin/agent/phase-5-project-persistence
git branch agent/archive/phase-6-pre-correction origin/agent/phase-6-layers-compositions
git push origin agent/archive/phase-5-pre-correction agent/archive/phase-6-pre-correction
```

- [ ] Switch to Phase 5 and run the untouched baseline.

```bash
git switch agent/phase-5-project-persistence
git pull --ff-only origin agent/phase-5-project-persistence
swift test
```

Expected: existing Phase 5 portable tests pass.

- [ ] Temporarily add this workflow trigger.

```yaml
pull_request:
  branches:
    - agent/phase-4-gpu-render-graph
    - agent/phase-5-project-persistence
```

- [ ] Add this exact status beside every historical 6.0 artifact record:

```text
Superseded draft artifact — do not use as the Phase 7 base.
```

- [ ] Commit and push.

```bash
git add .github/workflows/phase-build.yml Documentation/VERSIONING_AND_ARTIFACTS.md Documentation/HANDOFF.md
git commit -m "chore: begin persistence contract correction"
git push origin agent/phase-5-project-persistence
```

---

### Task 1: Make the portable model canonical and history session-only

**Files:**
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `Sources/VertexProject/DeterministicProjectCodec.swift`
- Create: `Sources/VertexProject/ProjectCommandPayload.swift`
- Create: `Sources/VertexProject/ProjectMutation.swift`
- Create: `Sources/VertexProject/ProjectTransition.swift`
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Delete after replacement: `Sources/VertexProject/ProjectHistory.swift`
- Create: `Sources/VertexProject/ProjectEditingSession.swift`
- Create: `Tests/VertexProjectTests/CanonicalProjectModelTests.swift`
- Create: `Tests/VertexProjectTests/ProjectEditingSessionTests.swift`

**Produces:**

```swift
public struct ProjectCommandRequest: Equatable, Sendable {
    public let commandID: VertexID
    public let projectID: VertexID
    public let baseRevision: UInt64
    public let timestamp: Date
    public let mergeKey: String?
    public let payload: ProjectCommandPayload
}

public struct ProjectTransition: Equatable, Sendable {
    public let commandID: VertexID
    public let projectID: VertexID
    public let baseRevision: UInt64
    public let timestamp: Date
    public let mergeKey: String?
    public let forward: ProjectMutation
    public let inverse: ProjectMutation
}

public struct ProjectEditingSession: Sendable {
    public private(set) var loadedSnapshot: ProjectDocument
    public private(set) var document: ProjectDocument
    public private(set) var savedRevision: UInt64
    public private(set) var hasUnsavedChanges: Bool
    public var canUndo: Bool { get }
    public var canRedo: Bool { get }
    public mutating func apply(_ request: ProjectCommandRequest) throws -> ProjectTransition
    public mutating func undo(commandID: VertexID, timestamp: Date) throws -> ProjectTransition
    public mutating func redo(commandID: VertexID, timestamp: Date) throws -> ProjectTransition
    public mutating func setSelectedMedia(_ mediaID: VertexID?, timestamp: Date) throws
    public mutating func markSaved(revision: UInt64) throws
}
```

- [ ] Write the canonical encoding RED test.

```swift
@Test("Canonical project JSON excludes persistence state")
func canonicalProjectExcludesPersistenceState() throws {
    let document = try ProjectDocument.makeNew(name: "Canonical", timestamp: .init(timeIntervalSince1970: 100))
    let json = String(decoding: try DeterministicProjectCodec().encode(document), as: UTF8.self)
    #expect(!json.contains("bookmarkData"))
    #expect(!json.contains("appliedCommandIDs"))
    #expect(!json.contains("legacyRenderSettings"))
    #expect(!json.contains("inverseOperation"))
}
```

Add compile-time construction coverage proving canonical `MediaLocator` has only `relativeHint` and `embeddedPath`.

- [ ] Run it and confirm RED.

```bash
swift test --filter CanonicalProjectModelTests
```

Expected: failure because current canonical types expose forbidden fields.

- [ ] Write session RED tests for empty history on open, 200-entry bounds, 512 command-ID bounds, duplicate ID rejection inside one session, same ID acceptance after reopen, coalescing, Redo preservation across selection changes, and failed `markSaved` state preservation.

- [ ] Run session tests and confirm RED.

```bash
swift test --filter ProjectEditingSessionTests
```

- [ ] Replace canonical media location with:

```swift
public struct MediaLocator: Codable, Equatable, Sendable {
    public var relativeHint: String?
    public var embeddedPath: String?

    public init(relativeHint: String? = nil, embeddedPath: String? = nil) {
        self.relativeHint = relativeHint
        self.embeddedPath = embeddedPath
    }
}
```

Remove canonical `appliedCommandIDs`, persisted history snapshots, deprecated writable compatibility constructors, and any compatibility field whose only purpose is the old persistence dialect. On Phase 5, retain genuine Phase 5 render product data; do not add Phase 6 compositions yet.

- [ ] Implement exact Phase 5 desired-state payloads.

```swift
public enum ProjectCommandPayload: Equatable, Sendable {
    case renameProject(to: String)
    case registerMedia(MediaReference)
    case removeMedia(id: VertexID)
    case relinkMedia(id: VertexID, locator: MediaLocator)
    case setEmbeddedPath(id: VertexID, path: String?)
    case setRenderParameter(ProjectRenderParameter, value: Double)
    case setRenderBoolean(ProjectRenderBooleanParameter, value: Bool)
    case setOutputDimensions(width: Int, height: Int)
    case setProjectColor(ColorDescriptor)
}
```

Selection is not a payload. `setSelectedMedia` validates, updates convenience state, increments revision, marks unsaved, and leaves Undo and Redo unchanged.

- [ ] Implement `ProjectMutation` with exact previous/next values for every payload. `ProjectCommandEngine.prepare(_:for:)` reads the current document and derives both mutations. `apply(_:to:)` validates identity and base revision, applies one mutation, increments revision once, and never stores command IDs in the document.

- [ ] Implement session coalescing. Compatible continuous edits keep the earliest inverse and newest forward mutation. Structural edits never coalesce. Opening a new session always creates empty history and an empty recent-ID set.

- [ ] Run GREEN tests.

```bash
swift test --filter VertexProjectTests
```

- [ ] Commit.

```bash
git add Sources/VertexProject Tests/VertexProjectTests
git commit -m "refactor: make project history session-local"
```

---

### Task 2: Create `VertexProjectPersistence` and enforce the package allowlist

**Files:**
- Modify: `Package.swift`
- Modify: `project.yml`
- Create: `Sources/VertexProjectPersistence/ProjectPersistenceError.swift`
- Create: `Sources/VertexProjectPersistence/VertexProjectPackageLayout.swift`
- Create: `Sources/VertexProjectPersistence/DurableFileIO.swift`
- Create: `Tests/VertexProjectPersistenceTests/PackageLayoutTests.swift`
- Create: `Tests/VertexProjectPersistenceTests/DurableFileIOTests.swift`

**Produces:**

```swift
public enum ProjectPersistenceError: Error, Equatable, Sendable {
    case unsupportedPackageExtension(found: String)
    case forbiddenPackageEntry(String)
    case invalidManifest(String)
    case checksumMismatch(expected: String, actual: String)
    case pendingSnapshotCorrupt(String)
    case pendingSnapshotOlderThanCurrent(pending: UInt64, current: UInt64)
    case atomicReplacementFailed(String)
    case autosaveVerificationFailed(String)
    case bookmarkMissing(VertexID)
    case bookmarkStale(VertexID)
    case embeddedMediaMismatch(VertexID)
    case legacyJournalCorrupt(sequence: UInt64?)
    case legacyImportIncomplete(stage: String)
    case concurrentRequestSuperseded
}

public struct VertexProjectPackageLayout: Equatable, Sendable {
    public static let requiredExtension = "vertexproject"
    public let root: URL
    public init(root: URL) throws
    public func createRequiredDirectories(fileManager: FileManager) throws
    public func validateAllowlist(fileManager: FileManager, mode: PackageValidationMode) throws
}
```

- [ ] Write RED tests asserting exact required directories `Journal`, `Autosaves`, `Bookmarks`, `Media`; exact steady-state root entries; rejection of `.aeproject`, unknown root entries, old history/WAL/backup/autosave/proxy/thumbnail/recovery/quarantine entries; and rejection of unknown `.tmp` names.

- [ ] Run RED.

```bash
swift test --filter PackageLayoutTests
```

- [ ] In `Package.swift`, replace the public product and target with:

```swift
.library(name: "VertexProjectPersistence", targets: ["VertexProjectPersistence"])
```

Add `VertexProjectPersistenceTests`. Remove the old product and target now. Leave the old source directory uncompiled until Task 6 copies its minimum read-only legacy logic, then delete it.

- [ ] Implement the exact steady-state allowlist:

```swift
["project.json", "manifest.json", "Journal", "Autosaves", "Bookmarks", "Media"]
```

Recognize only the transaction temporary names specified in the design.

- [ ] Implement package-private durable I/O:

```swift
package enum DurableFileFailurePoint: Sendable {
    case afterWrite
    case afterFileSync
    case afterRename
    case afterDirectorySync
}

package struct DurableFileIO: Sendable {
    func writeAndSynchronize(_ data: Data, to temporaryURL: URL) throws
    func atomicPromote(_ temporaryURL: URL, to destinationURL: URL) throws
    func synchronizeDirectory(_ url: URL) throws
    func removeIfPresent(_ url: URL) throws
}
```

Use same-volume `rename`, file synchronization, and directory synchronization. Do not create backup files.

- [ ] Run GREEN and product checks.

```bash
swift test --filter VertexProjectPersistenceTests
swift package dump-package | grep -q 'VertexProjectPersistence'
! swift package dump-package | grep -q 'VertexProjectFoundation'
```

- [ ] Commit.

```bash
git add Package.swift project.yml Sources/VertexProjectPersistence Tests/VertexProjectPersistenceTests
git commit -m "feat: add canonical vertex project package"
```

---

### Task 3: Implement full pending-save transactions and recovery

**Files:**
- Create: `Sources/VertexProjectPersistence/VertexProjectManifest.swift`
- Create: `Sources/VertexProjectPersistence/PendingSaveEnvelope.swift`
- Create: `Sources/VertexProjectPersistence/VertexProjectPackageStore.swift`
- Create: `Tests/VertexProjectPersistenceTests/PackageStoreTests.swift`
- Create: `Tests/VertexProjectPersistenceTests/PendingSaveTransactionTests.swift`

**Produces:**

```swift
public struct VertexProjectManifest: Codable, Equatable, Sendable {
    public static let currentPackageFormatVersion = 1
    public let packageFormatVersion: Int
    public let schemaVersion: Int
    public let minimumReaderVersion: Int
    public let projectID: VertexID
    public let projectRevision: UInt64
    public let projectChecksum: String
    public let createdByAppVersion: String
    public let lastSavedByAppVersion: String
    public let lastSuccessfulSave: Date
}

public enum ProjectPackageOpenResult: Sendable {
    case opened(ProjectPackageSnapshot)
    case pendingDecision(PendingSnapshotDecisionContext)
}

public struct VertexProjectPackageStore: Sendable {
    public func create(at url: URL, document: ProjectDocument) throws -> ProjectPackageSnapshot
    public func open(at url: URL) throws -> ProjectPackageOpenResult
    public func save(_ document: ProjectDocument, to url: URL) throws -> ProjectPackageSnapshot
    public func discardPending(in url: URL) throws -> ProjectPackageSnapshot
}
```

- [ ] Write RED envelope tests proving independent project/manifest checksum validation, Base64 round-trip of exact bytes, pair identity/revision/schema agreement, deterministic encoding, and absence of history, commands, bookmarks, and absolute paths.

- [ ] Write RED failure-injection tests at all six required boundaries. On reopen, permit only the last verified pair or complete candidate pair; never expose a mixed pair.

- [ ] Run RED.

```bash
swift test --filter PendingSaveTransactionTests
```

- [ ] Implement sorted-key manifest and envelope codecs with fixed UTC dates. The envelope stores exact canonical project and manifest bytes plus their SHA-256 values.

- [ ] Implement the exact protocol:

```text
capture and validate document
→ encode project and matching manifest
→ write/sync/promote pending marker
→ write/sync project.tmp and manifest.tmp
→ replace both canonical files
→ reopen and verify the pair
→ remove pending and known temp files
→ sync affected directories
```

- [ ] Implement open classification. Apply automatically only a proven newer valid candidate or a candidate completing a partial replacement. Return `.pendingDecision` for corrupt, uncertain, or older pending data.

- [ ] Run GREEN.

```bash
swift test --filter PendingSaveTransactionTests
swift test --filter PackageStoreTests
```

- [ ] Commit.

```bash
git add Sources/VertexProjectPersistence Tests/VertexProjectPersistenceTests
git commit -m "feat: save projects with pending snapshots"
```

---

### Task 4: Implement immutable autosaves

**Files:**
- Create: `Sources/VertexProjectPersistence/ImmutableAutosaveStore.swift`
- Create: `Tests/VertexProjectPersistenceTests/ImmutableAutosaveStoreTests.swift`

**Produces:**

```swift
public struct AutosaveRecord: Equatable, Sendable {
    public let sequence: UInt64
    public let checksum: String
    public let revision: UInt64
    public let createdAt: Date
    public let url: URL
    public let document: ProjectDocument
}

public struct ImmutableAutosaveStore: Sendable {
    public func write(document: ProjectDocument, in packageURL: URL, createdAt: Date) throws -> AutosaveRecord?
    public func validRecords(in packageURL: URL) throws -> [AutosaveRecord]
    public func latestValid(in packageURL: URL) throws -> AutosaveRecord?
}
```

- [ ] Write RED tests for 20-digit monotonic sequence names, checksum names, malformed-name isolation, sequence exhaustion, immutable existing bytes, duplicate revision/checksum suppression, corruption rejection, and retention of eight newest valid unique records. Assert no history, command, inverse, or bookmark field in autosave JSON.

- [ ] Run RED.

```bash
swift test --filter ImmutableAutosaveStoreTests
```

- [ ] Implement write to the exact candidate `.tmp`, synchronize, decode, canonical re-encode, verify, promote, then trim. Existing autosave bytes are never overwritten.

- [ ] Run GREEN and commit.

```bash
swift test --filter ImmutableAutosaveStoreTests
git add Sources/VertexProjectPersistence/ImmutableAutosaveStore.swift Tests/VertexProjectPersistenceTests/ImmutableAutosaveStoreTests.swift
git commit -m "feat: add immutable project autosaves"
```

---

### Task 5: Split bookmark sidecars and embedded media

**Files:**
- Create: `Sources/VertexProjectPersistence/BookmarkSidecarStore.swift`
- Create: `Sources/VertexProjectPersistence/EmbeddedMediaStore.swift`
- Create: `Tests/VertexProjectPersistenceTests/BookmarkSidecarStoreTests.swift`
- Create: `Tests/VertexProjectPersistenceTests/EmbeddedMediaStoreTests.swift`

**Produces:**

```swift
public struct BookmarkSidecarStore: Sendable {
    public func write(_ data: Data, mediaID: VertexID, in packageURL: URL) throws
    public func read(mediaID: VertexID, in packageURL: URL) throws -> Data?
    public func remove(mediaID: VertexID, in packageURL: URL) throws
}

public struct AppleBookmarkAdapter: Sendable {
    public func create(for url: URL) throws -> Data
    public func resolve(_ data: Data) throws -> (url: URL, isStale: Bool)
}

public struct EmbeddedMediaStore: Sendable {
    public func fingerprint(of url: URL) throws -> String
    public func embed(reference: MediaReference, sourceURL: URL, packageURL: URL) throws -> MediaReference
    public func resolve(reference: MediaReference, packageURL: URL) throws -> URL?
}
```

- [ ] Write RED bookmark tests for lowercase ID filename, atomic replacement, missing sidecar isolation, stale refresh, corrupt sidecar isolation, and canonical JSON exclusion.

- [ ] Write RED media tests for deterministic `Media/<mediaID>-<sanitized-name>`, `.tmp` copy, pre/post fingerprint verification, collision mismatch, and embedded-media independence from bookmarks.

- [ ] Run RED.

```bash
swift test --filter BookmarkSidecarStoreTests
swift test --filter EmbeddedMediaStoreTests
```

- [ ] Implement raw sidecar I/O and conditionally compiled Apple bookmark APIs. Unsupported platforms return a structured bookmark error without breaking raw sidecar tests.

- [ ] Implement media promotion only after destination fingerprint verification.

- [ ] Run GREEN and commit.

```bash
swift test --filter BookmarkSidecarStoreTests
swift test --filter EmbeddedMediaStoreTests
! grep -R "bookmarkData" Sources/VertexProject
git add Sources/VertexProjectPersistence Tests/VertexProjectPersistenceTests Sources/VertexProject
git commit -m "feat: store bookmarks outside project json"
```

---

### Task 6: Implement non-destructive legacy `.aeproject` import

**Files:**
- Create: `Sources/VertexProjectPersistence/LegacyImport/LegacyProjectDTO.swift`
- Create: `Sources/VertexProjectPersistence/LegacyImport/LegacyManifestDTO.swift`
- Create: `Sources/VertexProjectPersistence/LegacyImport/LegacyJournalReader.swift`
- Create: `Sources/VertexProjectPersistence/LegacyImport/LegacySourceTreeDigest.swift`
- Create: `Sources/VertexProjectPersistence/LegacyImport/LegacyProjectImporter.swift`
- Read then delete after migration: `Sources/VertexProject/ProjectJournal.swift`
- Read then delete after migration: `Sources/VertexProjectFoundation/*`
- Create: `Tests/VertexProjectPersistenceTests/LegacyJournalReaderTests.swift`
- Create: `Tests/VertexProjectPersistenceTests/LegacyProjectImporterTests.swift`

**Produces:**

```swift
public struct LegacyImportInspection: Sendable {
    public let sourceDigest: String
    public let compositionCount: Int
    public let layerCount: Int
    public let mediaCount: Int
    public let embeddedMediaEligibleCount: Int
    public let bookmarkSuccessCount: Int
    public let bookmarkFailureCount: Int
    public let discardedUndoCount: Int
    public let discardedRedoCount: Int
    public let discardedAutosaveCount: Int
    public let validJournalRecordCount: Int
    public let ignoredJournalRecordCount: Int
}

public struct LegacyImportResult: Sendable {
    public let destinationURL: URL
    public let snapshot: ProjectPackageSnapshot
    public let inspection: LegacyImportInspection
}

public struct LegacyProjectImporter: Sendable {
    public func inspect(sourceURL: URL) throws -> LegacyImportInspection
    public func convert(sourceURL: URL, destinationURL: URL) throws -> LegacyImportResult
}
```

- [ ] Write RED journal tests for committed-sequence start, contiguous records, truncated final line, first gap, checksum failure, unknown command, invalid transition, and prohibition of post-failure records.

- [ ] Write RED importer tests proving source-tree digest equality before/after; unchanged source bytes; preserved IDs and normalized source timestamps; discarded history, backup, and mutable autosaves; bookmark extraction and per-media failure isolation; verified embedded copy; temporary destination cleanup; and deterministic canonical project bytes across repeated imports.

- [ ] Run RED.

```bash
swift test --filter LegacyJournalReaderTests
swift test --filter LegacyProjectImporterTests
```

- [ ] Implement internal/package-only DTOs capable of reading old bookmark payloads, applied IDs, compatibility render values, history, old manifest sequence, and operation records. No legacy DTO is public writable state.

- [ ] Implement source digest from sorted normalized relative paths, file lengths, and exact bytes. Exclude permissions and timestamps.

- [ ] Build `<destination>.tmp`, replay only the valid contiguous WAL prefix, convert old render values once, extract bookmarks, verify embedded media, validate the canonical allowlist, atomically promote, then prove the source digest is unchanged.

- [ ] Run GREEN, delete the uncompiled old module and obsolete portable WAL implementation, and commit.

```bash
swift test --filter LegacyJournalReaderTests
swift test --filter LegacyProjectImporterTests
git rm -r Sources/VertexProjectFoundation Tests/VertexProjectFoundationTests
git rm Sources/VertexProject/ProjectJournal.swift
git add Sources/VertexProjectPersistence Tests/VertexProjectPersistenceTests
git commit -m "feat: import legacy projects non-destructively"
```

---

### Task 7: Route the Phase 5 app through `ProjectSessionActor`

**Files:**
- Create: `App/ProjectDocumentTypes.swift`
- Create: `App/ProjectSessionActor.swift`
- Create: `App/LegacyProjectImportView.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Modify: `App/ProjectWorkspaceView.swift`
- Modify: `App/ProjectPackageFileDocument.swift`
- Modify: `App/RootView.swift`
- Modify: `App/VertexApp.swift`
- Modify: `project.yml`
- Create: `Tests/VertexAppTests/ProjectDocumentTypeTests.swift`
- Create: `Tests/VertexAppTests/ProjectSessionActorTests.swift`
- Modify: `Tests/VertexCoreTests/StartupReadinessTests.swift`

**Produces:**

```swift
actor ProjectSessionActor {
    func create(name: String, packageURL: URL) async throws -> ProjectSessionSnapshot
    func openCanonical(packageURL: URL) async throws -> ProjectOpenOutcome
    func inspectLegacy(packageURL: URL) async throws -> LegacyImportInspection
    func importLegacy(sourceURL: URL, destinationURL: URL) async throws -> ProjectSessionSnapshot
    func apply(_ payload: ProjectCommandPayload, mergeKey: String?) async throws -> ProjectSessionSnapshot
    func setSelectedMedia(_ mediaID: VertexID?) async throws -> ProjectSessionSnapshot
    func undo() async throws -> ProjectSessionSnapshot
    func redo() async throws -> ProjectSessionSnapshot
    func save() async throws -> ProjectSessionSnapshot
    func autosave(reason: AutosaveReason) async throws -> AutosaveRecord?
    func relink(mediaID: VertexID, to url: URL) async throws -> ProjectSessionSnapshot
    func embed(mediaID: VertexID, from url: URL) async throws -> ProjectSessionSnapshot
    func close(disposition: CloseDisposition) async throws -> ProjectSessionSnapshot?
}
```

`ProjectWorkspaceViewModel.OperationState` is exactly `.idle`, `.running(OperationKind)`, `.succeeded(String)`, `.failed(String)`, or `.cancelled`.

- [ ] Add `Tests/VertexAppTests` to the Xcode `VertexTests` target in `project.yml`. Do not add it as a SwiftPM test target.

- [ ] Write RED Xcode tests for UTType `com.maze.vertex.project`, extension `vertexproject`, legacy import-only behavior, empty history after reopen, save-failure state preservation, autosave not clearing unsaved state, coalesced equal requests, superseded older requests, close dispositions, and stale completion rejection.

- [ ] Run RED app tests.

```bash
xcodegen generate
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16 Pro' -only-testing:VertexTests/ProjectDocumentTypeTests -only-testing:VertexTests/ProjectSessionActorTests
```

Expected: failures because the app still directly owns WAL/history/package stores.

- [ ] Implement canonical and legacy UTTypes separately. Canonical files open/edit; legacy files only launch inspection and conversion.

- [ ] Implement the actor. Capture immutable documents for saves and autosaves. Call `markSaved` only after verified store success. Keep security-scoped access around each external operation. Coalesce equal revision/checksum requests and reject stale completions.

- [ ] Replace ViewModel fields `historyController`, `journalSequence`, direct package store, rotating autosave store, and bookmark-in-model resolution with actor calls and returned snapshots.

- [ ] Implement conversion report, destination selection, cancellation, success, and failure. Never register a temporary destination as recent.

- [ ] Keep startup bounded. Project inspection, pending decisions, Metal creation, and bookmark resolution occur after workspace presentation or in bounded tasks with terminal states.

- [ ] Run GREEN app tests and iOS Release compilation.

```bash
xcodegen generate
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16 Pro' -only-testing:VertexTests/ProjectDocumentTypeTests -only-testing:VertexTests/ProjectSessionActorTests
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO clean build
```

- [ ] Commit.

```bash
git add App project.yml Tests/VertexAppTests Tests/VertexCoreTests
git commit -m "refactor: route projects through a session actor"
```

---

### Task 8: Verify and document corrected Phase 5

**Files:**
- Modify: `.github/workflows/phase-build.yml`
- Modify: `Documentation/PROJECT_PERSISTENCE_ARCHITECTURE.md`
- Modify: `Documentation/PROJECT_TEST_MATRIX.md`
- Modify: `Documentation/PHASE_5_WORK_LOG.md`
- Modify: `Documentation/HANDOFF.md`
- Modify: `README.md`

- [ ] Add exact static CI checks.

```bash
! grep -R "VertexProjectFoundation" Package.swift project.yml App Sources Tests
! grep -R "bookmarkData" Sources/VertexProject
! grep -R "appliedCommandIDs" Sources/VertexProject
! grep -R "legacyRenderSettings" Sources/VertexProject
! grep -R "operations.log" Sources/VertexProjectPersistence App
! grep -R "history.json" Sources/VertexProjectPersistence App
```

- [ ] Run the complete Phase 5 correction gate.

```bash
swift test
xcodegen generate
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16 Pro'
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO clean build
```

- [ ] Replace authoritative old persistence documentation. Preserve historical evidence only in sections labeled as superseded.

- [ ] Commit and push.

```bash
git add .github/workflows Documentation README.md
git commit -m "docs: record corrected project persistence"
git push origin agent/phase-5-project-persistence
```

Expected: PR #5 remains Draft, targets Phase 4, and all correction checks pass.

---

# Segment B — Reintegrate Phase 6

### Task 9: Merge corrected Phase 5 and restore canonical Schema 2

**Files:**
- Merge: `agent/phase-5-project-persistence` into `agent/phase-6-layers-compositions`
- Modify: `Package.swift`
- Modify: `project.yml`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `Sources/VertexProject/ProjectCommandPayload.swift`
- Modify: `Sources/VertexProject/ProjectMutation.swift`
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Modify: `Sources/VertexProject/ProjectEditingSession.swift`
- Modify: `Sources/VertexProjectPersistence/LegacyImport/LegacyProjectDTO.swift`
- Modify: `Sources/VertexProjectPersistence/LegacyImport/LegacyProjectImporter.swift`
- Modify: `Tests/VertexProjectTests/ProjectCompositionSchemaTests.swift`
- Modify: `Tests/VertexProjectTests/ProjectLayerCommandTests.swift`
- Create: `Tests/VertexProjectPersistenceTests/LegacySchema2ImportTests.swift`

- [ ] Merge and commit the branch integration before additional edits.

```bash
git switch agent/phase-6-layers-compositions
git pull --ff-only origin agent/phase-6-layers-compositions
git merge --no-ff origin/agent/phase-5-project-persistence
# resolve conflicts by retaining corrected persistence APIs and Phase 6 product behavior
git add -A
git commit -m "merge: integrate corrected Phase 5 persistence"
```

Never resolve a conflict by restoring old WAL, history snapshots, bookmark fields, compatibility render fields, or `VertexProjectFoundation` imports.

- [ ] Write RED final-Schema-2 tests for canonical media/composition/layer registries, valid active composition normalization, invalid selected-layer/media normalization, and continued absence of forbidden fields.

- [ ] Extend desired-state payloads with Phase 6 edit cases:

```swift
case createComposition(ProjectComposition, ownedLayers: [ProjectLayer], index: Int)
case removeComposition(id: VertexID)
case duplicateComposition(sourceID: VertexID, newCompositionID: VertexID, newLayerIDs: [VertexID])
case renameComposition(id: VertexID, to: String)
case setCompositionDimensions(id: VertexID, width: Int, height: Int)
case setCompositionDuration(id: VertexID, duration: RationalTime)
case setCompositionFrameRate(id: VertexID, frameRate: RationalTime)
case setCompositionBackground(id: VertexID, color: ProjectRGBAColor)
case insertLayer(ProjectLayer, compositionID: VertexID, index: Int)
case removeLayer(id: VertexID)
case duplicateLayer(sourceID: VertexID, duplicateID: VertexID, index: Int)
case renameLayer(id: VertexID, to: String)
case reorderLayer(compositionID: VertexID, layerID: VertexID, toIndex: Int)
case setLayerEnabled(id: VertexID, value: Bool)
case setLayerLocked(id: VertexID, value: Bool)
case setLayerSolo(id: VertexID, value: Bool)
case setLayerTiming(id: VertexID, value: LayerTiming)
case setLayerTransform(id: VertexID, value: LayerTransform)
case setLayerBlendMode(id: VertexID, value: LayerBlendMode)
case setLayerSource(id: VertexID, value: LayerSource)
case setLayerOperations(id: VertexID, value: [LayerOperation])
```

Active composition and selected layer are not payloads. Add session navigation methods:

```swift
public mutating func setActiveComposition(_ compositionID: VertexID?, timestamp: Date) throws
public mutating func setSelectedLayer(_ layerID: VertexID?, timestamp: Date) throws
```

They validate and persist convenience state without modifying Undo/Redo or clearing Redo.

- [ ] Derive exact inverse mutations from the current document, including registry index, owned layers, previous order, and previous property values.

- [ ] Add import support for the pre-correction Phase 6 Schema 2 `.aeproject` dialect. Preserve composition, layer, and media IDs; discard old persistence state.

- [ ] Run GREEN.

```bash
swift test --filter ProjectCompositionSchemaTests
swift test --filter ProjectLayerCommandTests
swift test --filter LegacySchema2ImportTests
```

- [ ] Commit.

```bash
git add Package.swift project.yml Sources Tests
git commit -m "refactor: apply corrected persistence to schema 2"
```

---

### Task 10: Reconnect the Composition workspace to the actor

**Files:**
- Modify: `App/ProjectSessionActor.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Modify: `App/ProjectWorkspaceCompositionCommands.swift`
- Modify: `App/ProjectWorkspaceLayerSourceCommands.swift`
- Modify: `App/CompositionWorkspaceView.swift`
- Modify: `App/CompositionMediaFrameResolver.swift`
- Modify: `App/CompositionPreviewController.swift`
- Modify: `App/ProjectPackageFileDocument.swift`
- Modify: `project.yml`
- Create: `Tests/VertexAppTests/ProjectWorkspacePersistenceTests.swift`
- Modify: `Tests/VertexCompositionTests/CompositionGraphCompilerTests.swift`
- Modify: `Tests/VertexRenderMetalTests/MetalCompositionPixelTests.swift`

- [ ] Write RED Xcode tests for composition/layer create, duplicate, delete, reorder, transform coalescing, navigation without Undo, locked-layer rejection, nested-cycle rejection, save/reopen with empty history, missing bookmark isolation, embedded resolution, and legacy conversion report.

- [ ] Run RED.

```bash
xcodegen generate
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16 Pro' -only-testing:VertexTests/ProjectWorkspacePersistenceTests
```

- [ ] Route every edit through actor desired-state payloads. Route active composition, selected layer, and selected media through non-history navigation methods. Remove all app references to `ProjectCommandRecord`, `ProjectJournalRecord`, direct history controllers, and direct package writes.

- [ ] Preserve media resolution order: verified embedded media, then bookmark sidecar, then Missing. One media error cannot block project open or unrelated layers.

- [ ] Preserve one render path: the same `CompositionRenderRequest`, compiler, Metal backend, and canonical pixel bytes feed preview and PNG.

- [ ] Run GREEN app, compiler, and Metal tests.

```bash
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16 Pro' -only-testing:VertexTests/ProjectWorkspacePersistenceTests
swift test --filter VertexCompositionTests
swift test --filter VertexRenderMetalTests
```

- [ ] Commit.

```bash
git add App project.yml Tests
git commit -m "refactor: persist compositions through project sessions"
```

---

### Task 11: Add end-to-end failure and rendering regressions

**Files:**
- Create: `Tests/VertexProjectPersistenceTests/CanonicalPackageIntegrationTests.swift`
- Create: `Tests/VertexProjectPersistenceTests/ConcurrentPersistenceTests.swift`
- Create: `Tests/VertexProjectPersistenceTests/LegacyPhase6ImportIntegrationTests.swift`
- Modify: `Tests/VertexCoreTests/StartupReadinessTests.swift`
- Create: `Tests/VertexRenderMetalTests/PersistenceRenderRegressionTests.swift`

- [ ] Write a package integration test containing two media layers, one adjustment layer, and one nested composition. Save, assert allowlist, reopen, assert canonical project byte equality, assert empty history through the session API, render, and compare pixels.

- [ ] Write concurrency tests proving equal request coalescing, newer-revision supersession, stale-completion rejection, Save and Close waiting for verified save, and Discard preserving verified autosaves.

- [ ] Write startup tests injecting project inspection, pending decision, Metal initialization, and bookmark failures separately. Each test must reach workspace and show only a scoped terminal error.

- [ ] Run the complete new suite.

```bash
swift test --filter CanonicalPackageIntegrationTests
swift test --filter ConcurrentPersistenceTests
swift test --filter LegacyPhase6ImportIntegrationTests
swift test --filter StartupReadinessTests
swift test --filter PersistenceRenderRegressionTests
```

Expected: zero failures.

- [ ] Commit.

```bash
git add Tests
git commit -m "test: cover corrected project persistence end to end"
```

---

### Task 12: Produce and inspect the replacement 6.0 IPA

**Files:**
- Modify: `.github/workflows/phase-build.yml`
- Modify: `Documentation/PROJECT_PERSISTENCE_ARCHITECTURE.md`
- Modify: `Documentation/LAYERS_COMPOSITIONS_ARCHITECTURE.md`
- Modify: `Documentation/PROJECT_TEST_MATRIX.md`
- Modify: `Documentation/COMPOSITION_TEST_MATRIX.md`
- Modify: `Documentation/PHASE_5_COMPLETION.md`
- Modify: `Documentation/PHASE_6_COMPLETION.md`
- Modify: `Documentation/PHASE_6_WORK_LOG.md`
- Modify: `Documentation/VERSIONING_AND_ARTIFACTS.md`
- Modify: `Documentation/HANDOFF.md`
- Modify: `README.md`

- [ ] Add exact static gates.

```bash
set -euo pipefail
! grep -R "VertexProjectFoundation" Package.swift project.yml App Sources Tests
! grep -R "bookmarkData" Sources/VertexProject
! grep -R "appliedCommandIDs" Sources/VertexProject
! grep -R "legacyRenderSettings" Sources/VertexProject
! grep -R "operations.log" Sources/VertexProjectPersistence App
! grep -R "history.json" Sources/VertexProjectPersistence App
! grep -R 'appendingPathExtension("aeproject")' App Sources/VertexProjectPersistence --exclude-dir=LegacyImport
```

- [ ] Run all portable, persistence, composition, Metal, and app tests.

```bash
swift test
xcodegen generate
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16 Pro'
```

- [ ] Build Release and package.

```bash
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO clean build
rm -rf Payload artifacts
mkdir -p Payload artifacts
cp -R DerivedData/Build/Products/Release-iphoneos/AfterEffects.app Payload/AfterEffects.app
zip -qry artifacts/After-Effects-6.0.0-unsigned.ipa Payload
shasum -a 256 artifacts/After-Effects-6.0.0-unsigned.ipa > artifacts/After-Effects-6.0.0-unsigned.ipa.sha256
```

- [ ] Download the uploaded artifact and independently inspect display name, bundle name, bundle ID, `6.0.0 (6)`, iOS 17.0 minimum, arm64 executable, `Assets.car`, `default.metallib`, ZIP digest, IPA digest, size, executable path, and resource sizes.

- [ ] Update all architecture, completion, versioning, work-log, and handoff documents. Record any manual-device tests not performed. State that this replacement artifact is the only allowed Phase 7 base.

- [ ] Remove the temporary PR workflow trigger only after the successful product artifact run. Documentation-only commits must not regenerate the recorded artifact.

- [ ] Commit and push final documentation.

```bash
git add .github/workflows Documentation README.md
git commit -m "docs: complete corrected Phase 6 persistence"
git push origin agent/phase-6-layers-compositions
```

Expected: PR #6 remains Draft and unmerged. The recorded product/CI source HEAD may precede the final documentation HEAD.

---

### Task 13: Enforce the Phase 7 creation gate

**Files:**
- Read: `Documentation/PHASE_6_COMPLETION.md`
- Read: `Documentation/VERSIONING_AND_ARTIFACTS.md`
- Read: `Documentation/HANDOFF.md`
- Create no Phase 7 source file in this task.

- [ ] Verify that product HEAD, successful CI run, artifact ID, downloaded ZIP digest, IPA digest, bundle metadata, package allowlist evidence, startup evidence, and forbidden-field scans are recorded.

- [ ] Verify the corrected Phase 5 branch is an ancestor of Phase 6.

```bash
git fetch origin
git merge-base --is-ancestor origin/agent/phase-5-project-persistence origin/agent/phase-6-layers-compositions
```

Expected: exit code 0. PR #5 and PR #6 remain Draft and unmerged.

- [ ] Only after the gate passes, create the Phase 7 branch.

```bash
git switch agent/phase-6-layers-compositions
git pull --ff-only origin agent/phase-6-layers-compositions
git switch -c agent/phase-7-motion-engine
git push -u origin agent/phase-7-motion-engine
```

Do not write Motion Engine code in this task. Begin a separate brainstorming, design-spec, user-review, and implementation-plan cycle for animation channels, interpolation, parenting, and motion blur.

## Plan Completion Criteria

1. PR #5 exposes `.vertexproject`, `VertexProjectPersistence`, session-only history, full pending snapshots, immutable autosaves, bookmark sidecars, verified embedded media, and non-destructive legacy import.
2. PR #6 restores canonical Schema 2 layers and compositions on that corrected foundation.
3. No public or app source imports `VertexProjectFoundation`.
4. Canonical JSON and autosaves contain no bookmark bytes, applied IDs, compatibility render field, history, inverse, or WAL.
5. Canonical packages create and accept no old history, WAL, backup, proxy, thumbnail, recovery, or quarantine entries.
6. Startup cannot remain indefinitely blocked by phase, project, pending recovery, Metal, media, or bookmark checks.
7. The downloaded replacement 6.0 IPA passes inspection and is explicitly the only Phase 7 base.
