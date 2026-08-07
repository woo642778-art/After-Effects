# Project Persistence Architecture

## Purpose

Phase 5 provides the first canonical, recoverable project system for After Effects. The writable format is `.vertexproject`; legacy `.aeproject` packages are read-only import sources and are never modified in place.

The application version is `5.0.0 (5)`. The Phase 5 project schema is version `1`; product and schema versions remain independent.

## Module boundaries

### VertexProject

`VertexProject` is portable Swift. It owns canonical product data, deterministic encoding, desired-state command requests, engine-derived forward/inverse transitions, and one in-memory editing session.

It includes:

- `ProjectDocument`, metadata, settings, media references, composition placeholders, and Render Lab values;
- sorted-key canonical JSON, normalized UTC timestamps, and SHA-256;
- `ProjectCommandRequest`, `ProjectMutation`, `ProjectTransition`, and `ProjectCommandEngine`;
- `ProjectEditingSession`, with session-only Undo/Redo and recent-command identity tracking;
- schema inspection and sequential migration contracts;
- fingerprint-based media relinking decisions.

It does not expose AVFoundation, Metal, UIKit, SwiftUI, security-scoped objects, bookmark bytes, file descriptors, absolute sandbox paths, or writable filesystem state.

### VertexProjectPersistence

`VertexProjectPersistence` owns filesystem behavior:

- the `.vertexproject` package allowlist;
- durable temporary writes, synchronized files, same-volume atomic rename, and directory synchronization;
- matching `project.json` and `manifest.json` verification;
- full `Journal/pending-save.json` save transactions and recovery classification;
- immutable full-document autosaves;
- bookmark sidecars and Apple bookmark adapters;
- verified embedded-media copy and resolution;
- internal legacy `.aeproject` DTOs, source-tree digesting, journal-prefix replay, inspection, and non-destructive conversion.

The former public `VertexProjectFoundation` product is not in the active package graph.

## Canonical package layout

```text
Project.vertexproject/
├── project.json
├── manifest.json
├── Journal/
│   └── pending-save.json        # present only while a save/recovery decision is pending
├── Autosaves/
│   └── <20-digit-sequence>-<project-sha256>.json
├── Bookmarks/
│   └── <lowercase-mediaID>.bookmark
└── Media/
    └── <mediaID>-<sanitized-original-name>
```

The steady-state root allowlist is exactly:

```text
project.json
manifest.json
Journal
Autosaves
Bookmarks
Media
```

Unknown root entries, legacy history/WAL/backup locations, mutable autosave names, proxy/thumbnail/recovery directories, and unrecognized temporary files are rejected.

## Canonical project data

Equal logical project states produce equal `project.json` bytes.

Rules:

- JSON keys and registries are stably ordered;
- UUIDs use lowercase canonical strings;
- dates use fixed UTC ISO-8601 encoding;
- exact time uses integer `RationalTime` values;
- NaN and infinity are rejected;
- paths are package-relative and may not escape the package;
- binary media and bookmark bytes never appear in project JSON;
- Undo, Redo, recent command IDs, inverse mutations, pending transactions, and autosave sequencing are not project data;
- each promoted project is decoded and canonically re-encoded before acceptance;
- the manifest checksum covers the exact canonical project bytes.

## Editing-session model

Callers submit desired values through `ProjectCommandRequest`. `ProjectCommandEngine.prepare` reads the current document and derives exact forward and inverse `ProjectMutation` values. Applying a transition validates project identity, base revision, inverse correctness, preconditions, and values, then increments revision exactly once.

`ProjectEditingSession` owns:

- the loaded snapshot and working document;
- saved revision and dirty state;
- at most 200 Undo entries and 200 Redo entries;
- at most 512 recent command IDs;
- compatible continuous-edit coalescing.

Opening or reopening a package creates a new session with empty Undo, Redo, and recent-ID state. Workspace selection may persist, but it does not enter edit history and does not clear Redo.

Deprecated operation-WAL compatibility types remain only to decode historical draft packages and fixtures. New application writes do not use them.

## Full-snapshot save protocol

A save creates one complete candidate pair, never an operation WAL:

1. Validate and canonically encode the next project.
2. Build the matching manifest and independently checksum both exact byte payloads.
3. Encode the complete pair into `Journal/pending-save.json`.
4. Write and synchronize the pending temporary file, atomically promote it, and synchronize `Journal/`.
5. Write and synchronize project and manifest temporary files.
6. Atomically promote `project.json`, then `manifest.json`, synchronizing the package directory at each required boundary.
7. Reopen and verify identity, revision, schema, and checksums.
8. Remove the pending envelope and synchronize `Journal/`.

Failure-injection tests cover every required boundary. Reopening may expose only the last verified pair or the complete candidate pair, never mixed project/manifest state. Newer proven candidates can complete automatically; uncertain, corrupt, older, or divergent candidates require an explicit decision.

## Immutable autosaves

Autosaves are complete canonical project snapshots named by a monotonically increasing 20-digit sequence and project checksum. Existing autosave bytes are never overwritten. Duplicate revision/checksum snapshots are suppressed, corrupt or malformed entries are isolated, sequence exhaustion fails safely, and only the eight newest valid unique snapshots are retained.

Autosaves contain no Undo/Redo history, command/inverse records, recent IDs, or bookmark bytes.

## Media references

Canonical `MediaLocator` contains only a portable relative hint and optional embedded path.

External security bookmarks are stored separately at `Bookmarks/<lowercase-mediaID>.bookmark`. A missing, corrupt, or stale bookmark affects only that media reference and cannot corrupt the verified project pair.

Embedding writes to a temporary file under `Media/`, verifies the expected fingerprint before and after copying, uses a deterministic sanitized name, rejects byte-mismatched collisions, and promotes only verified content.

## Legacy import

`.aeproject` support is import-only:

- the source tree is digested before and after conversion and must remain byte-identical;
- IDs and canonical source timestamps are preserved;
- only the valid contiguous legacy journal prefix after the committed sequence is replayed;
- persisted Undo/Redo, backup files, and mutable autosaves are discarded;
- bookmark extraction failures are isolated per media item;
- embedded media is fingerprint-verified;
- conversion writes a separate `.vertexproject` destination through a temporary staging package;
- failed conversion removes the staging destination.

## Application vertical slice

The app routes project operations through serial `ProjectSessionActor` ownership. It provides project create/open/save/export, explicit pending-save decisions, legacy inspection and conversion, session Undo/Redo, immutable autosave, missing-media detection, relinking, bookmark sidecars, and verified embedding. Backgrounding requests an autosave without making startup dependent on recovery, Metal, or release-phase work.

The Phase 4 Metal render graph remains the shared preview and PNG-output path.

## Deliberate exclusions

Phase 5 does not claim layers/compositions, continuous playback, timeline editing, video export, motion keyframes, retiming, masks, tracking, AI cutout, shape or text animation, professional color/audio, particles, node compositing, or 3D.
