# Phase 5–6 Persistence Correction Design

**Status:** Approved design; implementation has not started.

**Product version after correction:** `6.0.0 (6)`

**Canonical project extension:** `.vertexproject`

**Legacy import extension:** `.aeproject`

**Implementation gate:** Phase 7 may not branch from or depend on the current persistence implementation. Phase 5 and Phase 6 must first be corrected, reverified, and produce a replacement 6.0.0 artifact.

## 1. Purpose

The current Phase 5 and Phase 6 drafts implement a persistence dialect that diverges from the approved architecture. It persists Undo and Redo history, appends an operation write-ahead log, rotates mutable autosave files, stores Apple bookmark bytes inside canonical project JSON, and creates authoritative backup, proxy, thumbnail, recovery, and quarantine locations.

This correction replaces that dialect with a small, deterministic, recoverable package based on full pending snapshots. It preserves valid project, composition, layer, and media data while removing persistence state from the portable model.

The correction is not a new feature phase. The app remains `6.0.0 (6)` until the corrected package, app flows, tests, iOS build, and downloaded IPA inspection all pass.

## 2. Non-negotiable outcomes

The corrected system must satisfy all of the following:

- New projects use the `.vertexproject` extension.
- `VertexProject` remains platform-neutral.
- File-system behavior is owned by a public `VertexProjectPersistence` module.
- Undo and Redo exist only in the active editing session.
- No durable operation WAL is used for new projects.
- A save uses one full `Journal/pending-save.json` transaction.
- Autosaves are immutable full-document snapshots identified by sequence and checksum.
- Apple bookmark data is stored only in `Bookmarks/<mediaID>.bookmark` sidecars.
- Existing `.aeproject` packages are imported into a separate `.vertexproject` package and are never modified in place.
- A project, media, Metal, recovery, or bookmark error cannot leave the app on an indefinite loading screen.
- Existing layer and composition rendering behavior remains unchanged unless required to consume the corrected canonical model.
- All existing 6.0 artifacts are marked as superseded draft artifacts and are not valid Phase 7 bases.

## 3. Canonical package contract

A normal project package has the following allowlisted structure:

```text
Project.vertexproject/
├── project.json
├── manifest.json
├── Journal/
│   └── pending-save.json       # exists only during an incomplete save
├── Autosaves/
│   └── <sequence>-<checksum>.json
├── Bookmarks/
│   └── <mediaID>.bookmark
└── Media/
    └── <mediaID>-<sanitized-filename>
```

`Journal/`, `Autosaves/`, `Bookmarks/`, and `Media/` are created as package directories. They may be empty. Temporary files may exist during a transaction but must be removed after a successful operation or a completed recovery.

The following entries are forbidden in a canonical package:

```text
history.json
journal/operations.log
project.json.backup
snapshot-current.json
snapshot-previous.json
Proxies/
proxies/
Thumbnails/
thumbnails/
Recovery/
recovery/
Quarantine/
quarantine/
```

Unknown root entries are rejected unless a future package version explicitly adds them to the allowlist. Renaming an arbitrary folder or ZIP archive to `.vertexproject` does not make it valid.

## 4. Canonical project model

The canonical Schema 2 document contains product data, not persistence implementation state.

The following fields are removed from canonical encoding:

- `MediaLocator.bookmarkData`
- `ProjectDocument.appliedCommandIDs`
- `ProjectDocument.legacyRenderSettings`

`MediaReference` retains only portable identity and location hints:

- stable media ID;
- display and original filename;
- media kind and availability state;
- file size and modification metadata where available;
- content fingerprint;
- optional package-relative embedded path;
- optional non-authoritative relative path hint.

Apple bookmark bytes never enter `project.json`, autosaves, command payloads, diagnostics, or logs.

Legacy Render Lab values are read only by a legacy DTO. During import they are converted once into the appropriate composition dimensions, layer transform, opacity, and operation values. They are not carried into the canonical document as a compatibility field.

