# Phase 5–6 Persistence Correction Design

**Status:** Approved design; implementation has not started.

**Corrected product version:** `6.0.0 (6)`

**Canonical project extension:** `.vertexproject`

**Legacy import extension:** `.aeproject`

**Implementation gate:** Phase 7 may not branch from the current persistence implementation. Phase 5 and Phase 6 must first be corrected, reverified, and produce a replacement 6.0.0 artifact.

## 1. Purpose and scope

The current Phase 5 and Phase 6 drafts persist Undo and Redo history, append an operation write-ahead log, rotate mutable autosave files, store Apple bookmark bytes inside canonical project JSON, and create backup, proxy, thumbnail, recovery, and quarantine locations. Those behaviors diverge from the approved architecture.

This correction replaces that dialect with a deterministic `.vertexproject` package based on one full pending-save snapshot. It preserves valid project, composition, layer, and media data while removing persistence implementation state from the portable model.

This is not a new feature phase. It does not implement keyframes, interpolation, parenting, motion blur, playback, retiming, video export, masks, tracking, AI, text, shapes, audio, color, particles, nodes, or 3D. The product remains `6.0.0 (6)` until the corrected package, app flows, tests, iOS build, and downloaded IPA inspection pass.

Non-negotiable outcomes:

- new projects use `.vertexproject`;
- `VertexProject` remains platform-neutral;
- public file-system APIs move to `VertexProjectPersistence`;
- Undo and Redo are session-only;
- canonical projects have no durable command WAL;
- a save uses `Journal/pending-save.json` containing a complete candidate snapshot;
- autosaves are immutable, checksummed full-document snapshots;
- Apple bookmark bytes exist only in `Bookmarks/<mediaID>.bookmark`;
- `.aeproject` packages are import-only and never modified;
- no project, media, Metal, bookmark, or recovery error can leave the app in indefinite loading;
- existing Phase 6 layer and composition rendering remains intact;
- every earlier 6.0 IPA is marked as a superseded draft artifact.

## 2. Canonical package contract

Normal package layout:

```text
Project.vertexproject/
├── project.json
├── manifest.json
├── Journal/
│   └── pending-save.json       # only while a save is incomplete
├── Autosaves/
│   └── <sequence>-<checksum>.json
├── Bookmarks/
│   └── <mediaID>.bookmark
└── Media/
    └── <mediaID>-<sanitized-filename>
```

`Journal/`, `Autosaves/`, `Bookmarks/`, and `Media/` are created as package directories and may be empty.

The only transaction-temporary package entries permitted are:

```text
project.json.tmp
manifest.json.tmp
Journal/pending-save.json.tmp
Autosaves/<sequence>-<checksum>.json.tmp
Bookmarks/<mediaID>.bookmark.tmp
Media/<mediaID>-<filename>.tmp
```

A loader checks for and classifies pending transactions before enforcing the steady-state allowlist. Unknown `.tmp` names are not accepted. Successful save, recovery, autosave, relink, or embedding operations remove their temporary files before reporting success.

Forbidden canonical entries include:

```text
history.json
journal/operations.log
project.json.backup
snapshot-current.json
snapshot-previous.json
Proxies/ or proxies/
Thumbnails/ or thumbnails/
Recovery/ or recovery/
Quarantine/ or quarantine/
```

Unknown root entries are rejected unless a future package-format version explicitly adds them to the allowlist. An ordinary folder, malformed package, renamed ZIP, or writable `.aeproject` is not accepted as a canonical project.

## 3. Canonical Schema 2 model

The canonical project contains product state, not persistence machinery.

The canonical encoder never emits:

- `MediaLocator.bookmarkData`;
- `ProjectDocument.appliedCommandIDs`;
- `ProjectDocument.legacyRenderSettings`.

A legacy DTO may decode those fields solely during `.aeproject` import. They are never exposed as canonical writable properties.

`MediaReference` retains only portable values:

- stable media ID;
- display and original filename;
- kind and availability status;
- file size and modification metadata where available;
- content fingerprint;
- optional package-relative embedded path;
- optional non-authoritative relative path hint.

