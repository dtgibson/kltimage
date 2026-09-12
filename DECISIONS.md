# KLT Image Decisions

## Ship the narrow RGB covariance foundation first — 2026-09-10

**Decision:** The first shipped build uses deterministic whole-image RGB covariance only. Lab processing, correlation mode, and selectable-region sampling remain the next product step, even though the founding brief describes the broader destination.

**Rationale:** A single mathematically testable path establishes whether decorrelation stretch is visually useful for bird-feather imagery before additional choices complicate interpretation. Whole-image sampling also provides a clear baseline for later region-based comparisons.

**Implications:** Future analysis controls must preserve the existing transform as a reproducible baseline. New modes should identify their color space, matrix basis, and sampling region explicitly, and quantitative export should record those settings.

## Keep results exploratory and local — 2026-09-10

**Decision:** KLT Image keeps image data on the Mac, retains no project history, and presents enhanced colors as exploratory visual evidence rather than biological measurement or proof.

**Rationale:** The technique amplifies variance, including compression artifacts and sensor noise, so the unchanged source and clear method disclosure are essential to responsible interpretation.

**Implications:** New features must preserve side-by-side context, avoid unsupported scientific claims, and require explicit user action for every exported artifact.

## Keep full-frame processing within a fixed 64 MP boundary — 2026-09-11

**Decision:** KLT Image supports full-frame processing up to 64,000,000 pixels with deterministic pre-decode and pre-allocation validation; the limit does not expand from volatile free-memory readings.

**Rationale:** A fixed ceiling gives users repeatable behavior and bounds the multi-buffer working set on the lowest-memory supported Mac class while covering common high-resolution cameras.

**Implications:** Images above 64 megapixels require a separately designed tiled or out-of-core processing path rather than a larger opportunistic allocation.

## Keep the current release private and local — 2026-09-11

**Decision:** The current ad-hoc-signed, unnotarized package is approved only for private/local distribution over the project's tailnet; broad public distribution is not approved.

**Status:** Superseded on 2026-09-12 by the trusted-signing requirement and verified Build 4 private-tailnet deployment below.

**Rationale:** Core verification and security review found no open product defect, but 22 QA criteria retain evidence gaps across UI automation, VoiceOver, platform/runtime coverage, cancellation workflows, and dynamic privacy checks.

**Implications:** Public distribution requires closing the accepted evidence debt and producing a Developer ID-signed, notarized artifact without development entitlements, followed by verification of the exact package.

## Require trusted signing for every downloadable build — 2026-09-12

**Decision:** Every newly published macOS package, including a private tailnet release, must be Developer ID-signed, Apple-notarized, stapled, and accepted by Gatekeeper when quarantined. Ad-hoc signing is limited to local development and is not a release path.

**Rationale:** Download quarantine and Gatekeeper apply independently of audience size. Build 3's valid ad-hoc seal protected integrity but could not authenticate the publisher or carry a notarization ticket, causing the normal “move to Trash” rejection.

**Implications:** Release automation must fail on signing identity, team, timestamp, hardened-runtime, entitlement, architecture, version, notarization, ticket, checksum, or Gatekeeper mismatches. Packaging happens only after stapling, and quarantine removal is never an acceptance workaround. This trust decision does not remove the existing QA evidence debt or approve broad public distribution.

## Publish verified Build 4 on the private tailnet — 2026-09-12

**Decision:** Advertise KLT Image 1.1.0 build 4 at its distinct tailnet-only URL with SHA-256 `4e884df54b06c393dbbb48c77bc96477b915dc4ba79cf26c6a29c7f59f672442`. Preserve affected Build 3 unchanged as an unadvertised rollback artifact rather than replacing it in place.

**Rationale:** The exact served Build 4 download matched the approved artifact byte-for-byte, passed the independent Developer ID, notarization, stapling, quarantine, and Gatekeeper checks, and launched normally under App Translocation.

**Implications:** Build 4 is the only recommended tailnet download. If it must be rolled back, remove only its versioned file and restore source-only guidance; do not present Build 3 as a trusted release. Tailnet-only availability does not authorize broad public distribution.