Duplicate-command protection is session-local. Canonical project bytes do not contain applied command IDs.

`activeCompositionID` and `selectedLayerID` may be persisted as workspace convenience state. Changes to these values do not create Undo entries. They must always be validated against the current composition and layer registries; invalid values normalize to a valid active composition and no selected layer.

The corrected canonical dialect remains Schema 2. The package contract and decoder boundary distinguish the legacy `.aeproject` dialect from the canonical `.vertexproject` dialect. This correction does not consume Schema 3.

## 5. Module boundaries

### 5.1 VertexProject

`VertexProject` owns portable data and editing semantics:

- canonical Schema 2 project, composition, layer, and media models;
- deterministic canonical JSON and project checksums;
- project validation and nested-composition cycle checks;
- command request and inverse calculation;
- the in-memory editing session;
- bounded Undo and Redo stacks;
- command coalescing;
- structured portable project errors.

It must not expose Foundation file URLs, Apple bookmarks, file descriptors, AVFoundation, Metal, UIKit, SwiftUI, or absolute sandbox paths.

### 5.2 VertexProjectPersistence

`VertexProjectPersistence` owns platform and file-system behavior:

- `.vertexproject` layout and package allowlist validation;
- durable temporary writes and directory synchronization;
- pending-snapshot save and recovery;
- immutable autosave creation, verification, retention, and selection;
- bookmark sidecar creation, replacement, resolution, and stale handling;
- embedded-media copy, checksum verification, and resolution;
- legacy `.aeproject` inspection and non-destructive import;
- package-level structured errors.

The public `VertexProjectFoundation` product is removed. New app and test code may not import it. Minimal legacy readers may live under `VertexProjectPersistence/LegacyImport`, but they are internal compatibility code and cannot be used to create or save new packages.

### 5.3 Application layer

The app owns:

- Files document pickers and UTType registration;
- user-facing conversion and recovery decisions;
- recent-project registration;
- security-scoped access lifetime;
- UI state for save, autosave, import, relink, and recovery;
- startup state and error presentation.

The app talks to project persistence through one `ProjectSessionActor` and never edits package files directly.

## 6. Editing session and Undo/Redo

An open project is represented by:

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

Definitions:

- **Loaded snapshot:** the last validated document loaded from disk.
- **Working document:** the current in-memory editable document.
- **Durable saved snapshot:** the latest document whose full save transaction completed and was reverified.

Undo and Redo rules:

- both stacks start empty whenever a project is opened;
- both stacks are discarded when the project is closed or the app session ends;
- they are not encoded in project JSON, manifest, pending snapshot, autosave, or bookmark sidecars;
- a successful new command pushes its calculated inverse onto Undo and clears Redo;
- Undo pushes the original transition onto Redo;
- Redo recalculates the inverse from the current valid state and pushes it onto Undo;
- stacks contain at most 200 user edits, dropping the oldest entry first;
- continuous controls coalesce only when command type, merge key, target layer, and editing gesture match;
- create, delete, duplicate, and reorder commands never coalesce;
- selection and active-composition navigation do not enter edit history;
- locked layers reject mutating commands except the explicit unlock command;
- a command that would introduce an invalid reference or nested-composition cycle fails before changing the document or either history stack.

A command request contains a command ID, expected base revision, timestamp, optional merge key, and payload. The engine derives the inverse from the current document. Neither the request nor the canonical project persists a historical inverse.

## 7. Save transaction

A durable explicit save uses one full pending snapshot.

### 7.1 Pending snapshot contents

`Journal/pending-save.json` contains enough information to complete or classify the candidate save without consulting session history:

- package format version;
- project ID;
- candidate project revision;
- canonical candidate `project.json` bytes or an encoded lossless representation of them;
- candidate project checksum;
- candidate manifest bytes or complete manifest fields;
- transaction ID and creation timestamp.

It contains no Undo, Redo, command log, bookmark bytes, or external absolute paths.

### 7.2 Save protocol

