# Phase 5 Project Persistence Design

## Goal

Build the first recoverable project system for After Effects 5.0.0. A project must survive normal saves, interrupted writes, application termination, missing external media, schema evolution, and reversible user edits without serializing Apple framework, GPU, UI, or sandbox-specific runtime objects.

## Product boundary

Phase 5 implements project persistence, command history, recovery, migration, and media relinking. It does not implement a timeline, layer compositor, continuous playback, video export, general effects, motion, tracking, AI cutout, shape or text animation, professional color or audio tools, particles, nodes, or 3D.

## Storage approach

Phase 5 uses a hybrid media policy:

- external media references are the default;
- projects store portable identity, fingerprint, bookmark, and relinking metadata rather than platform objects or raw absolute sandbox paths;
- users may copy selected media into the project package for a self-contained project;
- embedded media remains usable when the original external file is unavailable.

This balances package size, portability, and recoverability.

## Project package layout

Projects are directory packages with the `.aeproject` extension.

```text
MyProject.aeproject/
├── project.json
├── project.json.backup
├── manifest.json
├── journal/
│   └── operations.log
├── autosaves/
│   ├── snapshot-current.json
│   ├── snapshot-previous.json
│   ├── snapshot-hourly-01.json
│   └── snapshot-hourly-02.json
├── media/
├── proxies/
├── thumbnails/
└── recovery/
    └── quarantine/
```

Phase 5 may leave `proxies/` and `thumbnails/` empty. They are reserved package locations, not claims of proxy or cache implementation.

## Module architecture

### VertexProject

A platform-neutral Swift module owns:

- project schema and manifest values;
- portable media references;
- render-lab settings persisted as project data;
- deterministic JSON encoding and decoding;
- command application, inverse operations, merge semantics, undo, and redo;
- journal records and checksums;
- migration interfaces and reports;
- validation and structured project errors.

`VertexProject` may depend on `VertexCore`, `VertexMedia`, and `VertexRender`. It may not expose `AVAsset`, `CMTime`, `MTLTexture`, `UIImage`, SwiftUI state, security-scoped URL objects, or backend-specific types.

### VertexProjectFoundation

An Apple-platform adapter owns:

- file-system package creation and inspection;
- atomic replacement and backup handling;
- write-ahead journal persistence and durable flushes;
- autosave snapshot rotation;
- interrupted-write and corruption recovery;
- security-scoped bookmark creation and resolution;
- media embedding, availability checks, and relinking;
- quarantine and recovery-copy creation.

The adapter maps file-system failures to portable `ProjectError` values.

### Application integration

The app provides one Phase 5 vertical slice:

- create a named project;
- capture the current selected media and Render Lab settings;
- save a project package through the system file exporter;
- reopen a package through the system file importer;
- display revision, last saved time, autosave or recovery state, and media availability;
- change supported render settings through command-based edits;
- undo and redo those edits;
- embed the selected media when the original source is accessible;
- relink a missing external media reference;
- present explicit recovery choices when more than one valid recovery candidate exists.

The existing Phase 4 render graph remains the only render path.

## Schema model

### ProjectDocument

The initial schema contains:

- `schemaVersion`;
- `minimumReaderVersion`;
- `projectID`;
- `revision`;
- project metadata and settings;
- media registry;
- composition registry placeholder with no layer implementation;
- optional active composition identifier;
- current selected media identifier;
- persisted Render Lab settings;
- applied command identifiers needed for idempotence;
- bounded undo and redo history metadata.

The composition registry placeholder exists only to reserve stable identity for later phases. Phase 5 does not claim layer or composition rendering.

### ProjectManifest

The manifest stores:

- schema and reader versions;
- project identifier;
- creation and last-save application versions;
- project revision;
- project JSON SHA-256;
- last committed journal sequence;
- last successful save timestamp;
- package integrity status.

Application marketing version and project schema version are independent. Phase 5 uses application version `5.0.0 (5)` and project schema version `1`.

## Deterministic serialization

Equal logical project states must produce equal `project.json` bytes.

Rules:

