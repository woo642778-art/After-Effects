# Versioning and Artifact Policy

## Phase-major versioning

Starting with Phase 3, the successful phase number is the product major version.

| Phase | Marketing version | Build number | IPA filename | Status |
|---:|---|---:|---|---|
| 2 | 2.0.0 policy baseline | 2 | historical Phase 2 filename | completed |
| 3 | 3.0.0 | 3 | `After-Effects-3.0.0-unsigned.ipa` | completed |
| 4 | 4.0.0 | 4 | `After-Effects-4.0.0-unsigned.ipa` | completed and verified |
| 5 | 5.0.0 | 5 | `After-Effects-5.0.0-unsigned.ipa` | reserved for completed Phase 5 only |
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

## Verified Phase 4 artifact

- Product and CI HEAD: `2bcc43869cb495feef0297dad3eed59d8548efa7`
- Workflow run: `31060781516`
- Artifact ID: `8952047400`
- Artifact archive SHA-256: `ce8f6fe16ca4bfe3f07b2ddd4d5b9fb0c6322dac1605a025f7657b8c53ef78a8`
- IPA SHA-256: `fb4aac8c8370dc90f3b347cb7fbb2548d05808d1d2a5a091b868a41a420be331`
- Executable: `Payload/AfterEffects.app/AfterEffects`, Mach-O 64-bit arm64
- Version: `4.0.0 (4)`
- Minimum OS: iOS 17.0
- Compiled Metal resource: `Vertex_VertexRenderMetal.bundle/default.metallib`