`activeCompositionID`, `selectedLayerID`, and `selectedMediaID` may be persisted as workspace convenience state. They never enter Undo history. Validation rules are explicit:

- an invalid active composition normalizes to the first canonical composition;
- an invalid selected layer normalizes to `nil`;
- an invalid selected media ID normalizes to `nil`.

Legacy Render Lab values are converted once during import into actual composition dimensions, layer transform, opacity, and operations. No compatibility Render Lab field remains in the canonical document.

Duplicate-command protection uses a session-local recent-command set and is not serialized. The corrected dialect remains Project Schema 2; the package extension, manifest package-format version, and decoder boundary distinguish legacy `.aeproject` from canonical `.vertexproject`. This correction does not consume Schema 3.

## 4. Module boundaries

### 4.1 `VertexProject`

Portable responsibilities:

- canonical project, composition, layer, and media models;
- deterministic JSON and project checksum;
- project validation and nested-composition cycle checks;
- command requests and inverse calculation;
- in-memory editing session;
- bounded Undo and Redo;
- command coalescing;
- portable structured errors.

It may not expose file URLs, Apple bookmarks, security-scoped access objects, file descriptors, AVFoundation, Metal, UIKit, SwiftUI, or absolute sandbox paths.

### 4.2 `VertexProjectPersistence`

Platform and file-system responsibilities:

- `.vertexproject` layout and allowlist validation;
- durable temporary writes, file synchronization, and directory synchronization;
- pending-snapshot save and recovery;
- immutable autosave creation, validation, retention, and selection;
- bookmark sidecar creation, replacement, resolution, and stale refresh;
- embedded-media copy and fingerprint validation;
- legacy `.aeproject` inspection and non-destructive conversion;
- package-level structured errors.

The public `VertexProjectFoundation` product is removed. New source and tests may not import it. Minimum legacy readers may live under `VertexProjectPersistence/LegacyImport`, remain internal, and cannot create or save new packages.

### 4.3 Application layer

The app owns Files document pickers, UTType registration, recent-project registration, user-facing conversion and recovery decisions, security-scoped access lifetime, UI operation states, and startup presentation. It accesses project persistence through one `ProjectSessionActor` and does not edit package files directly.

## 5. Editing session and Undo/Redo

Session state:

```text
ProjectEditingSession
├── loadedSnapshot
├── document
├── undoStack
├── redoStack
├── recentCommandIDs
├── savedRevision
├── hasUnsavedChanges
└── activeTransaction
```

- **Loaded snapshot:** the validated document read when the session opened.
- **Working document:** the current editable in-memory document.
- **Durable saved snapshot:** the latest full transaction that completed and was reverified.

Rules:

- Undo and Redo start empty whenever a project opens and are discarded on close or process termination.
- They are absent from project JSON, manifest, pending snapshot, autosaves, and bookmark sidecars.
- A successful command calculates its inverse from the current document, pushes that inverse to Undo, and clears Redo.
- Undo pushes the corresponding forward transition onto Redo.
- Redo validates against the current state, recalculates the inverse, and pushes it to Undo.
- Each history stack holds at most 200 user edits, dropping the oldest first.
- `recentCommandIDs` holds the most recent 512 IDs for the active session; it is cleared on open and close and never persisted.
- Continuous edits coalesce only when command type, merge key, target identity, and editing gesture match.
- Create, delete, duplicate, and reorder commands never coalesce.
- Selection and active-composition navigation do not create Undo entries.
- Locked layers reject mutation except explicit unlock.
- Invalid references and nested-composition cycles fail before the document or history stacks change.

A command request contains command ID, expected base revision, timestamp, optional merge key, and payload. Historical inverses are never written to disk.

## 6. Full pending-snapshot save

### 6.1 Exact pending format

`Journal/pending-save.json` is a deterministic JSON envelope containing:

- package-format version;
- transaction ID;
- project ID;
- candidate revision;
- creation timestamp;
- exact canonical `project.json` bytes as Base64;
- SHA-256 of those exact project bytes;
- exact canonical `manifest.json` bytes as Base64;
- SHA-256 of those exact manifest bytes.

The decoder verifies both Base64 payloads, both checksums, project-to-manifest identity, schema, revision, and project checksum before treating the envelope as a recovery candidate. It contains no Undo, Redo, command log, bookmark bytes, or external absolute paths.

### 6.2 Save protocol

1. Serialize the request through `ProjectSessionActor`.
2. Capture an immutable working document value.
3. Validate and canonically encode the project.
4. Calculate the project checksum and construct the matching manifest.
5. Canonically encode and validate the pending envelope.
6. Durably write `Journal/pending-save.json.tmp`, synchronize it, atomically promote it to `pending-save.json`, and synchronize `Journal/`.
7. Durably write `project.json.tmp` and `manifest.json.tmp`.
8. Atomically replace `project.json` and `manifest.json`.
9. Reopen both files and verify project ID, schema, revision, project checksum, manifest checksum, and canonical re-encoding.
10. Delete `pending-save.json`, remove remaining known transaction temporary files, and synchronize affected directories.
11. Only then update `savedRevision` and clear `hasUnsavedChanges`.

There is no `history.json`, operation log, or backup project file.

### 6.3 Failure semantics

File I/O does not mutate the working document or session history. On failure:

- the working document remains available;
- Undo and Redo remain available;
- `hasUnsavedChanges` remains true;
- the UI reaches an explicit failure state with retry;
- the last complete durable pair and any valid pending candidate remain classifiable on next open.

“Restore original state” means no partial persistence operation corrupts session state. It does not mean discarding unsaved user edits.

## 7. Pending recovery

Package open classifies known temporary files and `pending-save.json` before returning a document.

- If current project and manifest are valid and exactly match the pending candidate, delete the redundant pending marker and known candidate temporary files.
- If a valid pending candidate has a greater revision than the current valid pair, complete both replacements and reverify.
- If project and manifest are mixed because only one replacement completed, a valid matching pending candidate completes both before exposure.
- If the pending candidate is corrupt, internally inconsistent, or cannot be proven newer, do not apply or delete it automatically.
- If the pending candidate is older than a valid current pair, return `pendingSnapshotOlderThanCurrent`; the app asks whether to discard it.
- Uncertain pending data is not moved to a hidden quarantine directory. It remains until explicit discard or diagnostic export.

Only a fully matched project and manifest pair is returned. A mixed-revision pair is never exposed to the app.

## 8. Immutable autosaves

Autosave filename:

```text
Autosaves/<zero-padded-sequence>-<project-checksum>.json
```

The autosave envelope contains creation timestamp, project ID, revision, exact canonical project payload, and checksum. It contains no Undo, Redo, command IDs, or bookmark bytes.

Sequence rules:

- read valid canonical autosave filenames;
- select the greatest valid sequence;
- next sequence is greatest plus one, beginning at `00000001`;
- malformed filenames do not influence the sequence and are reported as invalid entries;
- sequence exhaustion is a structured error rather than wraparound.

Behavior:

- existing autosave bytes are never overwritten;
- write to the exact candidate `.tmp`, synchronize, decode, canonically re-encode, and verify checksum before promotion;
- suppress duplicate revision-and-checksum snapshots;
- retain the eight newest valid unique snapshots;
- delete old snapshots only after the new one is fully verified;
- corrupt snapshots are never selected for recovery;
- autosave success does not clear `hasUnsavedChanges`.

Autosave requests occur two seconds after the latest edit, after twenty unsaved commands, on backgrounding, and before opening another project. Requests for an equal revision and checksum coalesce.

## 9. Bookmark sidecars and media

External bookmark path:

```text
Bookmarks/<mediaID>.bookmark
```

Rules:

