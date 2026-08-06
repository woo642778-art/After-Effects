# Versioning and Artifact Policy

## Phase-major versioning

Starting with Phase 3, the successful phase number is the product major version.

| Phase | Marketing version | Build number | IPA filename | Status |
|---:|---|---:|---|---|
| 2 | 2.0.0 policy baseline | 2 | historical Phase 2 filename | completed |
| 3 | 3.0.0 | 3 | `After-Effects-3.0.0-unsigned.ipa` | completed |
| 4 | 4.0.0 | 4 | `After-Effects-4.0.0-unsigned.ipa` | completed and verified |
| 5 | 5.0.0 | 5 | `After-Effects-5.0.0-unsigned.ipa` | completed and verified |
| 6 | 6.0.0 | 6 | `After-Effects-6.0.0-unsigned.ipa` | reserved for completed Phase 6 only |
| N | N.0.0 | N | `After-Effects-N.0.0-unsigned.ipa` | future successful phase |

A phase version is published only when its required tests, iOS Release compilation, identity checks, packaging, artifact upload, downloaded-IPA inspection, documentation, and handoff are complete. Partial milestones remain on the current phase version or use internal prerelease identifiers; they do not consume the next major number.

## Binary status

GitHub Actions produces unsigned arm64 IPA files. The repository does not contain an Apple distribution certificate, private key, or provisioning profile. Installation requires the repository owner to apply valid signing credentials using an appropriate signing workflow.

Renaming an archive or adding an invalid signature does not create an installable App Store build.

## Required artifact verification

Every phase record must include:

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

## Verified Phase 5 artifact

- Product and CI source HEAD: `e68ffde2eebcdb58becc9d3d1ecaf195f1861e76`
- Workflow run: `31069517329`
- Artifact ID: `8955148634`
- Artifact API digest: `sha256:f43efd3c17e018f17781f5e92cda888de6a223061e4703c136f7492659da1ea8`
- IPA SHA-256: `395e67c262fa24cb7f9b75f459ced1bf4673d6edbdc24d622d1456342f18d366`
- Executable: `Payload/AfterEffects.app/AfterEffects`, Mach-O 64-bit arm64
- Display name: `After Effects`
- Bundle identifier: `com.woo642778.aftereffects`
- Version: `5.0.0 (5)`
- Minimum OS: iOS 17.0
- Compiled asset catalog: `Assets.car`
- Compiled Metal resource: `Vertex_VertexRenderMetal.bundle/default.metallib`, 6,996 bytes

## Previous verified artifact

Phase 4 remains recorded in `Documentation/PHASE_4_COMPLETION.md`. Phase-specific completion records are immutable evidence for their corresponding product source and workflow run.