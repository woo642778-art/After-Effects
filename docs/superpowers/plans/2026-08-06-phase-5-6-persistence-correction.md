# Phase 5–6 Persistence Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the draft `.aeproject` WAL/history persistence dialect with the approved `.vertexproject` full-snapshot contract, then reintegrate and reverify Phase 6 without weakening layer or composition rendering.

**Architecture:** `VertexProject` owns only canonical portable project data and an in-memory editing session. A new `VertexProjectPersistence` target owns package layout, full pending-save transactions, immutable autosaves, bookmark sidecars, embedded media, and import-only legacy readers. Work lands on `agent/phase-5-project-persistence` first; the corrected Phase 5 branch is then merged into `agent/phase-6-layers-compositions`, where Schema 2 and the composition workspace are adapted and a replacement 6.0.0 IPA is produced.

**Tech Stack:** Swift 6, Swift Package Manager, Foundation, Swift Concurrency actors, SwiftUI, UniformTypeIdentifiers, XCTest/Swift Testing, Metal, XcodeGen, GitHub Actions, iOS 17 arm64.

## Global Constraints

- Canonical writable extension is exactly `.vertexproject`.
- `.aeproject` is import-only and the source package is never modified.
- Corrected product version remains `6.0.0 (6)`; this work does not consume Phase 7.
- Canonical Project Schema remains 2 in the final Phase 6 branch.
- `VertexProject` may not expose file URLs, bookmark bytes, security-scoped access, AVFoundation, Metal, UIKit, SwiftUI, file descriptors, or absolute paths.
- Public file-system APIs live in `VertexProjectPersistence`; the `VertexProjectFoundation` product is removed.
- Canonical JSON never contains `bookmarkData`, `appliedCommandIDs`, `legacyRenderSettings`, Undo, Redo, command inverses, or WAL records.
- Undo/Redo and duplicate-command tracking are session-local: 200 history entries and 512 recent command IDs.
- New saves use one complete `Journal/pending-save.json` envelope; new projects never append an operation WAL.
- Autosaves are immutable, checksummed full-document snapshots; keep the eight newest valid unique snapshots.
- Bookmark bytes exist only at `Bookmarks/<lowercase-mediaID>.bookmark`.
- Existing Phase 6 Metal, blend, adjustment, nested-composition, preview, and PNG parity behavior must remain active.
- Existing 6.0 artifacts remain superseded draft artifacts and are not Phase 7 bases.
- PR #5 and PR #6 remain Draft and unmerged throughout this plan.

---

## File Structure Locked by This Plan

### Portable model and editing

- `Sources/VertexProject/ProjectSchema.swift`: canonical writable project and media values only.
- `Sources/VertexProject/ProjectCommandPayload.swift`: user-requested edits without historical `before` values.
- `Sources/VertexProject/ProjectTransition.swift`: engine-derived forward and inverse transitions used only in memory.
- `Sources/VertexProject/ProjectEditingSession.swift`: document, session Undo/Redo, recent command IDs, save markers, and coalescing.
- `Sources/VertexProject/ProjectCommands.swift`: validated payload-to-transition preparation and transition application.
- `Sources/VertexProject/DeterministicProjectCodec.swift`: canonical Schema 1 on corrected Phase 5 and Schema 2 after Phase 6 reintegration.

### Persistence

- `Sources/VertexProjectPersistence/ProjectPersistenceError.swift`: stable package error categories and safe context.
- `Sources/VertexProjectPersistence/VertexProjectPackageLayout.swift`: extension validation, allowlist, and exact paths.
- `Sources/VertexProjectPersistence/DurableFileIO.swift`: synchronized temporary writes, atomic rename, directory sync, and failure injection.
- `Sources/VertexProjectPersistence/VertexProjectManifest.swift`: package-format manifest; no committed WAL sequence.
- `Sources/VertexProjectPersistence/PendingSaveEnvelope.swift`: exact project and manifest bytes plus independent SHA-256 values.
- `Sources/VertexProjectPersistence/VertexProjectPackageStore.swift`: create, open, save, and verified pending recovery.
- `Sources/VertexProjectPersistence/ImmutableAutosaveStore.swift`: monotonic immutable autosaves and retention.
- `Sources/VertexProjectPersistence/BookmarkSidecarStore.swift`: raw sidecar I/O and Apple bookmark adapter.
- `Sources/VertexProjectPersistence/EmbeddedMediaStore.swift`: verified package media copy and resolution.
- `Sources/VertexProjectPersistence/LegacyImport/LegacyProjectDTO.swift`: legacy schema values including embedded bookmark bytes and old render settings.
- `Sources/VertexProjectPersistence/LegacyImport/LegacyManifestDTO.swift`: old manifest and committed WAL sequence.
- `Sources/VertexProjectPersistence/LegacyImport/LegacyJournalReader.swift`: complete, checksummed, contiguous record parsing.
- `Sources/VertexProjectPersistence/LegacyImport/LegacySourceTreeDigest.swift`: sorted relative-path and file-byte digest.
- `Sources/VertexProjectPersistence/LegacyImport/LegacyProjectImporter.swift`: inspection, report, conversion, validation, and source-integrity proof.

### App

- `App/ProjectDocumentTypes.swift`: canonical and legacy UTTypes and picker modes.
- `App/ProjectSessionActor.swift`: serializes open, edit, Undo/Redo, save, autosave, import, and close.
- `App/ProjectWorkspaceViewModel.swift`: MainActor presentation adapter with explicit terminal states.
- `App/LegacyProjectImportView.swift`: report, destination selection, progress, cancellation, and result.
- `App/ProjectPackageFileDocument.swift`: canonical `.vertexproject` export wrapper only.
- `App/VertexApp.swift`: bounded startup transition independent of project and Metal work.

---

# Execution Segment A — Correct PR #5 First

### Task 0: Freeze the two draft baselines and enable correction CI