- the filename is the lowercase canonical media ID plus `.bookmark`;
- bookmark writes use `<mediaID>.bookmark.tmp`, synchronization, validation where supported, and atomic replacement;
- stale bookmarks are refreshed after successful resolution when the platform permits;
- missing, stale, or unreadable bookmarks do not prevent project open;
- only affected media becomes Missing and receives a Relink action;
- successful Relink updates portable metadata and atomically replaces the sidecar;
- embedded media does not require an external bookmark;
- embedded media is copied through a `.tmp` destination and promoted only after fingerprint verification;
- embedded checksum mismatch isolates that media and emits a warning without failing unrelated project data.

Security-scoped access starts and stops in the application or persistence adapter and is never represented in portable models.

## 10. Non-destructive `.aeproject` import

Legacy projects are import-only and never directly edited.

```text
Select .aeproject
→ inspect
→ show conversion report
→ choose destination
→ construct <name>.vertexproject.tmp
→ verify canonical package
→ atomically promote destination
→ open new project
```

The report shows composition, layer, and media counts; embedded media eligible for verified copy; bookmark extraction successes and failures; discarded persistent Undo/Redo, backup, and mutable autosave data; valid WAL records applied; and truncated, corrupt, unknown, or post-gap records ignored.

Import algorithm:

1. Calculate a deterministic source-tree digest from sorted relative paths and file bytes. Filesystem timestamps and permissions are excluded.
2. Inspect legacy project and manifest before decoding as writable state.
3. Replay only complete, checksummed, contiguous WAL records after the manifest’s committed sequence.
4. Accept valid complete records before a truncated final record.
5. Stop at the first sequence gap, checksum failure, unknown command, or invalid transition.
6. Preserve project, composition, layer, and media IDs.
7. Convert legacy Render Lab data once into canonical composition and layer values.
8. Discard persistent history, backup files, and legacy mutable autosaves.
9. Copy embedded media only after source fingerprint verification and verify destination bytes.
10. Extract valid bookmark bytes into sidecars; invalid bookmark data changes only that media to Missing.
11. Use the legacy project’s normalized creation and modification timestamps in canonical project metadata. The wall-clock import time is not written into canonical `project.json`.
12. Encode canonical Schema 2 without legacy-only fields.
13. Verify destination allowlist, project, manifest, media, and sidecars before promotion.
14. Recalculate the source-tree digest and require an exact match before reporting success.

The original `.aeproject` remains unchanged. On failure, remove the incomplete `.vertexproject.tmp`, do not register it as recent, and show the precise failing stage.

Importing the same unchanged source twice under the same importer version produces identical canonical `project.json` bytes. Destination manifest transaction metadata, bookmark binary representation, filesystem timestamps, and package placement are excluded from that equality guarantee.

## 11. App document types, startup, and concurrency

Canonical document type:

```text
Identifier: com.maze.vertex.project
Extension: vertexproject
Mode: open and edit
```

Legacy document type:

```text
Extension: aeproject
Mode: import and convert only
```

Startup state:

```text
StartupState
├── splash
├── workspace
└── fatalConfigurationError
```

The splash has a bounded minimum display time and transitions to the workspace unless the app bundle cannot construct its root UI. Recent-project inspection, pending recovery, Metal initialization, media access, and bookmark resolution run after workspace entry or within bounded tasks.

- project inspection failure opens an empty workspace and presents recovery choices;
- Metal failure affects only preview and export surfaces;
- bookmark failure affects only its media reference;
- cancelled or superseded tasks cannot overwrite newer UI state;
- every operation has explicit success, failure, and cancellation terminal states;
- an internal guard may not return while leaving a loading state active.

All project mutation and persistence is serialized by:

```text
ProjectSessionActor
├── open()
├── apply(command)
├── undo()
├── redo()
├── save()
├── autosave()
├── importLegacy()
└── close()
```

Save and autosave operate on immutable captured documents. A newer revision supersedes an older queued request. Equal revision and checksum requests coalesce. Stale completions cannot overwrite current UI state.

Closing with unsaved changes offers exactly:

```text
Save and Close
Discard Session Changes
Cancel
```

Discard clears session edits and history but does not silently delete verified autosaves.

## 12. Structured errors

