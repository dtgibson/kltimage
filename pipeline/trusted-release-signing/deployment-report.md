# Deployment Report — Trusted Release Signing

**Date:** 2026-09-12

**Result:** DEPLOYED AND VERIFIED

**Target:** Existing tailnet-only Tailscale Serve route

**URL:** `https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-preview/releases/KLT-Image-1.1.0-build-4.zip`

**SHA-256:** `4e884df54b06c393dbbb48c77bc96477b915dc4ba79cf26c6a29c7f59f672442`

**Size:** 1,582,664 bytes

## Authorization

The user explicitly confirmed the production deployment after the superseding QA report passed and the superseding security report approved the release with zero findings.

## Pre-Deploy Reconciliation

- The exact candidate at `/var/folders/qn/fzq2ymy1219bnchgrdvmcrdc0000gp/T/kltimage-release.MEV7ae/KLT-Image-1.1.0-build-4.zip` matched the expected SHA-256 and re-passed the independent release verifier.
- The Tester passed 67 configuration-specific test executions with no failures and verified the release acceptance criteria.
- The Auditor approved the remediated release with 0 Critical, 0 High, 0 Medium, and 0 Low findings.
- `main` matched `origin/main` before the scoped release commit, with no conflicts or remote-only changes.
- This project has no GitHub Actions workflow, staging environment, backend, or deployment secrets. Its CI/CD equivalent is the documented manual signed-release, notarization, and independent-verification process.

## Production Deployment and Health Check

- Build 4 was copied into `releases/` under its distinct versioned filename and atomically promoted from a temporary local name. Build 3 was not overwritten or removed.
- The existing Tailscale Serve route remained tailnet-only and unchanged: `/kltimage-preview` proxies to the local static server at `127.0.0.1:8786`.
- A fresh tailnet download returned HTTP 200, `application/zip`, content length 1,582,664 bytes, and the exact expected SHA-256.
- `scripts/verify-macos-release.sh` verified the downloaded ZIP's universal architectures, bundle versions and identifiers, strict nested and app signatures, Developer ID identity and Team ID, hardened runtime, secure timestamps, exact entitlements, and absence of `get-task-allow`.
- The downloaded app's notarization ticket passed `stapler validate`. A clean extracted copy retained an applied quarantine attribute and Gatekeeper accepted it with `source=Notarized Developer ID`.
- The quarantined app launched through App Translocation, remained running through the observation interval, and was then terminated normally after the smoke test.
- The core application action remains covered by the superseding QA run; this deployment changed only the distribution artifact and documentation.

## Rollback

Build 3 remains byte-identical at `releases/KLT-Image-1.1.0-build-3.zip` with SHA-256 `011ad363f46f9b9d81a6be3aeb936de1f692ed19fcc63e2ad0ba0207c353db7a`. It is no longer advertised because it is ad-hoc signed and rejected by Gatekeeper.

If Build 4 must be rolled back, remove only `releases/KLT-Image-1.1.0-build-4.zip` and restore the pre-deployment source-only guidance. Do not advertise Build 3 as trusted.

## Remaining Flags

- Broad public distribution remains unapproved because the previously accepted UI, accessibility, platform/runtime, cancellation, and dynamic-privacy evidence debt is unchanged.
- The established tailnet static server uses the repository root as its document root. Access remains tailnet-only and this deployment did not broaden or alter the route, but narrowing the local document root to release artifacts is a future hardening opportunity.