**Files:**
- Modify: `.github/workflows/phase-build.yml`
- Modify: `Documentation/VERSIONING_AND_ARTIFACTS.md`
- Modify: `Documentation/HANDOFF.md`

**Interfaces:**
- Consumes: current Draft PR #5 and Draft PR #6 branch heads.
- Produces: safety refs, explicit superseded-artifact documentation, and temporary PR-triggered CI for correction work.

- [ ] **Step 1: Record and protect the current branch heads**

```bash
git fetch origin
git rev-parse origin/agent/phase-5-project-persistence
git rev-parse origin/agent/phase-6-layers-compositions
git branch agent/archive/phase-5-pre-correction origin/agent/phase-5-project-persistence
git branch agent/archive/phase-6-pre-correction origin/agent/phase-6-layers-compositions
git push origin agent/archive/phase-5-pre-correction agent/archive/phase-6-pre-correction
```

Expected: both archive refs point to the exact pre-correction heads and neither PR is merged.

- [ ] **Step 2: Check out the Phase 5 draft branch and verify the baseline**

```bash
git switch agent/phase-5-project-persistence
git pull --ff-only origin agent/phase-5-project-persistence
swift test
```

Expected: the existing Phase 5 portable suite passes before correction work.

- [ ] **Step 3: Add a temporary `pull_request` workflow trigger for PR #5 and PR #6**

Add this alongside the existing `push` trigger:

```yaml
pull_request:
  branches:
    - agent/phase-4-gpu-render-graph
    - agent/phase-5-project-persistence
```

Do not change version or artifact names in this task.

- [ ] **Step 4: Mark every existing 6.0 artifact as superseded**

Add the exact status line to versioning and handoff documents:

```text
Superseded draft artifact — do not use as the Phase 7 base.
```

Include the previously recorded run IDs and checksums without deleting historical evidence.

- [ ] **Step 5: Run baseline CI and commit**

```bash
swift test
git add .github/workflows/phase-build.yml Documentation/VERSIONING_AND_ARTIFACTS.md Documentation/HANDOFF.md
git commit -m "chore: begin persistence contract correction"
git push origin agent/phase-5-project-persistence
```

Expected: portable tests pass and PR #5 receives a correction workflow run.

---

### Task 1: Remove persistence state from the portable project model

**Files:**
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `Sources/VertexProject/DeterministicProjectCodec.swift`
- Create: `Sources/VertexProject/ProjectCommandPayload.swift`
- Create: `Sources/VertexProject/ProjectTransition.swift`
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Replace: `Sources/VertexProject/ProjectHistory.swift` with `Sources/VertexProject/ProjectEditingSession.swift`
- Test: `Tests/VertexProjectTests/CanonicalProjectModelTests.swift`
- Test: `Tests/VertexProjectTests/ProjectEditingSessionTests.swift`

