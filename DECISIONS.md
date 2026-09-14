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

**Rationale:** Download quarantine and Gatekeeper apply independently of audience size. Build 3 was built with Xcode signing disabled, then ad-hoc signed without a secure timestamp; release checks accepted its internal seal even though Gatekeeper rejected it. GitHub's v1.0.0 build 2 was also ad-hoc signed, unnotarized, and rejected by Gatekeeper, so there was no older trusted release to regress from—older copies likely opened without quarantine or with a local exception.

**Implications:** Release automation must fail on signing identity, team, timestamp, hardened-runtime, entitlement, architecture, version, notarization, ticket, checksum, or Gatekeeper mismatches. The release ZIP and checksum must keep unmistakably pending names until the independent verifier accepts them; only then may same-volume renames expose final names. A failed verifier may retain pending diagnostics but must leave no final-looking artifact. Quarantine removal is never an acceptance workaround. This trust decision does not remove the existing QA evidence debt or approve broad public distribution.

## Publish verified Build 4 on the private tailnet — 2026-09-12

**Decision:** Advertise KLT Image 1.1.0 build 4 at its distinct tailnet-only URL with SHA-256 `4e884df54b06c393dbbb48c77bc96477b915dc4ba79cf26c6a29c7f59f672442`. Preserve affected Build 3 unchanged as an unadvertised rollback artifact rather than replacing it in place.

**Rationale:** The exact served Build 4 download matched the approved artifact byte-for-byte, passed the independent Developer ID, notarization, stapling, quarantine, and Gatekeeper checks, and launched normally under App Translocation.

**Implications:** Build 4 is the only recommended tailnet download. If it must be rolled back, remove only its versioned file and restore source-only guidance; do not present Build 3 as a trusted release. Tailnet-only availability does not authorize broad public distribution.

## Publish Reproducible Analysis through GitHub Releases and the tailnet — 2026-09-12

**Decision:** Publish KLT Image 1.2.0 build 5 through GitHub Releases and the existing tailnet-only Tailscale mirror. Both channels use the identical versioned ZIP with SHA-256 `66883ef34f22043bbf74b51e76648ad62527ac47be6fb9c28f33fee2e89ae3aa`; Build 4 remains unchanged as the trusted rollback artifact.

**Rationale:** Reproducible Analysis passed all 43 Debug tests, all 44 Release tests, all 17 acceptance criteria, and a zero-finding security review. Fresh downloads from both production channels matched the approved candidate byte-for-byte, passed the independent release verifier, and launched through App Translocation with quarantine retained.

**Implications:** GitHub Releases is the public primary download and the existing Tailscale route remains a tailnet-only mirror without configuration changes. Rollback removes the Build 5 advertisement and hosted assets and restores Build 4; copies already downloaded cannot be recalled.

## Make reproducibility a versioned, local analysis protocol — 2026-09-12

**Decision:** Every accepted enhancement owns an immutable analysis record bound to the decoded, oriented source fingerprint and the exact source, request, and processing job; users can inspect that snapshot and explicitly export it as canonical version-1 JSON, while history, record import, and transform replay remain out of scope.

**Rationale:** Interactive color-space, matrix, and sampling choices make visually similar results ambiguous unless the app preserves the exact numerical inputs and applied output path without reconstructing them from mutable controls.

**Implications:** Future record versions must preserve result currency, deterministic protocol compatibility, finite values, explicit user-directed local export, and the exploratory-use boundary. Persistent projects, comparisons, imported records, or reusable transforms require separately designed capabilities rather than silent extensions to version 1.

## Separate transparent working spaces from frozen transform recipes — 2026-09-13

**Decision:** Working spaces are inspectable, reversible three-channel definitions over encoded sRGB or CIE Lab D65 that calculate a new image-specific transform; saved transforms are complete immutable recipes that replay captured mathematics without fitting anything to the target image. Curated spaces use the same transparent definition model as user-created spaces and carry no scientific rank.

**Rationale:** A coordinate system and a prior calculation answer different questions. Keeping them distinct lets users explore new variables or reuse one controlled method without presenting fixed replay as target-derived analysis.

**Implications:** Product language, library organization, processing requests, provenance, and future method features must preserve the calculated/replayed distinction. Later edits or deletion of a working space cannot change a recipe that captured an earlier definition, and adaptive reuse requires a separately named method.

## Keep local method documents strict and type-separated — 2026-09-13

**Decision:** KLT Image persists only user working spaces and saved transform recipes in its sandboxed method library and exchanges them through separate versioned document types. Analysis records remain documentary and are never accepted as executable methods.

**Rationale:** Explicit type boundaries make portable methods understandable and prevent historical provenance from becoming code-like input by implication, while narrowly scoped persistence supports reuse without creating an image project or history database.

**Implications:** Future method formats must remain local, deterministic, bounded, fail-closed, and independently versioned. The library must not accumulate source pixels, results, analysis history, regions, bookmarks, or ordinary workspace state.

## Publish Build 6 identically through GitHub and the tailnet — 2026-09-13

**Decision:** KLT Image 1.3.0 build 6 is the current public GitHub and tailnet-only Tailscale release. Both channels serve the identical ZIP with SHA-256 `dbac952c70e1d05f38ec10af099577c4e082f089653eb6d37c33e05c4299c4f3`; KLT Image 1.2.0 build 5 remains unchanged as the trusted rollback release.

**Rationale:** The served Build 6 copies matched the approved candidate and each other byte-for-byte after publication and passed the independent release verifier.

**Implications:** Rollback restores Build 5 as the advertised release and removes only Build 6 release assets and references while leaving the existing Tailscale route and Build 5 bytes unchanged. Already-downloaded Build 6 copies cannot be recalled.
