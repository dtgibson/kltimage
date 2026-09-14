## Custom Color Spaces and Reusable Transforms

### What this does

KLT Image now treats a working space and a saved transform as two distinct, inspectable method types. A working space defines reversible three-channel coordinates in which the app calculates a fresh decorrelation stretch. A saved transform freezes one accepted calculation so the exact center, transform, working-space revision, and output mapping can be replayed on the same or another image without adapting to target statistics.

The method library includes standard RGB/Lab, three documented DStretch-inspired curated spaces, and user-defined affine spaces over encoded sRGB or CIE Lab D65. User methods persist locally and support create, edit with immutable definition versions, rename, duplicate, delete, strict JSON import, and deterministic JSON export.

The comparison toolbar now exposes all four display-only views requested by the user: **Original**, **Side-by-Side**, **Slider**, and **Processed**. Calculated and replayed provenance remains visible across the workspace and versioned analysis record.

### How to test

1. Open `KLTImage.xcodeproj` in Xcode 26 or later, select the `KLTImage` scheme and `My Mac`, then press Command-R.
2. Open an image, then switch among Original, Side-by-Side, Slider, and Processed. Confirm synchronized zoom/pan and that the Slider divider supports pointer, arrow, Shift-arrow, Home, End, and accessibility-adjust actions.
3. Open **Methods**. Confirm the working-space section contains RGB, CIE Lab D65, Luma + Chroma, Red + Complement, and Lab Blue / Yellow, while saved transforms occupy a separate section.
4. Apply each curated space, change covariance/correlation and whole-image/selected-region sampling, and confirm the result is labeled **Calculated**.
5. Create or duplicate a working space, edit its 3×3 forward matrix, three offsets, channel names, and purpose, then save. Confirm invalid or ill-conditioned mathematics remains in the editor with a specific validation message.
6. Save a current calculated result as a transform. Apply it to the origin image and confirm identical processed bytes, then apply it to another image and confirm the controls are frozen and replay diagnostics are observational only.
7. Choose **Calculate for This Image** and confirm the app returns to calculated mode using the prior calculated controls rather than silently changing the saved recipe.
8. Export and re-import `.klt-space.json` and `.klt-transform.json` files. Exercise Add, Replace, Import as Copy, and Cancel. Present an analysis record, duplicate key, unknown field, BOM, malformed/deep JSON, oversized file, and inconsistent inverse; each must fail before mutation.
9. Inspect and export Analysis Record v2 for a curated/custom calculation and replay. A replay must have `"calculation":null`, a nested frozen application, explicit optional outcome nulls, and no target mean, covariance, eigensystem, gains, or sampling region.
10. Press Command-U for Debug. Run Release separately so the 24-megapixel standard matrix, affine calculation, frozen replay, and 500-item library timing checks execute.

### Notes for reviewer

- Standard RGB/Lab calculations retain the shipped arithmetic branches and byte-compatible version-1 analysis JSON. Curated/custom affine calculations and all replays route to an additive version-2 record.
- Built-in working-space identities are pinned to their exact version-1 base, channels, coefficients, and zero offsets. User identities are lowercase UUIDs; edits advance an immutable definition version.
- Recipe replay performs only the frozen coordinate conversion, centering, transform, inverse conversion, and captured output mapping. It does not run target accumulation, covariance/correlation, eigensolving, gains, range fitting, or gamut fitting.
- Portable method import accepts only a regular non-symlink local file, reads no more than 256 KiB, and applies strict depth, UTF-8, duplicate-key, field, schema, version, numeric, identity, inverse, and recipe-consistency validation.
- Library and portable exports share an fsync-backed temporary-file and atomic-rename primitive. Library mutations are serialized and a corrupt/future library fails closed without blocking built-in analysis.
- All pixels, filenames, fingerprints, recipes, and methods remain local. This change adds no networking, analytics, account, bookmark, plug-in, shader, code-evaluation, or cloud path.

### Engineer verification

- Arm64 Debug passes 60/60 core tests and 18/18 app/store tests. Rosetta/x86_64 Debug passes the same 78 non-UI tests. The shipping Release builds universal arm64/x86_64 with hardened runtime enabled and testability disabled.
- Three clean project-supported `ReleaseTests` runs each passed 80/80 tests without command-line testability or architecture overrides. `ReleaseTests` remains an arm64 active-architecture configuration for optimized local XCTest only.
- Across those optimized runs every 24-megapixel path stayed below five seconds; affine calculation was 2.341–2.427 s, frozen replay was 1.034–1.070 s, and originating/replayed bytes matched exactly.
- The Release 500-item method-library load was 0.324–0.351 seconds. The 64-megapixel replay memory fixture passed with peak incremental memory of 256,016,384 bytes, consistent with one output frame and no avoidable duplicate.
- Focused coverage pins curated matrices and conditioning, all curated request combinations, capture/replay equality, cross-source diagnostics, strict portable documents, exact malformed-field counts, cross-type normalized-name conflicts, preflight identity/version mismatch rejection, unsuccessful-open isolation, fully transparent replay, concurrent clipping/low-contrast reporting, bounded regular-file reads, every durable-write checkpoint, persistence failures, revision conflicts, and mutation serialization.
- Final macOS UI verification passes 6/6 tests. Native keyboard traversal creates complete encoded-sRGB and CIE Lab D65 definitions, submits each with Return from the focused final offset, and finds both rows after process termination and relaunch. Invalid Return stays in the editor with its specific validation message and disabled Save. Larger text and increased contrast pass in both system appearances.
- XcodeGen completed successfully. The design mockup passes the current Weft design lint; the installed linter does not scan Swift files. `git diff --check` passes.