**Interfaces:**
- Consumes: `ProjectDocument`, existing `ProjectOperation` cases, `VertexID`, `RationalTime`.
- Produces:

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
    public private(set) var document: ProjectDocument
    public private(set) var savedRevision: UInt64
    public private(set) var hasUnsavedChanges: Bool
    public var canUndo: Bool { get }
    public var canRedo: Bool { get }
    public mutating func apply(_ request: ProjectCommandRequest) throws -> ProjectTransition
    public mutating func undo(commandID: VertexID, timestamp: Date) throws -> ProjectTransition
    public mutating func redo(commandID: VertexID, timestamp: Date) throws -> ProjectTransition
    public mutating func markSaved(revision: UInt64) throws
}
```

- [ ] **Step 1: Write canonical-encoding RED tests**

```swift
@Test("Canonical project JSON excludes persistence state")
func canonicalProjectExcludesPersistenceState() throws {
    let document = try ProjectDocument.makeNew(name: "Canonical", timestamp: .init(timeIntervalSince1970: 100))
    let text = String(decoding: try DeterministicProjectCodec().encode(document), as: UTF8.self)
    #expect(!text.contains("bookmarkData"))
    #expect(!text.contains("appliedCommandIDs"))
    #expect(!text.contains("legacyRenderSettings"))
    #expect(!text.contains("inverseOperation"))
}
```

Add compile-time construction tests proving `MediaLocator` accepts only `relativeHint` and `embeddedPath`, and `ProjectDocument` initializers have no applied-command or legacy-render arguments.

- [ ] **Step 2: Run RED tests**

```bash
swift test --filter CanonicalProjectModelTests
```

Expected: FAIL because canonical types still expose forbidden fields.

- [ ] **Step 3: Write session RED tests**

Cover these exact behaviors:

```swift
@Test("Opening a session starts with empty Undo and Redo")
@Test("Duplicate command IDs are rejected only within the active session")
@Test("Undo and Redo are bounded to 200 entries")
@Test("Recent command IDs are bounded to 512 entries")
@Test("Saving does not serialize history")
@Test("A failed markSaved revision leaves session state unchanged")
```

The duplicate-ID test creates a new session from the resulting document and proves the same command ID is allowed after reopen when its base revision is current.

- [ ] **Step 4: Run session RED tests**

```bash
swift test --filter ProjectEditingSessionTests
```

Expected: FAIL because the current controller accepts a persisted snapshot and the document stores command IDs.

- [ ] **Step 5: Implement canonical model removal**

Change `MediaLocator` to:

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

Remove `ProjectDocument.appliedCommandIDs`, `ProjectDocument.legacyRenderSettings`, deprecated writable constructors, and the `renderSettings` compatibility setter. Keep legacy decoding out of this file.

On the corrected Phase 5 branch, keep its current canonical schema number and render values required by Phase 5; do not add Phase 6 composition fields here. The Phase 6 merge task upgrades the canonical model to Schema 2.

- [ ] **Step 6: Implement request, mutation, transition, and session types**

`ProjectCommandPayload` carries desired state, not historical `before` values. Include the Phase 5 cases explicitly:

```swift
public enum ProjectCommandPayload: Equatable, Sendable {
    case renameProject(to: String)
    case registerMedia(MediaReference)
    case removeMedia(id: VertexID)
    case relinkMedia(id: VertexID, locator: MediaLocator)
    case setEmbeddedPath(id: VertexID, path: String?)
    case selectMedia(VertexID?)
    case setRenderParameter(ProjectRenderParameter, value: Double)
    case setRenderBoolean(ProjectRenderBooleanParameter, value: Bool)
    case setOutputDimensions(width: Int, height: Int)
    case setProjectColor(ColorDescriptor)
}
```

`ProjectCommandEngine.prepare(_:for:)` reads the current document, validates preconditions, and returns a transition containing exact forward and inverse `ProjectMutation` values. `apply(_:to:)` validates project identity and base revision, applies only the forward mutation, increments revision once, and never writes command IDs into the document.

- [ ] **Step 7: Implement session-only coalescing**

Coalesce only when merge key, payload family, target identity, and elapsed time are compatible. Preserve the first inverse and newest forward value. Do not coalesce register, remove, or selection commands. Store no `Codable` history snapshot type.

- [ ] **Step 8: Run model and session GREEN tests**

```bash
swift test --filter VertexProjectTests
```

Expected: all VertexProject tests pass with no persisted history or command IDs.

- [ ] **Step 9: Commit**

```bash
git add Sources/VertexProject Tests/VertexProjectTests
git commit -m "refactor: make project history session-local"
```

---

### Task 2: Introduce `VertexProjectPersistence` and the package allowlist

**Files:**
- Modify: `Package.swift`
- Modify: `project.yml`
- Create: `Sources/VertexProjectPersistence/ProjectPersistenceError.swift`
- Create: `Sources/VertexProjectPersistence/VertexProjectPackageLayout.swift`
- Create: `Sources/VertexProjectPersistence/DurableFileIO.swift`
- Create: `Tests/VertexProjectPersistenceTests/PackageLayoutTests.swift`
- Create: `Tests/VertexProjectPersistenceTests/DurableFileIOTests.swift`

**Interfaces:**
- Consumes: canonical `ProjectDocument`, Foundation `URL`, `FileManager`.
- Produces:

```swift
public struct VertexProjectPackageLayout: Equatable, Sendable {
    public static let requiredExtension = "vertexproject"
    public let root: URL
    public init(root: URL) throws
    public var projectURL: URL { get }
    public var manifestURL: URL { get }
    public var journalDirectoryURL: URL { get }
    public var pendingSaveURL: URL { get }
    public var autosavesDirectoryURL: URL { get }
    public var bookmarksDirectoryURL: URL { get }
    public var mediaDirectoryURL: URL { get }
    public func createRequiredDirectories(fileManager: FileManager) throws
    public func validateAllowlist(fileManager: FileManager, mode: PackageValidationMode) throws
}
```

- [ ] **Step 1: Write RED package-layout tests**

Assert exact root entries after directory creation:

```swift
#expect(Set(entries) == ["Journal", "Autosaves", "Bookmarks", "Media"])
```

Add tests that `.aeproject`, ordinary directories, `history.json`, `journal/operations.log`, `project.json.backup`, mutable autosaves, proxy, thumbnail, recovery, quarantine, and unknown `.tmp` entries are rejected.

- [ ] **Step 2: Run RED layout tests**

```bash
swift test --filter PackageLayoutTests
```

Expected: FAIL because only `VertexProjectFoundation` and the old layout exist.

- [ ] **Step 3: Replace package products and targets**

In `Package.swift`:

```swift
.library(name: "VertexProjectPersistence", targets: ["VertexProjectPersistence"])
```

Create target dependency `["VertexCore", "VertexMedia", "VertexProject"]` and `VertexProjectPersistenceTests`. Remove the public `VertexProjectFoundation` product and target only after all required legacy readers have equivalents scheduled in Task 6. During Tasks 2–5, no new app code may import the old module.

Update `project.yml` package dependencies and test target names to the new product.

- [ ] **Step 4: Implement stable persistence errors**

Define `ProjectPersistenceError: Error, Equatable, Sendable, LocalizedError` with the exact categories from the spec. Store only package-relative entry names, IDs, revisions, sequences, stages, and checksums in associated values.

- [ ] **Step 5: Implement the exact allowlist and known temporary names**

Steady-state root allowlist:

```swift
["project.json", "manifest.json", "Journal", "Autosaves", "Bookmarks", "Media"]
```

Transaction mode additionally recognizes only:

```swift
project.json.tmp
manifest.json.tmp
Journal/pending-save.json
Journal/pending-save.json.tmp
Autosaves/<sequence>-<checksum>.json.tmp
Bookmarks/<mediaID>.bookmark.tmp
Media/<mediaID>-<filename>.tmp
```

Do not create backup, proxy, thumbnail, recovery, or quarantine directories.

- [ ] **Step 6: Implement durable file primitives with failure injection**

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

Use `fsync`/`F_FULLFSYNC` where available and `rename` for same-volume promotion. Map failures to `ProjectPersistenceError.atomicReplacementFailed`.

- [ ] **Step 7: Run GREEN tests and static product check**

```bash
swift test --filter VertexProjectPersistenceTests
swift package dump-package | grep -q 'VertexProjectPersistence'
! swift package dump-package | grep -q 'VertexProjectFoundation'
```

Expected: layout and durable-I/O tests pass; the old public product is absent.

- [ ] **Step 8: Commit**

```bash
git add Package.swift project.yml Sources/VertexProjectPersistence Tests/VertexProjectPersistenceTests
git commit -m "feat: add canonical vertex project package"
```

---

### Task 3: Implement full pending-snapshot save and recovery

**Files:**
- Create: `Sources/VertexProjectPersistence/VertexProjectManifest.swift`
- Create: `Sources/VertexProjectPersistence/PendingSaveEnvelope.swift`
- Create: `Sources/VertexProjectPersistence/VertexProjectPackageStore.swift`
- Create: `Tests/VertexProjectPersistenceTests/PendingSaveTransactionTests.swift`
- Create: `Tests/VertexProjectPersistenceTests/PackageStoreTests.swift`

**Interfaces:**
- Consumes: `DeterministicProjectCodec`, `StableProjectSHA256`, `DurableFileIO`, `VertexProjectPackageLayout`.
- Produces:

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

- [ ] **Step 1: Write RED deterministic envelope tests**

Create fixed project and manifest bytes and assert decode verifies:

- both Base64 payloads;
- independent project and manifest SHA-256 values;
- project ID, schema, revision, and project checksum agreement;
- no history, command ID, inverse, bookmark, or absolute path fields.

- [ ] **Step 2: Write RED failure-injection matrix**

Use a table of the six required failure points. After each injected failure, reopen and assert exactly one of:

```swift
.lastVerifiedPair
.completeCandidatePair
```

Assert a mixed project/manifest revision is never returned.

- [ ] **Step 3: Run RED transaction tests**

```bash
swift test --filter PendingSaveTransactionTests
```

Expected: FAIL because no full pending envelope or recovery classifier exists.

- [ ] **Step 4: Implement deterministic manifest and pending envelope codecs**

Use sorted keys, fixed UTC fractional-second encoding, and no non-finite floats. The pending envelope stores exact project and manifest bytes as Base64 and checksums those exact bytes.

- [ ] **Step 5: Implement save order exactly**

```text
validate candidate
→ encode project and manifest
→ write/sync/promote pending marker
→ write/sync project.tmp and manifest.tmp
→ atomically replace both canonical files
→ reopen and verify pair
→ delete pending and known temp files
→ sync affected directories
```

Do not update a session or delete the pending marker before pair verification succeeds.

- [ ] **Step 6: Implement open classification**

Return `.opened` only for a fully matched pair. Return `.pendingDecision` for corrupt, uncertain, or older pending data. Automatically complete only a valid candidate with a strictly greater revision or a candidate matching a partially replaced pair.

- [ ] **Step 7: Run GREEN transaction and package tests**

```bash
swift test --filter PendingSaveTransactionTests
swift test --filter PackageStoreTests
```

Expected: all six failure points recover deterministically and allowlist inspection passes after success.

- [ ] **Step 8: Commit**

```bash
git add Sources/VertexProjectPersistence Tests/VertexProjectPersistenceTests
git commit -m "feat: save projects with pending snapshots"
```

---

### Task 4: Implement immutable autosaves

**Files:**
- Create: `Sources/VertexProjectPersistence/ImmutableAutosaveStore.swift`
- Create: `Tests/VertexProjectPersistenceTests/ImmutableAutosaveStoreTests.swift`

**Interfaces:**
- Consumes: package layout, deterministic project codec, durable I/O.
- Produces:

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

- [ ] **Step 1: Write RED autosave tests**

Cover exact filename, monotonic sequence from valid names, malformed-name isolation, duplicate revision/checksum suppression, immutable existing bytes, sequence exhaustion, corruption rejection, and eight-record retention.

Assert autosave JSON does not contain `undo`, `redo`, `bookmark`, `commandID`, or `inverse`.

- [ ] **Step 2: Run RED tests**

```bash
swift test --filter ImmutableAutosaveStoreTests
```

Expected: FAIL because the current store rotates mutable current/previous files and persists history.

- [ ] **Step 3: Implement immutable write and verification**

Write `Autosaves/<20-digit-sequence>-<lowercase-checksum>.json.tmp`, synchronize, decode, re-encode, verify, promote, then delete only excess older valid snapshots. Existing records are never overwritten.

- [ ] **Step 4: Run GREEN tests**

```bash
swift test --filter ImmutableAutosaveStoreTests
```

Expected: all autosave contract tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/VertexProjectPersistence/ImmutableAutosaveStore.swift Tests/VertexProjectPersistenceTests/ImmutableAutosaveStoreTests.swift
git commit -m "feat: add immutable project autosaves"
```