1. Serialize all session mutations through `ProjectSessionActor`.
2. Validate the current working document.
3. Canonically encode the document and calculate its checksum.
4. Construct and validate the matching manifest.
5. Durably write and synchronize `Journal/pending-save.json`.
6. Durably write `project.json.tmp` and `manifest.json.tmp` in the package volume.
7. Atomically replace `project.json` and `manifest.json` with the candidate files.
8. Reopen both canonical files and verify project ID, schema, revision, checksum, and canonical re-encoding.
9. Delete `pending-save.json` and synchronize the Journal directory.
10. Update `savedRevision` and clear `hasUnsavedChanges` only after step 9 succeeds.

There is no `history.json`, operation log, or project backup file.

### 7.3 Failure semantics

A save function must not mutate the working document or Undo/Redo stacks as a side effect of file I/O. On failure:

- the working document remains available;
- Undo and Redo remain available;
- `hasUnsavedChanges` remains true;
- the last fully verified durable snapshot remains a valid recovery candidate;
- the UI exits its progress state and shows a structured error and retry action.

The phrase “restore original state” refers to preventing partial file-system operations from corrupting session state. It does not mean discarding the user’s unsaved edits.

## 8. Pending-snapshot recovery

Package open inspects `pending-save.json` before exposing a project document.

Classification rules:

- If current project and manifest are valid and exactly match the pending candidate, remove the redundant pending marker.
- If the pending candidate is valid, newer than the current valid snapshot, and internally consistent, complete both canonical replacements and reverify them.
- If one canonical file was replaced and the other was not, a valid pending candidate is used to complete both files before the project is exposed.
- If the pending snapshot is corrupt, internally inconsistent, or cannot be proven newer, do not apply it automatically.
- If the pending snapshot is older than a valid current snapshot, report `pendingSnapshotOlderThanCurrent`; the app asks whether to discard the marker.
- Uncertain pending data is not moved into a quarantine directory. It remains untouched until the user explicitly chooses to discard it or export diagnostics.

After recovery, only a fully matched project and manifest pair may be returned. A mixed-revision pair is never exposed to the app.

## 9. Immutable autosaves

Autosaves are complete canonical project snapshots with a small autosave envelope containing creation metadata. They contain no editing history or bookmark bytes.

Filename format:

```text
Autosaves/<zero-padded-sequence>-<project-checksum>.json
```

Rules:

- sequence numbers increase monotonically within a package;
- an existing autosave is never overwritten;
- the new file is durably written, decoded, canonically re-encoded, and checksum-verified before retention cleanup;
- a duplicate revision and checksum does not create another autosave;
- the eight newest valid unique snapshots are retained;
- invalid or corrupt autosaves are never selected as recovery candidates;
- deleting older autosaves occurs only after the new snapshot has been fully verified;
- autosave success does not mark the explicit project save as complete and does not clear `hasUnsavedChanges`.

Autosave requests occur after two seconds of edit inactivity, after twenty unsaved commands, on app backgrounding, and before opening another project. The actor coalesces requests for the same revision and checksum.

## 10. Bookmark sidecars and media

External access data is stored at:

```text
Bookmarks/<mediaID>.bookmark
```

Rules:

- sidecar filenames use the canonical media ID exactly;
- bookmark creation and replacement are atomic;
- a stale bookmark is refreshed after successful resolution when the platform permits it;
- a missing, stale, or unreadable bookmark does not prevent the project from opening;
- only the affected media is marked missing and offered for Relink;
- a successful Relink updates the portable metadata and atomically replaces the sidecar;
- embedded media does not require an external bookmark;
- embedded files are stored under `Media/` and are verified against the reference fingerprint before use;
- an embedded checksum mismatch marks that media missing and emits a warning without corrupting the rest of the project.

Security-scoped access starts and stops in the application or persistence adapter. It is not represented in portable models.

## 11. Legacy `.aeproject` import

A legacy package is import-only. It is never opened for direct editing and never modified.

User flow:

```text
Select .aeproject
→ inspect legacy package
→ show conversion report
→ choose destination
→ build <name>.vertexproject.tmp
→ verify complete canonical package
→ atomically promote destination
→ open new project
```

The conversion report includes:

- composition count;
- layer count;
- media count;
- embedded media eligible for verified copy;
- bookmark sidecars successfully extracted or failed;
- discarded persistent Undo and Redo entries;
- discarded legacy autosave and backup candidates;
- valid WAL records applied;
- truncated, corrupt, or post-gap WAL records ignored.

Import rules:

1. Calculate and retain a whole-package fingerprint or equivalent evidence proving the source did not change.
2. Inspect legacy project and manifest before decoding as writable state.
3. Replay only complete, checksummed, contiguous WAL records after the committed sequence.
4. Accept complete records before a truncated final record.
5. Stop at the first sequence gap, checksum failure, unknown command, or invalid transition.
6. Preserve project, composition, layer, and media IDs.
7. Convert legacy Render Lab values into canonical composition or layer properties once.
8. Discard legacy persistent Undo/Redo history, backup files, and mutable autosaves.
9. Copy embedded media only after fingerprint verification and verify the destination copy.
10. Extract valid bookmark bytes into sidecars; invalid bookmark bytes produce missing-media status rather than total import failure.
11. Encode the canonical project without legacy-only fields.
12. Verify the entire destination package and allowlist before promotion.
13. Confirm the source package evidence is unchanged after import.

If any mandatory step fails:

- the original `.aeproject` remains unchanged;
- the temporary destination is removed;
- no incomplete project is registered as recent;
- the app displays the precise import stage and error;
- a retry starts from a new temporary destination.

Importing the same unchanged source twice with the same canonical import policy produces identical canonical `project.json` bytes. Autosave sequence values, sidecar bytes, and filesystem timestamps are not part of this canonical-byte equality requirement.

## 12. App document types and startup

Canonical UTType:

```text
Identifier: com.maze.vertex.project
Extension: vertexproject
Mode: open and edit
```

Legacy type:

```text
Extension: aeproject
Mode: import and convert only
```

The app rejects ordinary folders, malformed packages, and renamed ZIP archives after structure and manifest inspection.

Startup is independent of project recovery and release phase numbers:

```text
StartupState
├── splash
├── workspace
└── fatalConfigurationError
```

The splash has a bounded minimum display time and always transitions to the workspace unless the app bundle is so incomplete that the root UI cannot be constructed. Recent-project inspection, pending recovery, Metal initialization, media relinking, and bookmark resolution occur after workspace entry or within bounded tasks.

Specific failure behavior:

- project inspection failure opens an empty workspace and presents recovery choices;
- Metal initialization failure affects only preview and export surfaces;
- bookmark failure affects only the referenced media;
- cancelled or superseded startup tasks cannot overwrite newer UI state;
- every async operation has explicit success, failure, and cancellation terminal states;
- no `ProgressView` may remain indefinitely because an internal guard returned without completing its state transition.

## 13. Concurrency

All project mutation and persistence requests are serialized by one actor:

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

Rules:

- save and autosave operate on immutable captured document values;
- a newer revision supersedes an older queued request;
- equal revision and checksum requests coalesce;
- stale completion callbacks cannot overwrite current UI state;
- opening another project first resolves the current close decision;
- close with unsaved changes offers exactly `Save and Close`, `Discard Session Changes`, and `Cancel`;
- discard removes session edits and history but does not delete verified autosaves without a separate user action.

## 14. Structured errors

`ProjectPersistenceError` provides stable categories:

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

Errors include safe context such as package entry, project ID, media ID, expected and actual checksum, revision, sequence, or import stage. They do not include bookmark bytes or unrestricted absolute paths in persisted diagnostics.

Error isolation principles:

- package integrity errors and media availability errors are separate;
- one failed bookmark cannot fail the whole project;
- checksum disagreement cannot trigger an unverified overwrite;
- unresolved pending state requires an explicit user decision;
- all UI operations leave progress state on failure or cancellation.