`ProjectPersistenceError` has stable categories:

- `unsupportedPackageExtension`
- `forbiddenPackageEntry`
- `invalidManifest`
- `checksumMismatch`
- `pendingSnapshotCorrupt`
- `pendingSnapshotOlderThanCurrent`
- `atomicReplacementFailed`
- `autosaveVerificationFailed`
- `bookmarkMissing`
- `bookmarkStale`
- `embeddedMediaMismatch`
- `legacyJournalCorrupt`
- `legacyImportIncomplete`
- `concurrentRequestSuperseded`

Errors may include safe project ID, media ID, package-relative entry, revision, sequence, import stage, and expected or actual checksum. Persisted diagnostics do not contain bookmark bytes or unrestricted absolute paths.

Package integrity and media availability are isolated. One bookmark failure cannot fail a project. Checksum disagreement cannot cause an unverified overwrite. Uncertain pending state requires explicit user action. Failure and cancellation always end progress UI.

## 13. TDD and verification

### Package and model

- new-package allowlist test;
- forbidden legacy entry tests;
- known temporary-file classification tests;
- canonical JSON excludes `bookmarkData`, `appliedCommandIDs`, and `legacyRenderSettings`;
- public package products and imports contain no `VertexProjectFoundation`;
- writable document extension is exactly `.vertexproject`.

### Pending save failure injection

Inject failure:

1. before pending write;
2. after pending synchronization;
3. after project temporary write;
4. after project replacement and before manifest replacement;
5. after both replacements and before verification;
6. after verification and before pending deletion.

Each reopened package produces either the last complete pair or the complete candidate pair. No mixed revision is exposed.

### Autosave

- immutable existing bytes;
- sequence and checksum filename;
- deterministic next-sequence calculation;
- duplicate suppression;
- eight-snapshot retention;
- corruption rejection;
- no history, command IDs, or bookmark payload.

### Bookmark and media

- canonical sidecar name;
- atomic replacement;
- stale refresh;
- missing-bookmark media isolation;
- Relink sidecar replacement;
- embedded-media independence and fingerprint verification.

### Legacy import

- source-tree digest unchanged before and after;
- contiguous WAL replay and first-gap stop;
- truncated-final-record handling;
- history, backup, and mutable-autosave discard;
- stable identity preservation;
- deterministic timestamp policy and canonical bytes;
- bookmark extraction and failure isolation;
- embedded-media verification;
- temporary destination cleanup and recent-project invariance on failure.

### Session, startup, and regressions

- Undo/Redo empty after reopen;
- 200-entry history bounds and 512 command-ID bounds;
- command coalescing rules;
- save-failure preservation of working document and history;
- save/autosave race handling;
- splash completion across later phase numbers;
- project, Metal, and bookmark failures do not block workspace entry;
- all existing Phase 6 schema, command, compiler, Metal pixel, adjustment, blend, nested-composition, preview, PNG, relink, and embed tests remain active.

## 14. CI, branches, and artifact gate

Required CI evidence:

- Linux portable tests;
- macOS persistence failure-injection tests;
- macOS legacy import tests;
- Metal shader and pixel tests;
- composition compiler tests;
- iOS 17 arm64 Release build;
- startup regression test;
- package allowlist inspection;
- static forbidden-module, extension, entry, and canonical-field checks;
- downloaded IPA inspection;
- artifact ZIP and IPA SHA-256 recording.

Branch sequence:

1. Correct Phase 5 and PR #5 with `VertexProjectPersistence` and the canonical package contract.
2. Rebase or retarget Phase 6 onto the corrected Phase 5 state and adapt the app without weakening layers and compositions.
3. Produce and inspect the replacement `After-Effects-6.0.0-unsigned.ipa`.
4. Record product HEAD, CI run, artifact ID, checksums, bundle metadata, and package evidence.
5. Mark every previous 6.0 artifact: `Superseded draft artifact — do not use as the Phase 7 base`.
6. Only then create `agent/phase-7-motion-engine` and begin a separate Phase 7 design and implementation cycle.