---

### Task 5: Split bookmark sidecars from embedded media

**Files:**
- Create: `Sources/VertexProjectPersistence/BookmarkSidecarStore.swift`
- Create: `Sources/VertexProjectPersistence/EmbeddedMediaStore.swift`
- Create: `Tests/VertexProjectPersistenceTests/BookmarkSidecarStoreTests.swift`
- Create: `Tests/VertexProjectPersistenceTests/EmbeddedMediaStoreTests.swift`

**Interfaces:**
- Consumes: media IDs, media fingerprints, layout, durable I/O.
- Produces:

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

- [ ] **Step 1: Write RED sidecar tests**

Assert lowercase canonical ID filename, atomic replacement, missing sidecar returns `nil`, corrupt data does not affect project decoding, stale refresh replaces the same sidecar, and no bookmark bytes appear in canonical project JSON.

- [ ] **Step 2: Write RED embedded-media tests**

Assert `.tmp` copy, source and destination fingerprint validation, deterministic `Media/<mediaID>-<sanitized-name>` path, no external bookmark requirement, collision mismatch rejection, and unrelated project data remains readable after one media mismatch.

- [ ] **Step 3: Run RED tests**

```bash
swift test --filter BookmarkSidecarStoreTests
swift test --filter EmbeddedMediaStoreTests
```

Expected: FAIL because the old combined media store writes bookmark bytes through `MediaLocator`.

- [ ] **Step 4: Implement raw sidecar and conditional Apple adapter**

Keep raw sidecar I/O portable across Foundation platforms. Wrap `URL.bookmarkData` and resolution in `#if os(iOS) || os(macOS)`; unsupported platforms return a stable bookmark error without preventing non-bookmark tests.

- [ ] **Step 5: Implement verified embedded media**