## Convention Flags

- Keep working-space definitions and frozen recipes as separate artifact types; never infer replay from an analysis record.
- Persist and process validated immutable snapshots so library metadata changes cannot retroactively relabel or alter an accepted result.
- Preserve standard arithmetic and version-1 analysis bytes; use tagged additive versions for new calculation/replay semantics.
- Keep all comparison modes presentation-only and all method/library work local to the Mac.

## Deployment

- KLT Image 1.3.0 build 6 is the next monotonic feature candidate. QA passed with 37 Pass, 1 Partial solely for unavailable native Intel hardware, and 0 Fail; security passed with zero findings.
- Release preparation reuses the existing fail-closed universal Developer ID signing, notarization, stapling, quarantined Gatekeeper, checksum, and independent-verification path. Publication remains a separate explicitly confirmed action.
- No production artifact or advertised link has changed. Trusted KLT Image 1.2.0 build 5 remains the exact rollback release while this candidate awaits the production gate.

### Release notes

KLT Image 1.3.0 adds a transparent local method library with documented curated and user-defined reversible three-channel working spaces. A separate saved-transform workflow freezes an accepted calculation—including its working-space revision, center, transform, and output mapping—for deterministic replay on the original or another image without refitting target statistics.

Method definitions and recipes can be inspected, renamed, duplicated, deleted, exported, and strictly imported as bounded inert JSON. Calculated versus replayed provenance remains explicit throughout the workspace and versioned analysis record, while existing RGB/Lab version-1 analysis JSON stays byte-compatible. The comparison workspace now includes Original, Side-by-Side, Slider, and Processed views with synchronized navigation and accessible keyboard control.

The release remains local-only and sandboxed: no accounts, uploads, analytics, networking, plug-ins, or executable import path were added. It requires macOS 14 or later.

## Trusted release signing fix

### What changed

- Bumped KLT Image to 1.1.0 build 4 so the repaired artifact cannot be confused with affected build 3.
- Added `scripts/release-macos.sh`, a fail-closed universal macOS release path pinned to `Developer ID Application: DAVID THOMAS GIBSON (8QKC3L2FKP)`.
- The script signs KLTCore before its containing app with secure timestamps and hardened runtime, then enforces the expected identity, Team ID, bundle IDs, version, architectures, and exact sandbox/user-selected-file entitlements. It rejects ad-hoc signatures, unexpected entitlements, and `get-task-allow`.
- The distributable ZIP is created only after Apple accepts notarization and the ticket is stapled and validated.
- Added `scripts/verify-macos-release.sh` to enforce an expected SHA-256 on the exact ZIP, extract a clean verification copy, apply quarantine, recheck the signature and ticket, and require Gatekeeper acceptance specifically as `Notarized Developer ID`.
- Updated local-use guidance to advertise the verified Build 4 tailnet package and checksum. The affected Build 3 package remains hosted only as an unadvertised rollback artifact.

### Engineer verification

- A universal Release build completed for arm64 and x86_64.
- KLTCore.framework and KLT Image.app passed strict signature verification using the required Developer ID identity, Team ID `8QKC3L2FKP`, secure timestamps, and hardened-runtime flags.
- The app signature contains exactly `com.apple.security.app-sandbox` and `com.apple.security.files.user-selected.read-write`; `com.apple.security.get-task-allow` is absent.
- Debug KLTCore tests passed 33/33 and Release KLTCore tests passed 34/34, including the 24-megapixel performance matrix.
- The independent verifier rejected a deliberately incorrect SHA-256 before extraction.
- App Store Connect Team API-key authentication completed without reading or printing private key material. Apple accepted submission `0d58fc72-c6d2-4a41-b1ad-61091db2761d`; its ticket was stapled and validated.
- The final ZIP at `/var/folders/qn/fzq2ymy1219bnchgrdvmcrdc0000gp/T/kltimage-release.MEV7ae/KLT-Image-1.1.0-build-4.zip` has SHA-256 `4e884df54b06c393dbbb48c77bc96477b915dc4ba79cf26c6a29c7f59f672442`.
- The independent verifier matched that checksum, revalidated the exact signatures and entitlements, validated the stapled ticket, applied quarantine to an extracted copy, and received Gatekeeper `accepted` with `source=Notarized Developer ID`.
- After explicit production approval, Build 4 was published at its distinct tailnet-only URL without replacing Build 3. A fresh download matched SHA-256 `4e884df54b06c393dbbb48c77bc96477b915dc4ba79cf26c6a29c7f59f672442`, passed the independent verifier as `Notarized Developer ID`, and launched under App Translocation with quarantine retained.
- Security remediation: the release archive and checksum now remain under `UNVERIFIED-…pending` names while the independent verifier runs. A verifier rejection is routed through the release script's explicit failure path, preserves the staged app/workspace/pending diagnostics, and leaves no final-named artifact. Only verifier success permits same-volume atomic renames to the final ZIP and checksum names.
- `./scripts/release-macos.sh --self-test-promotion` passed both regression branches: forced verifier failure retained pending diagnostics with no final names and emitted the release failure path; forced success removed pending names, atomically promoted both final names, and left a valid checksum naming the promoted archive.
- The packaging-boundary change does not alter the already accepted, stapled app or archive bytes. The existing candidate and SHA-256 were re-run through the real independent verifier after remediation and again passed signatures, entitlements, ticket validation, quarantine, and Gatekeeper acceptance, so a duplicate Apple submission was neither required nor created.