## 15. TDD and failure-injection coverage

### 15.1 Package allowlist

Tests create a new project and assert that only the canonical root files and directories exist. Any legacy history, WAL, backup, mutable autosave, proxy, thumbnail, recovery, or quarantine entry fails the test.

### 15.2 Pending save

Failure injection covers:

1. before pending write;
2. after pending fsync;
3. after project temporary write;
4. after project replacement but before manifest replacement;
5. after both replacements but before verification;
6. after verification but before pending deletion.

Opening the package after each injected failure must produce either the last complete snapshot or the complete candidate snapshot. It must never expose mixed project and manifest revisions.

### 15.3 Autosave

Tests verify immutable bytes, sequence and checksum filenames, duplicate suppression, eight-snapshot retention, corrupt candidate rejection, and absence of Undo, Redo, command IDs, and bookmark data.

### 15.4 Bookmark sidecars

Tests verify sidecar naming, canonical JSON exclusion, atomic replacement, stale refresh, missing-bookmark isolation, Relink behavior, and embedded-media independence.

### 15.5 Legacy import

Tests verify source-package byte or tree evidence is unchanged; contiguous WAL replay; truncated-final-record handling; sequence-gap stopping; history and mutable-autosave discard; stable ID preservation; bookmark extraction; embedded-media verification; temporary cleanup; deterministic canonical project bytes; and no recent-project registration on failure.

### 15.6 Session and startup

Tests verify empty Undo/Redo after reopen, 200-entry bounds, coalescing rules, save-failure session preservation, save/autosave race handling, splash completion across future phase numbers, and isolation of project, Metal, and bookmark failures from workspace entry.

### 15.7 Regression coverage

All Phase 6 schema, command, compiler, Metal pixel, adjustment-layer, blend-mode, nested-composition, preview, PNG, relink, and embedded-media tests remain active after adaptation to the canonical package.

## 16. CI and release gate

The corrected 6.0 release requires:

- Linux portable tests;
- macOS persistence failure-injection tests;
- macOS legacy import tests;
- Metal shader and pixel regression tests;
- composition compiler tests;
- iOS 17 arm64 Release compilation;
- app startup regression test;
- package allowlist inspection;
- static checks confirming the public `VertexProjectFoundation` product is absent;
- static checks confirming canonical JSON has no `bookmarkData`, `appliedCommandIDs`, or `legacyRenderSettings`;
- downloaded IPA inspection;
- artifact ZIP and IPA SHA-256 recording.

The workflow must fail if new code imports `VertexProjectFoundation`, uses `.aeproject` as a writable type, emits forbidden package entries, or serializes forbidden canonical fields.

## 17. Branch and artifact sequence

1. Correct the Phase 5 persistence implementation and PR #5 to expose `VertexProjectPersistence` and the canonical package contract.
2. Adapt and rebase or retarget Phase 6 onto the corrected Phase 5 state without weakening the existing layer and composition behavior.
3. Verify the corrected Phase 6 source and produce a replacement `After-Effects-6.0.0-unsigned.ipa`.
4. Record the corrected product HEAD, CI run, artifact ID, ZIP checksum, IPA checksum, bundle metadata, and package contract evidence.
5. Mark every earlier 6.0 IPA as `Superseded draft artifact — do not use as the Phase 7 base`.
6. Only after the correction gate passes, create `agent/phase-7-motion-engine` and begin a separate Phase 7 design, plan, and TDD implementation cycle.

## 18. Deliberate exclusions

This correction does not implement Phase 7 animation channels, keyframes, interpolation, parenting, or motion blur. It also does not add continuous playback, a full NLE timeline, retiming, advanced pre-composition, camera or light rendering, video export, masks, tracking, AI, shapes, text, professional color or audio, particles, node compositing, or 3D.

Those features remain governed by their roadmap phases. The only product artifact produced by this correction is the verified replacement 6.0.0 unsigned IPA.