Never promote a media file until the destination fingerprint matches the expected fingerprint. Return an updated portable reference containing only `embeddedPath`, fingerprint, and availability.

- [ ] **Step 6: Run GREEN tests and canonical scan**

```bash
swift test --filter BookmarkSidecarStoreTests
swift test --filter EmbeddedMediaStoreTests
! grep -R "bookmarkData" Sources/VertexProject
```

Expected: all tests pass and portable sources contain no bookmark payload property.

- [ ] **Step 7: Commit**

```bash
git add Sources/VertexProjectPersistence Tests/VertexProjectPersistenceTests Sources/VertexProject
git commit -m "feat: store bookmarks outside project json"
```

---

### Task 6: Add non-destructive legacy `.aeproject` import

**Files:**
- Create: `Sources/VertexProjectPersistence/LegacyImport/LegacyProjectDTO.swift`
- Create: `Sources/VertexProjectPersistence/LegacyImport/LegacyManifestDTO.swift`
- Create: `Sources/VertexProjectPersistence/LegacyImport/LegacyJournalReader.swift`
- Create: `Sources/VertexProjectPersistence/LegacyImport/LegacySourceTreeDigest.swift`
- Create: `Sources/VertexProjectPersistence/LegacyImport/LegacyProjectImporter.swift`
- Move required read-only logic from: `Sources/VertexProject/ProjectJournal.swift`
- Move required read-only logic from: `Sources/VertexProjectFoundation/ProjectPackageStore.swift`
- Test: `Tests/VertexProjectPersistenceTests/LegacyJournalReaderTests.swift`
- Test: `Tests/VertexProjectPersistenceTests/LegacyProjectImporterTests.swift`

**Interfaces:**
- Consumes: old package bytes, old manifest committed sequence, old journal lines, bookmark payloads, embedded media.
- Produces:

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

- [ ] **Step 1: Write RED journal-reader tests**

Cover contiguous replay, committed-sequence start, truncated final line, first sequence gap stop, checksum failure stop, unknown command stop, and invalid transition stop. Assert no record after the first invalid boundary is applied.

- [ ] **Step 2: Write RED source-integrity and conversion tests**

Create fixture packages and assert:

- source-tree digest before and after is equal;
- source bytes are unchanged;
- IDs and normalized source timestamps are preserved;
- persistent history, backup, and mutable autosave data are not copied;
- valid bookmark bytes become sidecars;
- invalid bookmark bytes mark only that media missing;
- embedded media is copied only after fingerprint verification;
- failed import removes `<destination>.tmp` and does not create destination;
- importing the same source twice produces byte-identical canonical project JSON.

- [ ] **Step 3: Run RED importer tests**

```bash
swift test --filter LegacyJournalReaderTests
swift test --filter LegacyProjectImporterTests
```

Expected: FAIL because existing migration writes another `.aeproject` and preserves old persistence structures.

- [ ] **Step 4: Implement internal legacy DTOs**

DTOs may decode `bookmarkData`, `appliedCommandIDs`, `legacyRenderSettings`, history files, old manifest journal sequence, and old operation records. Mark all DTOs and codecs `package` or `internal`; expose only inspection and conversion results.

- [ ] **Step 5: Implement deterministic source-tree digest**

Hash sorted normalized relative paths followed by exact file lengths and bytes. Exclude filesystem timestamps, permissions, and destination state.

- [ ] **Step 6: Implement import pipeline**

Build `<destination>.tmp` using the canonical store. Apply only valid contiguous journal records. Use source project timestamps for canonical metadata. Extract bookmarks, verify embedded media, validate destination allowlist, then atomically rename the completed temporary package. Recompute the source digest before success.

- [ ] **Step 7: Run GREEN importer tests**

```bash
swift test --filter LegacyJournalReaderTests
swift test --filter LegacyProjectImporterTests
```

Expected: all legacy conversion and non-destructive integrity tests pass.

- [ ] **Step 8: Remove writable legacy persistence APIs and commit**

Delete or unexport old package create/save, autosave rotation, recovery-copy, and journal append APIs after the importer has its internal readers.

```bash
git add Sources/VertexProjectPersistence Sources/VertexProject Tests/VertexProjectPersistenceTests
git rm -r Sources/VertexProjectFoundation Tests/VertexProjectFoundationTests
git commit -m "feat: import legacy projects non-destructively"
```

Expected: no public `VertexProjectFoundation` source remains.

---

### Task 7: Introduce `ProjectSessionActor` and canonical app flows on Phase 5