- sorted JSON keys;
- stable sorting for registries and sets;
- lowercase canonical UUID strings;
- UTC ISO-8601 timestamps with fixed fractional-second precision;
- `RationalTime` encoded as integer value and timescale;
- explicit color metadata;
- rejection of NaN and infinity;
- exclusion of temporary URLs, device paths, file descriptors, UI selection state that is not project state, and backend objects;
- pre-encoding validation;
- post-write decode and checksum verification.

Binary media is never embedded inside JSON.

## Portable media references

Each `MediaReference` stores:

- stable media ID;
- display and original file names;
- file size;
- modification timestamp when available;
- content fingerprint;
- relative location hint;
- opaque bookmark data through the adapter boundary;
- optional package-relative embedded path;
- declared media kind;
- availability status.

Automatic relinking order:

1. embedded package media;
2. valid security-scoped bookmark;
3. project-neighbor relative hint;
4. filename, size, and modification-date candidates;
5. content fingerprint verification;
6. manual user selection.

A filename match alone is never accepted as a strong automatic relink.

## Commands and undo/redo

`ProjectCommandRecord` includes:

- command ID;
- project ID;
- base revision;
- timestamp;
- optional merge key;
- forward operation;
- inverse operation.

Initial command operations:

- create or rename project;
- register or remove media;
- relink media;
- mark or complete media embedding;
- select active media;
- set render parameter;
- set output dimensions;
- set project color metadata;
- restore a validated snapshot.

Application rules:

- base revision must equal the current revision;
- duplicate command IDs are rejected;
- successful application increments revision exactly once;
- every reversible operation supplies a validated inverse;
- a new normal command clears redo history;
- undo and redo are themselves journaled state transitions;
- histories are bounded to the most recent 200 entries;
- binary payloads are referenced, not copied into command records.

### Command coalescing

Rapid changes such as slider drags may merge when all conditions hold:

- identical merge key;
- same target object and parameter;
- no intervening different command;
- within the configured coalescing interval.

Intermediate previews may render normally, while one completed gesture becomes one undo item and one durable project change.

## Write-ahead journal

Every durable edit is recorded before its resulting project state is committed.

A journal line contains:

- contiguous sequence number;
- command and project IDs;
- base revision;
- normalized timestamp;
- command payload;
- line checksum.

Rules:

- journal records are newline-delimited deterministic JSON;
- a record is flushed before applying it to the durable snapshot;
- sequence gaps, invalid checksums, unknown operation types, or revision mismatches stop automatic replay;
- a truncated or corrupt final line is discarded only when all prior lines are valid;
- already applied command IDs are not replayed;
- incompatible but intact records are preserved for user-visible recovery instead of silently skipped.

## Atomic save protocol

`project.json` is never overwritten in place.

1. Validate the in-memory project.
2. Encode deterministic bytes.
3. Write `project.json.tmp` in the same package volume.
4. Flush the temporary file.
5. Decode the temporary file and verify its SHA-256.
6. Preserve the previous valid project as `project.json.backup`.
7. Atomically replace `project.json` with the temporary file.
8. Write and atomically replace `manifest.json` with the new revision and checksum.
9. Mark the committed journal sequence.
10. Compact only fully committed journal history.

A failure before step 7 leaves the previous project intact. A failure between project and manifest replacement is detected and recovered through checksum and revision comparison.

## Autosave policy

Autosave triggers when any of these conditions occurs:

- two seconds have elapsed after the last committed user change;
- twenty uncommitted commands have accumulated;
- the application enters the background;
- an explicit save is requested;
- the application receives a memory warning and a valid snapshot can be produced.

Snapshot rotation keeps:

- current autosave;
- previous autosave;
- two most recent hourly recovery snapshots;
- one valid manual-save backup.

Invalid candidates move to `recovery/quarantine/`; they are not silently deleted during recovery.

## Recovery algorithm

Opening a package performs:

1. package and manifest validation;
2. current project checksum and schema validation;
3. candidate discovery for current project, backup, autosaves, and journal replay;
4. deterministic ranking by validity, revision, and committed sequence;
5. automatic recovery only when one unambiguous best candidate exists;
6. creation of a recovery copy before modifying a damaged package;
7. explicit user selection when multiple candidates are plausible;
8. assignment of a new revision and recovery report after successful recovery.

Fallback priority is:

```text
project.json
→ project.json.backup
→ snapshot-current.json
→ snapshot-previous.json
→ latest valid snapshot plus journal replay
```

The damaged original package is preserved. Recovery never reports success before the recovered document is encoded, decoded, checksummed, and atomically saved.

## Migration and compatibility

Migrations run sequentially without skipping versions.

```text
1 → 2 → 3 → current
```

Each migrator:

- validates its declared input schema;
- treats input bytes as immutable;
- returns a new document and migration report;
- is deterministic and idempotent for its accepted input;
- validates and re-encodes the result;
- preserves the original package if migration fails.

A project with a schema newer than the current reader supports is not rewritten. The app displays its schema, minimum reader version, and last-save application version when those fields can be read safely.

Unknown command types are compatibility errors, not no-op commands. Unknown future fields are not discarded by opening and resaving a project.

## Error model

`ProjectError` distinguishes:

- invalid schema or unsupported future schema;
- invalid project identity or revision;
- duplicate command;
- stale base revision;
- invalid inverse operation;
- deterministic encoding failure;
- package or manifest corruption;
- checksum mismatch;
- journal gap, corruption, or incompatibility;
- atomic replacement failure;
- autosave rotation failure;
- migration failure;
- missing media;
- bookmark failure;
- relink mismatch;
- embedding failure;
- cancelled user operation.

Errors expose stable codes and readable messages without embedding platform error objects in project models.

## Security and privacy boundaries

- security-scoped bookmark bytes are opaque project data and are never logged;
- external file paths are not emitted to analytics or public diagnostics;
- relinking verifies file identity before changing a media reference;
- package-relative paths are normalized and may not escape the package root;
- untrusted project JSON cannot cause arbitrary path writes;
- embedded filenames are sanitized and collisions are resolved deterministically.

## Testing strategy

### Portable tests

- equal states serialize to identical bytes and checksums;
- collection insertion order does not affect output;
- invalid floating-point values are rejected;
- command application increments revision once;
- invalid base revisions and duplicate IDs are rejected;
- forward, undo, and redo produce expected states;
- new commands clear redo history;
- slider commands coalesce into one undo item;
- journal lines are deterministic and independently checksummed;
- valid replay is idempotent;
- a corrupt final line is excluded while earlier lines survive;
- sequence gaps and unknown commands stop replay;
- schema migration is deterministic;
- future schemas are rejected without mutation;
- media relink candidates require strong identity evidence.

### Foundation and package tests

- interrupted temporary-file writes preserve the previous project;
- atomic replacement produces a matching manifest and project checksum;
- manifest/project disagreement is detected;
- a corrupt current project recovers from backup;
- autosave rotation obeys retention limits;
- recovery preserves the damaged source package;
- embedded media opens without the external original;
- path traversal attempts are rejected;
- security bookmark resolution failures map to structured errors.

### Application and CI tests

- app creates, saves, imports, and reopens a Phase 5 project package;
- revision and saved-state indicators update correctly;
- Undo and Redo control real persisted Render Lab parameters;
- missing media and relink flows are visible and non-destructive;
- iOS 17 arm64 Release build succeeds;
- app identity is `After Effects` version `5.0.0 (5)`;
- unsigned artifact is named `After-Effects-5.0.0-unsigned.ipa`;
- downloaded IPA contains the expected executable, asset catalog, and Metal library.

## Completion gate

Phase 5 is complete only when:

- the design and implementation plan are committed;
- portable project tests pass;
- file-system recovery and corruption fixtures pass on Apple CI;
- a real project package can be created, saved, reopened, and recovered through the app vertical slice;
- Undo/Redo changes persisted Render Lab state rather than decorative UI state;
- external and embedded media behaviors are verified;
- migration and future-schema policies are tested;
- the iOS 17 Release build passes;
- the downloaded unsigned IPA is inspected as arm64 with version `5.0.0 (5)`;
- final source SHA, workflow run, artifact ID, archive digest, IPA SHA-256, work log, completion record, and handoff are stored.

## Explicit non-claims

Phase 5 does not claim timeline editing, layers, compositions with rendered contents, continuous playback, video export, general effect stacks, animation channels, masks, tracking, AI segmentation, vector shapes, text motion, color grading, audio processing, particles, node compositing, or 3D.