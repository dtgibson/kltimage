## Reproducible Analysis

### What this does

KLT Image now creates an immutable analysis record with every successfully completed enhancement. The record binds the displayed result to its decoded oriented source fingerprint, exact request and sample geometry, statistical inputs, eigensystem, applied transform, and output mapping, then exposes those values in a trigger-anchored scientific inspector.

Users can export the accepted snapshot as canonical version-1 JSON. Repeated exports are byte-identical, use sorted stable keys and finite round-trippable numbers, write atomically, and omit paths, timestamps, and processing UUIDs.

### How to test

1. Open `KLTImage.xcodeproj` in Xcode 26 or later, select the `KLTImage` scheme and `My Mac`, then press Command-R.
2. Open a JPEG, PNG, TIFF, or HEIC image and wait for **Result ready**.
3. In the metadata strip, confirm **ANALYSIS RECORD · CURRENT** appears and click **Analysis Record**.
4. Inspect **Summary**, **Matrices**, and **Applied transform**. Confirm the filename and dimensions match the source, the request matches the visible controls, a full SHA-256 appears, and every vector, matrix, channel convention, output mapping, and integrity rule is labeled.
5. Choose **Selected region**, define valid source-pixel bounds, and reopen the record after processing. Confirm both normalized geometry and exact half-open integer bounds are present.
6. Change any color-space, matrix, sampling, or region setting. Confirm the record action and image export become unavailable immediately and return only after the matching result completes.
7. Click **Export JSON**, save the suggested `<source>-klt.klt-analysis.json` file twice, and confirm the two files have identical SHA-256 checksums. Confirm whole-image JSON contains `"region": null` and no timestamp, absolute path, or job UUID.
8. Dismiss the record and confirm Original, Split, and Enhanced comparison, zoom, pan, region editing, and full-resolution image export still work unchanged.
9. Press Command-U in Xcode to run the Debug tests. Run the Release configuration as well; the 24-megapixel matrix must remain below five seconds for every supported analysis combination.

### Notes for reviewer

- SHA-256 covers the documented domain separator, big-endian oriented dimensions, the `rgba8-premultiplied-srgb` format identifier, and the complete decoded RGBA byte buffer. The display filename is descriptive and does not affect source identity.
- `StretchAnalysis` now retains the exact final transform and the real rendered output path: RGB global minimum/maximum/scale, Lab D65-to-sRGB finite gamut clipping, or limited-variation identity.
- The workspace builds image and record together off the main actor, accepts them through the same request/job gate, and exposes one shared current-result predicate to image export, record inspection, and JSON export.
- The version-1 wire contract is implemented with dedicated export DTOs rather than broad `Codable` conformance. A golden-byte test pins the exact sorted-key JSON shape and explicit whole-image null region.
- The record stays in memory only. There is no history, imported transform, implicit sidecar, metadata embedding, database, account, analytics, or network path.
- JSON save failures preserve the current image and record and use an atomic write so no partial final-named file remains.
- The separately reported crash when opening a replacement image was intentionally not addressed in this feature; it remains captured as its own Fix item.

### Reproducible Analysis verification

- The complete Debug suite passed 43/43 tests and the complete Release suite passed 44/44 tests.
- All 17 acceptance criteria passed, including the selected-region workflow, Analysis Record accessibility assertions, deterministic JSON export, stale-record invalidation, and comparison-state restoration.
- Every supported 24-megapixel analysis combination remained below five seconds, and record generation added 1.687% median overhead.
- The repeated and near-equal eigensystem determinism regression passed.
- The real app was inspected at approximately 1200 points wide. Summary, Matrices, Applied Transform, footer controls, JSON export, stale-record invalidation, and restoration after matching region analysis all behaved as designed; the trigger-anchored popover remained fully visible.
- Full Keyboard Access was disabled during automation, so keyboard coverage combines UI XCTest with live accessibility-tree verification.
- XcodeGen completed successfully, the Swift UI design lint reported no findings across all eight app source files, and `git diff --check` passed.

## Convention Flags

- Pair every accepted enhancement and analysis record in one immutable, job-identified workspace snapshot so inspection and export cannot reconstruct scientific values from mutable controls.
- Treat the versioned analysis JSON as a protocol contract with dedicated DTOs, sorted keys, explicit nulls, finite-value validation, and golden-byte coverage.

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