**Files:**
- Create: `App/ProjectDocumentTypes.swift`
- Create: `App/ProjectSessionActor.swift`
- Create: `App/LegacyProjectImportView.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Modify: `App/ProjectWorkspaceView.swift`
- Modify: `App/ProjectPackageFileDocument.swift`
- Modify: `App/RootView.swift`
- Modify: `App/VertexApp.swift`
- Test: `Tests/VertexCoreTests/StartupReadinessTests.swift`
- Test: `Tests/VertexProjectTests/ProjectSessionActorContractTests.swift` or app-target tests in `VertexTests`

**Interfaces:**
- Consumes: `ProjectEditingSession`, canonical package store, autosave, bookmarks, embedded media, legacy importer.
- Produces:

```swift
actor ProjectSessionActor {
    func create(name: String, packageURL: URL) async throws -> ProjectSessionSnapshot
    func openCanonical(packageURL: URL) async throws -> ProjectOpenOutcome
    func inspectLegacy(packageURL: URL) async throws -> LegacyImportInspection
    func importLegacy(sourceURL: URL, destinationURL: URL) async throws -> ProjectSessionSnapshot
    func apply(_ payload: ProjectCommandPayload, mergeKey: String?) async throws -> ProjectSessionSnapshot
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

- [ ] **Step 1: Write RED document-type tests**

Assert canonical exported UTType identifier `com.maze.vertex.project`, extension `vertexproject`, canonical open/edit, and `.aeproject` import-only behavior. Assert `ProjectPackageFileDocument.readableContentTypes` excludes legacy editing.

- [ ] **Step 2: Write RED actor-state tests**

Cover session Undo empty after reopen, save failure preserving document/history, autosave not clearing unsaved state, equal revision/checksum request coalescing, newer revision superseding older queued work, close choices, and stale completion rejection.

- [ ] **Step 3: Run RED app-contract tests**

```bash
swift test --filter StartupReadinessTests
swift test --filter ProjectSessionActorContractTests
```

Expected: FAIL because ViewModel directly writes WAL/history/package state.

- [ ] **Step 4: Implement document types and actor**

Register canonical and legacy UTTypes separately. Keep security-scoped access lifetime around each external URL operation. Capture immutable documents before persistence calls and call `session.markSaved` only after the store returns a verified snapshot.

- [ ] **Step 5: Replace ViewModel persistence fields**

Remove `historyController`, `journalSequence`, `ProjectPackageStore`, rotating autosave, embedded bookmark lookup, and direct package file edits. Store one actor and publish returned snapshots on MainActor.

- [ ] **Step 6: Implement explicit legacy conversion UI**

The view shows all inspection counts, destination selection, progress, cancellation, success, and failure. It never opens a legacy package directly and never registers a temporary destination as recent.

- [ ] **Step 7: Keep startup bounded**

`VertexApp` transitions from splash to workspace after the bounded minimum delay. Project inspection and Metal creation start after workspace presentation. Every guard sets a terminal state before return.

- [ ] **Step 8: Run app and package GREEN tests**

```bash
swift test
xcodegen generate
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Release -sdk iphoneos -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO clean build
```

Expected: portable tests and iOS Release compilation pass.

- [ ] **Step 9: Commit**

```bash
git add App Package.swift project.yml Tests
git commit -m "refactor: route projects through a session actor"
```

---

### Task 8: Verify and document corrected Phase 5 foundation

**Files:**
- Modify: `.github/workflows/phase-build.yml`
- Modify: `Documentation/PROJECT_PERSISTENCE_ARCHITECTURE.md`
- Modify: `Documentation/PROJECT_TEST_MATRIX.md`
- Modify: `Documentation/PHASE_5_WORK_LOG.md`
- Modify: `Documentation/HANDOFF.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: Tasks 1–7.
- Produces: a corrected Phase 5 branch that PR #6 can merge without depending on old public persistence APIs.

- [ ] **Step 1: Add static contract checks to CI**

```bash
! grep -R "VertexProjectFoundation" Package.swift project.yml App Sources Tests
! grep -R "bookmarkData" Sources/VertexProject
! grep -R "appliedCommandIDs" Sources/VertexProject
! grep -R "legacyRenderSettings" Sources/VertexProject
! grep -R "operations.log" Sources/VertexProjectPersistence App
! grep -R "history.json" Sources/VertexProjectPersistence App
```

Add a test fixture that creates a canonical package and compares its root entries to the allowlist.

- [ ] **Step 2: Run full Phase 5 correction verification**

```bash
swift test
swift test --filter VertexProjectPersistenceTests
xcodegen generate
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Release -sdk iphoneos -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO clean build
```

Expected: zero test failures and iOS build exit code 0.

- [ ] **Step 3: Update architecture and test documentation**

Replace every authoritative description of `.aeproject`, persisted history, WAL, mutable autosave, backup, proxy, thumbnail, recovery, or quarantine behavior. Preserve old evidence only in a clearly labeled superseded-history section.

- [ ] **Step 4: Commit and push corrected Phase 5**

```bash
git add .github/workflows Documentation README.md
git commit -m "docs: record corrected project persistence"
git push origin agent/phase-5-project-persistence
```

Expected: PR #5 stays Draft, targets Phase 4, and all correction checks pass.

---

# Execution Segment B — Reintegrate and Reverify Phase 6

### Task 9: Merge corrected Phase 5 into Phase 6 and restore canonical Schema 2

**Files:**
- Merge branch: `agent/phase-5-project-persistence` into `agent/phase-6-layers-compositions`
- Modify: `Package.swift`
- Modify: `project.yml`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Modify: `Sources/VertexProject/ProjectCommandPayload.swift`
- Modify: `Sources/VertexProject/ProjectTransition.swift`
- Modify: `Sources/VertexProject/ProjectEditingSession.swift`
- Modify: `Sources/VertexProjectPersistence/LegacyImport/LegacyProjectDTO.swift`
- Modify: `Sources/VertexProjectPersistence/LegacyImport/LegacyProjectImporter.swift`
- Test: `Tests/VertexProjectTests/ProjectCompositionSchemaTests.swift`
- Test: `Tests/VertexProjectTests/ProjectLayerCommandTests.swift`
- Test: `Tests/VertexProjectPersistenceTests/LegacySchema2ImportTests.swift`

**Interfaces:**
- Consumes: corrected Phase 5 persistence and existing Phase 6 composition/layer types.
- Produces: final canonical Schema 2 model without legacy or persistence fields.

- [ ] **Step 1: Merge without force-rewriting either draft branch**

```bash
git switch agent/phase-6-layers-compositions
git pull --ff-only origin agent/phase-6-layers-compositions
git merge --no-ff origin/agent/phase-5-project-persistence -m "merge: integrate corrected Phase 5 persistence"
```

Resolve conflicts by keeping corrected persistence APIs and Phase 6 composition/layer product behavior. Do not restore old WAL, history snapshots, bookmark fields, or old module imports.

- [ ] **Step 2: Write RED final-Schema-2 tests**

Assert canonical Schema 2 has media, composition, layer, active composition, selected layer, and selected media values while forbidden fields remain absent. Assert normalization chooses a valid active composition and clears invalid selection IDs.

- [ ] **Step 3: Extend payload and mutation cases for Phase 6**

Add exact desired-state payloads:

```swift
case createComposition(ProjectComposition, ownedLayers: [ProjectLayer], index: Int)
case removeComposition(id: VertexID)
case duplicateComposition(sourceID: VertexID, newCompositionID: VertexID, newLayerIDs: [VertexID])
case renameComposition(id: VertexID, to: String)
case setActiveComposition(VertexID?)
case setCompositionDimensions(id: VertexID, width: Int, height: Int)
case setCompositionDuration(id: VertexID, duration: RationalTime)
case setCompositionFrameRate(id: VertexID, frameRate: RationalTime)
case setCompositionBackground(id: VertexID, color: ProjectRGBAColor)
case insertLayer(ProjectLayer, compositionID: VertexID, index: Int)
case removeLayer(id: VertexID)
case duplicateLayer(sourceID: VertexID, duplicateID: VertexID, index: Int)
case renameLayer(id: VertexID, to: String)
case reorderLayer(compositionID: VertexID, layerID: VertexID, toIndex: Int)
case setSelectedLayer(VertexID?)
case setLayerEnabled(id: VertexID, value: Bool)
case setLayerLocked(id: VertexID, value: Bool)
case setLayerSolo(id: VertexID, value: Bool)
case setLayerTiming(id: VertexID, value: LayerTiming)
case setLayerTransform(id: VertexID, value: LayerTransform)
case setLayerBlendMode(id: VertexID, value: LayerBlendMode)
case setLayerSource(id: VertexID, value: LayerSource)
case setLayerOperations(id: VertexID, value: [LayerOperation])
```

The engine derives exact inverse mutations from the current document, including registry indices, owned layers, previous order, and prior values.

- [ ] **Step 4: Add legacy schema-2 DTO and conversion tests**

Decode the pre-correction Phase 6 `.aeproject` dialect, including legacy Render Lab fields, applied IDs, embedded bookmarks, history, and WAL. Preserve composition, layer, and media IDs and convert to canonical Schema 2.

- [ ] **Step 5: Run GREEN project and importer tests**

```bash
swift test --filter ProjectCompositionSchemaTests
swift test --filter ProjectLayerCommandTests
swift test --filter LegacySchema2ImportTests
```

Expected: Schema 2 and all layer command tests pass with no persisted history fields.

- [ ] **Step 6: Commit**

```bash
git add Package.swift project.yml Sources Tests
git commit -m "refactor: apply corrected persistence to schema 2"
```

---

### Task 10: Reconnect the Phase 6 composition workspace to the session actor

**Files:**
- Modify: `App/ProjectSessionActor.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Modify: `App/ProjectWorkspaceCompositionCommands.swift`
- Modify: `App/ProjectWorkspaceLayerSourceCommands.swift`
- Modify: `App/CompositionWorkspaceView.swift`
- Modify: `App/CompositionMediaFrameResolver.swift`
- Modify: `App/CompositionPreviewController.swift`
- Modify: `App/ProjectPackageFileDocument.swift`
- Test: `Tests/VertexCompositionTests/CompositionGraphCompilerTests.swift`
- Test: `Tests/VertexRenderMetalTests/MetalCompositionPixelTests.swift`
- Test: app-target `ProjectWorkspacePersistenceTests.swift`

**Interfaces:**
- Consumes: Phase 6 command payloads and corrected persistence actor.
- Produces: composition and layer UI operations that use one actor and one canonical package.

- [ ] **Step 1: Write RED workspace persistence tests**

Cover create, duplicate, delete, reorder, transform coalescing, locked-layer rejection, nested-cycle rejection, save, reopen with empty Undo/Redo, missing bookmark isolation, embedded media resolution, and legacy import conversion report.

- [ ] **Step 2: Run RED workspace tests**

```bash
swift test --filter ProjectWorkspacePersistenceTests
```

Expected: FAIL while Phase 6 helpers still call the old ViewModel operation/WAL path.

- [ ] **Step 3: Route every composition and layer edit through actor payloads**

Remove direct `ProjectCommandRecord`, `ProjectJournalRecord`, package store, and history-controller access from app files. Continuous inspector gestures pass stable merge keys and gesture IDs; reorders and structural edits pass no merge key.

- [ ] **Step 4: Resolve frames through corrected media stores**

Resolution order remains embedded media first, then bookmark sidecar, then Missing. A bookmark or one media error does not block project open or unrelated layers.

- [ ] **Step 5: Preserve preview and PNG parity**

Do not create a second render path. Continue compiling the same `CompositionRenderRequest` and using the same returned canonical pixel bytes for preview and PNG export.

- [ ] **Step 6: Run GREEN workspace and rendering tests**

```bash
swift test --filter ProjectWorkspacePersistenceTests
swift test --filter VertexCompositionTests
swift test --filter VertexRenderMetalTests
```

Expected: workspace persistence, compiler, blend, adjustment, nested composition, and pixel tests pass.

- [ ] **Step 7: Commit**

```bash
git add App Tests
git commit -m "refactor: persist compositions through project sessions"
```

---

### Task 11: Add end-to-end package, startup, and failure-path tests

**Files:**
- Create: `Tests/VertexProjectPersistenceTests/CanonicalPackageIntegrationTests.swift`
- Create: `Tests/VertexProjectPersistenceTests/ConcurrentPersistenceTests.swift`
- Create: `Tests/VertexProjectPersistenceTests/LegacyPhase6ImportIntegrationTests.swift`
- Modify: `Tests/VertexCoreTests/StartupReadinessTests.swift`
- Create: `Tests/VertexRenderMetalTests/PersistenceRenderRegressionTests.swift`

**Interfaces:**
- Consumes: final Schema 2, session actor, package store, autosave, importer, compiler, Metal backend.
- Produces: evidence that persistence correction does not weaken rendering or startup.

- [ ] **Step 1: Write complete package integration test**

Create a project with two media layers, one adjustment layer, and one nested composition; save to `.vertexproject`; assert allowlist; reopen; assert identical canonical project bytes; assert empty Undo/Redo; render and compare expected pixels.

- [ ] **Step 2: Write concurrency tests**

Use controllable persistence suspension points to prove:

- equal revision/checksum save requests coalesce;
- newer queued revision supersedes older queued autosave;
- stale completion cannot replace current ViewModel state;
- close with Save and Close waits for verified save;
- Discard Session Changes leaves verified autosaves untouched.

- [ ] **Step 3: Write startup failure tests**

Inject project inspection, pending decision, Metal initialization, and bookmark errors separately. Assert startup reaches workspace and only the affected surface shows a terminal error.

- [ ] **Step 4: Run RED then GREEN integration suite**

```bash
swift test --filter CanonicalPackageIntegrationTests
swift test --filter ConcurrentPersistenceTests
swift test --filter LegacyPhase6ImportIntegrationTests
swift test --filter StartupReadinessTests
swift test --filter PersistenceRenderRegressionTests
```

Expected after implementation: all pass with no indefinite state and no rendering change.

- [ ] **Step 5: Commit**

```bash
git add Tests
git commit -m "test: cover corrected project persistence end to end"
```

---

### Task 12: Final static checks, CI, and replacement 6.0 IPA

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

**Interfaces:**
- Consumes: all preceding tasks.
- Produces: verified replacement `After-Effects-6.0.0-unsigned.ipa` and durable evidence.

- [ ] **Step 1: Add exact static CI gates**

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

Add an executable test utility that creates a canonical package and fails unless the root allowlist and forbidden-entry checks match the spec.

- [ ] **Step 2: Run full Linux and macOS suites**

```bash
swift test
swift test --filter VertexProjectPersistenceTests
swift test --filter VertexCompositionTests
swift test --filter VertexRenderMetalTests
```

Expected: zero failures.

- [ ] **Step 3: Build iOS Release and package unsigned IPA**

```bash
xcodegen generate
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Release -sdk iphoneos -destination "generic/platform=iOS" -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO clean build
rm -rf Payload artifacts
mkdir -p Payload artifacts
cp -R DerivedData/Build/Products/Release-iphoneos/AfterEffects.app Payload/AfterEffects.app
zip -qry artifacts/After-Effects-6.0.0-unsigned.ipa Payload
shasum -a 256 artifacts/After-Effects-6.0.0-unsigned.ipa > artifacts/After-Effects-6.0.0-unsigned.ipa.sha256
```

- [ ] **Step 4: Inspect the downloaded artifact, not only the runner copy**

Verify display name, bundle name, identifier, version `6.0.0 (6)`, minimum iOS 17.0, arm64 executable, `Assets.car`, `default.metallib`, and exact IPA SHA-256. Record workflow run ID, artifact ID, artifact ZIP digest, IPA digest, size, executable path, and resource sizes.

- [ ] **Step 5: Update completion and handoff documents**

State that previous 6.0 artifacts are superseded. Record that the replacement artifact is the only permitted Phase 7 base. Document any manual device tests not performed.

- [ ] **Step 6: Remove temporary PR workflow trigger after final artifact run**

Keep normal `push` and `workflow_dispatch` behavior. Documentation-only commits must not rebuild the already recorded artifact.

- [ ] **Step 7: Commit final documentation and push**

```bash
git add .github/workflows Documentation README.md
git commit -m "docs: complete corrected Phase 6 persistence"
git push origin agent/phase-6-layers-compositions
```

Expected: PR #6 remains Draft and unmerged; final documentation HEAD may follow the recorded product/CI source HEAD.

---

### Task 13: Phase 7 creation gate

**Files:**
- Read: `Documentation/PHASE_6_COMPLETION.md`
- Read: `Documentation/VERSIONING_AND_ARTIFACTS.md`
- Read: `Documentation/HANDOFF.md`
- No Phase 7 source files are created in this task.

**Interfaces:**
- Consumes: successful Task 12 evidence.
- Produces: authorization to begin a separate Motion Engine design cycle.

- [ ] **Step 1: Verify every gate from Task 12 is recorded**

Confirm product source HEAD, successful CI run, artifact ID, downloaded artifact ZIP digest, IPA digest, bundle metadata, package allowlist evidence, startup test, and forbidden-field scans.

- [ ] **Step 2: Verify draft stack state**

```bash
git fetch origin
git merge-base --is-ancestor origin/agent/phase-5-project-persistence origin/agent/phase-6-layers-compositions
```

Expected: exit code 0; PR #5 and PR #6 remain Draft and unmerged.

- [ ] **Step 3: Create Phase 7 branch only after the gate passes**

```bash
git switch agent/phase-6-layers-compositions
git pull --ff-only origin agent/phase-6-layers-compositions
git switch -c agent/phase-7-motion-engine
git push -u origin agent/phase-7-motion-engine
```

Do not write Phase 7 implementation code. Start a new brainstorming and design-spec cycle for generic animation channels, interpolation, parenting, and motion blur.

---

## Plan Completion Criteria

The plan is complete only when:

1. PR #5 exposes `VertexProjectPersistence`, `.vertexproject`, session-only history, pending snapshots, immutable autosaves, sidecar bookmarks, and non-destructive legacy import.
2. PR #6 contains canonical Schema 2 layers and compositions on top of that corrected foundation.
3. No public or app source imports `VertexProjectFoundation`.
4. No canonical JSON or autosave contains bookmark bytes, applied command IDs, legacy render settings, Undo/Redo, or inverses.
5. No canonical package creates or accepts history, WAL, backup, proxy, thumbnail, recovery, or quarantine entries.
6. Startup cannot remain indefinitely on the splash screen because of phase, project, Metal, media, bookmark, or recovery checks.
7. The replacement 6.0.0 IPA passes downloaded-artifact inspection and is explicitly recorded as the only Phase 7 base.
