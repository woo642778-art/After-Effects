# Versioning and Artifact Policy

## Phase-major versioning

Starting with Phase 3, the successful phase number is the product major version.

| Phase | Marketing version | Build number | IPA filename | Status |
|---:|---|---:|---|---|
| 2 | 2.0.0 policy baseline | 2 | historical Phase 2 filename | completed |
| 3 | 3.0.0 | 3 | `After-Effects-3.0.0-unsigned.ipa` | completed |
| 4 | 4.0.0 | 4 | `After-Effects-4.0.0-unsigned.ipa` | completed and verified |
| 5 | 5.0.0 | 5 | `After-Effects-5.0.0-unsigned.ipa` | completed and verified |
| 6 | 6.0.0 | 6 | `After-Effects-6.0.0-unsigned.ipa` | completed and verified |
| N | N.0.0 | N | `After-Effects-N.0.0-unsigned.ipa` | future successful phase |

A phase version is published only when its required tests, iOS Release compilation, identity checks, packaging, artifact upload, downloaded-IPA inspection, documentation, and handoff are complete. Partial milestones remain on the current phase version or use internal prerelease identifiers; they do not consume the next major number.

## Binary status

GitHub Actions produces unsigned arm64 IPA files. The repository does not contain an Apple distribution certificate, private key, or provisioning profile. Installation requires the repository owner to apply valid signing credentials using an appropriate signing workflow.

Renaming an archive or adding an invalid signature does not create an installable App Store build.

## Required artifact verification

Every phase record includes:

- final source and CI commit SHA;
- GitHub Actions run ID;
- artifact ID and archive digest;
- extracted IPA SHA-256;
- executable path and Mach-O architecture;
- display name, bundle name, bundle identifier;
- marketing version, build number, minimum OS;
- presence of compiled assets and required engine resources;
- precise list of features implemented and explicitly not implemented.

Documentation-only commits are excluded from the product-build trigger so final evidence can be recorded without generating a different ZIP timestamp and checksum.

## Verified Phase 6 artifact

- Product/artifact source HEAD: `852d6fde6157134e6ce46adb365c5f4474528215`
- CI trigger-policy closure HEAD: `f461b7854d1ee0c56e4d9376d6dc7503c5880e7d`
- Workflow run: `31081513272`
- Artifact ID: `8959725912`
- Artifact ZIP SHA-256: `739572b61e0cf61f6c06338845e5628634dd57a5d68177154cf029217236cc7d`
- Artifact ZIP size: 1,299,679 bytes
- IPA SHA-256: `b8b9ddb5a81549f1b6300f8e6a55dfce5ce32f19f2c457c753ec39e32a716117`
- IPA size: 1,312,056 bytes
- Executable: `Payload/AfterEffects.app/AfterEffects`, Mach-O 64-bit arm64, 4,883,640 bytes
- Display name: `After Effects`
- Bundle name: `AfterEffects`
- Bundle identifier: `com.woo642778.aftereffects`
- Version: `6.0.0 (6)`
- Minimum OS: iOS 17.0
- Compiled asset catalog: `Assets.car`, 152,879 bytes
- Compiled Metal resource: `Vertex_VertexRenderMetal.bundle/default.metallib`, 23,604 bytes

## Previous verified artifact

Phase 5 remains recorded in `Documentation/PHASE_5_COMPLETION.md` and retains its immutable product-source, workflow, and checksum evidence. Each phase-specific completion record remains authoritative for its own artifact.
