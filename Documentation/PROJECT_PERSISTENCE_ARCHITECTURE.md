# Project Persistence Architecture

## Purpose

Phase 5 introduces the first recoverable project system for After Effects. It persists project identity, media references, Render Lab settings, command history, journal state, autosaves, manifests, and recovery information without serializing Apple media objects, Metal objects, SwiftUI state, file descriptors, or absolute sandbox paths.

The application version is `5.0.0 (5)`. The initial project schema is version `1`; application and project schema versions are intentionally independent.

## Module boundaries

### VertexProject

`VertexProject` is portable Swift and depends only on Vertex-owned portable modules.

It owns:

- `ProjectDocument`, metadata, settings, media registry, composition identity placeholders, and Render Lab values;
- `ProjectManifest` and integrity state;
- deterministic sorted-key JSON and SHA-256;
- normalized UTC timestamps;
- commands, inverse operations, revision checks, duplicate-command protection, Undo, Redo, and command coalescing;
- checksummed newline-delimited journal records and deterministic replay;
- schema inspection and sequential migration contracts;
- strong media-relink decisions based on content fingerprints;
- stable `ProjectError` values.

No `AVAsset`, `CMTime`, `MTLTexture`, `UIImage`, SwiftUI view state, security-scoped URL object, or backend-specific value is exposed by this module.

### VertexProjectFoundation

`VertexProjectFoundation` owns platform and file-system behavior:

- package layout and path-containment checks;
- durable temporary writes and same-volume atomic rename;
- backup creation, manifest verification, history storage, and journal append;
- autosave rotation;
- recovery candidate inspection and non-destructive recovered-copy creation;
- security bookmark creation and resolution at the adapter boundary;
- media fingerprinting, verified embedding, and embedded-media resolution.

Platform errors are mapped into `ProjectError` rather than persisted directly.

## Project package layout

```text
Project.aeproject/
├── project.json
├── project.json.backup
├── manifest.json
├── history.json
├── journal/
│   └── operations.log
├── autosaves/
│   ├── snapshot-current.json
│   ├── snapshot-previous.json
│   ├── snapshot-hourly-*.json
│   └── snapshot-hourly-*.json
├── media/
├── proxies/
├── thumbnails/
└── recovery/
    └── quarantine/
```

`proxies/` and `thumbnails/` are reserved package locations. Phase 5 does not claim proxy generation or thumbnail-cache management.

## Deterministic project data

Equal logical project states produce equal `project.json` bytes.

Rules:

- JSON keys are sorted;
- media, composition, and command-identity collections are stably ordered;
- UUIDs use lowercase canonical strings;
- dates use UTC ISO-8601 with fixed fractional-second precision;
- exact time continues to use integer `RationalTime` values;
- NaN and infinity are rejected;
- paths are package-relative and may not escape the package root;
- binary media never appears inside JSON;
- every project write is decoded and canonically re-encoded before promotion;
- the manifest stores the SHA-256 of the exact project bytes.

## Command and history model

Every durable edit is represented by a `ProjectCommandRecord` containing:

- stable command and project IDs;
- expected base revision;
- normalized timestamp;
- optional merge key;
- forward operation;
- validated inverse operation.

The command engine rejects stale revisions, duplicate command IDs, mismatched project identities, invalid inverses, invalid preconditions, non-finite values, and invalid output dimensions.

Successful application increments the project revision exactly once. Undo and Redo are also durable state transitions. Rapid compatible Render Lab changes may coalesce into one Undo item while the journal preserves the actual durable command sequence.

## Write-ahead journal

The application validates a command, creates a checksummed journal record, appends and synchronizes that record, and only then mutates project and history state.

Undo and Redo use a preparation callback so journal append failure leaves the project and both history stacks unchanged.

Each line contains an independent checksum and contiguous sequence number. Replay:

- ignores already-applied command IDs;
- rejects sequence gaps;
- rejects checksum failures and incompatible operations;
- accepts valid complete lines before a truncated final line;
- begins after the manifest's committed journal sequence.

## Atomic save protocol

1. Validate and canonically encode the project.
2. Decode and re-encode to prove canonical-byte stability.
3. Write and synchronize `project.json.tmp` in the package volume.
4. Encode and synchronize temporary history and manifest files.
5. Preserve the previous `project.json` as `project.json.backup`.
6. Atomically rename the temporary project, history, and manifest files into place.
7. Load the package and verify project checksum, identity, revision, and schema.

A failure after the temporary project write leaves the previous current project intact. A project/manifest disagreement is rejected during load and exposed to recovery.

## Autosave and recovery

Autosave maintains:

- current snapshot;
- previous snapshot;
- two most recent hourly snapshots.

The application schedules an autosave two seconds after the latest edit, after twenty uncommitted commands, and when the app enters the background.

Recovery inspects current project, backup, current and previous autosaves, and hourly autosaves. Valid candidates are ranked by revision and source priority. A damaged package is copied before recovery writes occur, and the recovered project is created as a separate package with a new revision.

A backup project is not paired with a newer `history.json`; backup recovery starts with empty history unless a revision-matched backup history is introduced in a later schema.

## Media references

External media is the default. A `MediaReference` stores portable identity evidence, file metadata, an opaque bookmark payload, an optional package-relative embedded path, media kind, and availability state.

Automatic relinking requires a unique matching content fingerprint. Filename matches alone remain manual candidates. Embedding copies media into `media/`, sanitizes and deterministically disambiguates the filename with the media ID, and verifies the content fingerprint after copying.

## Application vertical slice

The Phase 5 workspace provides real behavior for:

- project creation and rename;
- project package open, atomic save, and package export;
- revision and schema presentation;
- persistent media registration;
- persistent Render Lab parameters and output dimensions;
- Undo and Redo backed by the command engine and journal;
- autosave status;
- missing-media detection and fingerprint-verified relinking;
- optional media embedding;
- explicit recovery candidate selection.

The Phase 4 Metal render graph remains the only preview and PNG-output path.

## Deliberate exclusions

Phase 5 does not implement or claim timeline editing, layer composition, continuous playback, video export, general effects, motion animation, retiming, masks, tracking, AI cutout, shape or text animation, professional color or audio processing, particles, node compositing, or 3D.