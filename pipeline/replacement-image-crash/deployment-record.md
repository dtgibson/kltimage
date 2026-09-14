# Deployment Record — KLT Image 1.3.1 Spool release

**Date:** 2026-09-14

**Result:** DEPLOYED AND VERIFIED

**Version:** KLT Image 1.3.1 build 7

**SHA-256:** `620044cc2191ee15c229d0abbdb0839eae703852081b1a179782e7942f10a0a1`

**Size:** 3,761,891 bytes

## Production channel

- GitHub release: `https://github.com/dtgibson/kltimage/releases/tag/v1.3.1`
- Release ZIP: `https://github.com/dtgibson/kltimage/releases/download/v1.3.1/KLT-Image-1.3.1-build-7.zip`
- Checksum: `https://github.com/dtgibson/kltimage/releases/download/v1.3.1/KLT-Image-1.3.1-build-7.zip.sha256`
- Published: `2026-09-14T16:19:21Z`
- Tag: `v1.3.1`
- Release commit: `0f49414a3dfd75f91df38ef04ba1c62347e7d44e`

## Authorization and channel decision

The user explicitly approved shipping the production release, then explicitly decided that GitHub is the final and canonical release step. The prior Tailscale mirror is no longer a required production channel for this or future current releases. This narrows the deployment target; it is not a rollback.

An initial two-channel health check found the local Tailscale proxy backend unavailable. No Build 7 tailnet verification claim was made. After the user's channel decision, the existing Tailscale route and historical mirrored artifacts were left unchanged, and Build 7 was neither advertised nor accepted as a tailnet release.

## Pre-deploy reconciliation

- `origin/main` was fetched before release preparation and again immediately before publication. It remained at the bundle's base, `4ca6b8661359f7388ec023e45cb5492f4ff9991f`, with no remote-only movement or integration conflict.
- The Spool bundle landed on `main` as `9268314bb25029def5aac4b4beccd2d761a1f471`.
- Audited release preparation was committed as `0f49414a3dfd75f91df38ef04ba1c62347e7d44e`, and annotated tag `v1.3.1` resolves to that commit.
- The project intentionally has no staging environment or GitHub Actions workflow. Deployment is the documented manual signed build, Apple notarization, GitHub publication, and independent fresh-download verification process.

## Acceptance basis

- The complete Debug suite passed 96/96 tests with 0 failures and 0 skips.
- The complete optimized `ReleaseTests` suite passed 98/98 tests with 0 failures and 0 skips, including the 24-megapixel performance checks.
- The comparison-slider fix passed its focused regression criteria and security review.
- The replacement-image fix passed its focused replacement, cancellation, corrupt-input, overlap, stale-callback, export-ordering, and safe-render regression criteria and security review.
- Both feature security reviews reported 0 Critical, 0 High, 0 Medium, 0 Low, and 0 Informational findings.

## Candidate verification

- The release resolved to version 1.3.1 build 7 with universal `arm64` and `x86_64` app and framework executables, hardened runtime enabled, and testability disabled.
- `KLTCore.framework` and `KLT Image.app` passed strict Developer ID signature verification for Team ID `8QKC3L2FKP`, with secure timestamps and the hardened-runtime flag.
- The app carried exactly the App Sandbox and user-selected read/write file entitlements. `get-task-allow` was absent, and the framework carried no entitlements.
- Apple accepted notarization submission `ba15760f-2058-457b-a21f-5f3fc748bfbf`; stapling and ticket validation passed.
- The release script independently extracted the final ZIP, applied quarantine without removing it, and received Gatekeeper acceptance with `source=Notarized Developer ID` before promoting the candidate from pending names.
- A separate verifier rerun accepted the final candidate with the same checksum.

## GitHub production verification

- The public release is neither draft nor prerelease. Its ZIP asset reports size 3,761,891 bytes and digest `sha256:620044cc2191ee15c229d0abbdb0839eae703852081b1a179782e7942f10a0a1`.
- A fresh GitHub download matched the approved candidate and the retained local archive byte-for-byte.
- The fresh download independently passed the repository verifier for exact checksum, bundle identity, Team ID, version/build, universal architectures, strict signatures, hardened runtime, exact entitlements, notarization ticket, retained quarantine, and Gatekeeper acceptance.
- The GitHub release page, ZIP asset, and checksum asset responded successfully.

## Rollback

Trusted KLT Image 1.3.0 build 6 is the rollback target. Its retained local artifact is `releases/KLT-Image-1.3.0-build-6.zip`, with SHA-256 `dbac952c70e1d05f38ec10af099577c4e082f089653eb6d37c33e05c4299c4f3`.

Rollback is a separate destructive action and was not performed or authorized. The existing Tailscale route and historical mirrored artifacts remain outside the current GitHub-only release flow.
