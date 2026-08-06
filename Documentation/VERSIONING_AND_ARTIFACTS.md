# Versioning and Artifact Policy

## Phase-major versioning

Starting with Phase 3, the successful phase number is the product major version.

| Phase | Marketing version | Build number | IPA filename |
|---:|---|---:|---|
| 2 | 2.0.0 policy baseline | 2 | historical Phase 2 filename |
| 3 | 3.0.0 | 3 | `After-Effects-3.0.0-unsigned.ipa` |
| 4 | 4.0.0 | 4 | `After-Effects-4.0.0-unsigned.ipa` |
| N | N.0.0 | N | `After-Effects-N.0.0-unsigned.ipa` |

A phase version is published only when its required tests, iOS Release compilation, identity checks, packaging, artifact upload, downloaded-IPA inspection, documentation, and handoff are complete. Partial milestones remain on the current phase version or use internal prerelease identifiers; they do not consume the next major number.

## Binary status

GitHub Actions produces unsigned arm64 IPA files. The repository does not contain an Apple distribution certificate, private key, or provisioning profile. Installation requires the repository owner to apply valid signing credentials using an appropriate signing workflow.

Changing `cryptid`, adding an ad hoc signature, or renaming an archive does not create a valid installable App Store build.

## Required artifact verification

Every phase record must include:

- final source and CI commit SHA;
- GitHub Actions run ID;
- artifact ID and archive digest;
- extracted IPA SHA-256;
- executable path and Mach-O architecture;
- display name, bundle name, bundle identifier;
- marketing version, build number, minimum OS;
- presence of compiled assets;
- precise list of features implemented and explicitly not implemented.

Documentation-only commits are excluded from the product-build trigger so the final artifact evidence can be recorded without generating a different ZIP timestamp and checksum.
