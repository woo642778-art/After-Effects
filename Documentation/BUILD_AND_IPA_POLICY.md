# Build and IPA Policy

## Artifact levels

| Level | Output | Installation status |
|---|---|---|
| Source validation | Swift tests and Xcode build logs | Not installable |
| Unsigned milestone IPA | `Payload/Vertex.app` packaged as `.ipa` | Not installable on stock iOS without signing |
| Development-signed IPA | Signed with an Apple Development identity and provisioning profile | Installable on registered devices |
| Ad Hoc IPA | Signed with an Ad Hoc distribution profile | Installable on listed devices |
| App Store/TestFlight archive | Distribution-signed archive uploaded through Apple tooling | Distributed through Apple services |

## Per-phase rule

Every phase that contains a buildable app must publish:

- an unsigned IPA;
- a SHA-256 checksum;
- the source commit SHA;
- build and test logs;
- a documented list of implemented and excluded behavior.

If a phase is research-only and has no executable product delta, the previous validated IPA remains the latest artifact and the work log must state why no new binary was produced.

## Current workflow

`.github/workflows/phase-build.yml` runs deterministic core tests on Linux, generates the Xcode project on macOS, builds the iOS app with code signing disabled, packages the app into `Vertex-Phase-1-unsigned.ipa`, and uploads the IPA plus checksum as workflow artifacts.

## Signing boundary

The repository must never contain private keys, `.p12` files, provisioning profiles, passwords, or encoded signing secrets. Signed builds require repository-owner-managed GitHub secrets or local Apple signing configuration.
