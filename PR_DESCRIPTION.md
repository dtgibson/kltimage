## Analysis controls

### What this does

KLT Image now lets an analyst choose RGB or CIE Lab D65 variables, covariance or correlation analysis, and whole-image or selected-region statistics. All eight combinations enhance the complete source image at full resolution while keeping RGB covariance with whole-image sampling as the pixel-identical default.

A single rectangular sample can be drawn, moved, or resized directly over the image, or entered as exact top-left source-pixel X, Y, width, and height values. The same source-coordinate region remains aligned through fit, zoom, pan, and Split view. Invalid drafts remain available for correction, stop recalculation, disable export, and never fall back to whole-image statistics or an older committed region.

Method changes automatically supersede older work, and only the newest result matching the visible method and sample can be exported. The unchanged source and any prior enhancement remain available for comparison while a request is processing or needs correction, with clear not-current status.

The full-frame pipeline now validates a documented 64-megapixel ceiling from image metadata before requesting full-resolution decoding, then rechecks the decoder output before allocating its RGBA buffer. Oversized images fail with a specific import message instead of entering an unbounded memory-pressure path.

### How to test

1. Open `KLTImage.xcodeproj` in Xcode 26 or later, select the `KLTImage` scheme and `My Mac`, then press Command-R.
2. Open an oriented JPEG, PNG, TIFF, or HEIC image. Confirm RGB, Covariance, and Whole image are selected by default and an enhanced result appears.
3. Switch independently between RGB and Lab, and between Covariance and Correlation. Confirm each change recalculates from the unchanged source and the active method updates in the metadata strip.
4. Choose Selected region. Confirm export becomes unavailable and the app asks for a sample instead of using whole-image statistics.
5. Drag on the source pane to create a rectangle. Move it from its interior and resize it from a corner; in Split view, confirm both panes show the same source-pixel bounds.
6. Enter exact X, Y, Width, and Height values and click Apply bounds. Enter an invalid or smaller-than-four-pixel region and confirm the attempted values remain editable, the problem is explained, and export stays unavailable. Correct the values and apply again.
7. Switch back to Whole image, then return to Selected region. Confirm the valid region is retained and reused. Clear it and confirm the app returns to the awaiting-region state.
8. Open the method details and confirm it explains the active variables, matrix basis, statistical sample, full-image application, stable components, and exploratory limits.
9. Export a current result as PNG, TIFF, or JPEG. Confirm its dimensions match the source and no region outline is included; PNG and TIFF should retain transparency.
10. Open a second image. Confirm its sample resets to Whole image and navigation resets, while the current RGB/Lab and Covariance/Correlation choices remain selected.
11. Open an image whose declared dimensions exceed 64 megapixels and confirm it is rejected with the documented limit before processing begins.
12. Press Command-U to run the numerical, image-pipeline, and interface automation checks.

### Notes for reviewer

- Lab processing converts sRGB values through CIE 1976 L*a*b* with a D65 reference white, transforms all source pixels, converts back to sRGB, and clips finite out-of-gamut channels while preserving alpha.
- Correlation normalizes numerically stable variables to unit variance. Flat or nearly flat variables are excluded from normalization and reported as limited variation rather than silently switching methods.
- A selected region supplies statistics only. Its half-open integer source-pixel bounds do not crop, mask, or localize the full-image enhancement.
- Region sampling supports one axis-aligned rectangle with at least four source pixels. Multiple regions, freehand selection, saved presets, and exported transform data remain out of scope.
- The shipped RGB covariance whole-image path remains byte-identical, including transparent and degenerate inputs.
- The Release performance suite exercises all eight analysis combinations on a 24-megapixel fixture and enforces the five-second target on Apple silicon.
- Full-frame processing is intentionally capped at 64 megapixels. Larger-image support belongs in a future tiled or out-of-core path rather than a hardware-dependent allocation attempt.
- IBM Plex Sans and IBM Plex Mono remain bundled under the SIL Open Font License.

## Convention Flags

- Keep scientific transforms in the independently testable `KLTCore` framework and keep file-panel and presentation state in the main-actor workspace model.
- Normalize imported images to oriented 8-bit sRGB premultiplied RGBA before analysis, and preserve the original decoded buffer unchanged.
- Keep analysis keys and request identity explicit so canceled or superseded work can never become current or exportable.
- Keep all image processing local, cancellable, deterministic, and off the main thread.

## Trusted release signing fix

### What changed

- Bumped KLT Image to 1.1.0 build 4 so the repaired artifact cannot be confused with affected build 3.
- Added `scripts/release-macos.sh`, a fail-closed universal macOS release path pinned to `Developer ID Application: DAVID THOMAS GIBSON (8QKC3L2FKP)`.
- The script signs KLTCore before its containing app with secure timestamps and hardened runtime, then enforces the expected identity, Team ID, bundle IDs, version, architectures, and exact sandbox/user-selected-file entitlements. It rejects ad-hoc signatures, unexpected entitlements, and `get-task-allow`.
- The distributable ZIP is created only after Apple accepts notarization and the ticket is stapled and validated.
- Added `scripts/verify-macos-release.sh` to enforce an expected SHA-256 on the exact ZIP, extract a clean verification copy, apply quarantine, recheck the signature and ticket, and require Gatekeeper acceptance specifically as `Notarized Developer ID`.
- Updated local-use guidance to identify hosted build 3 as affected and prohibit quarantine removal as a workaround. Publishing or replacing that file remains a separate deployment action.

### Engineer verification

- A universal Release build completed for arm64 and x86_64.
- KLTCore.framework and KLT Image.app passed strict signature verification using the required Developer ID identity, Team ID `8QKC3L2FKP`, secure timestamps, and hardened-runtime flags.
- The app signature contains exactly `com.apple.security.app-sandbox` and `com.apple.security.files.user-selected.read-write`; `com.apple.security.get-task-allow` is absent.
- Debug KLTCore tests passed 33/33 and Release KLTCore tests passed 34/34, including the 24-megapixel performance matrix.
- The independent verifier rejected a deliberately incorrect SHA-256 before extraction.
- App Store Connect Team API-key authentication completed without reading or printing private key material. Apple accepted submission `0d58fc72-c6d2-4a41-b1ad-61091db2761d`; its ticket was stapled and validated.
- The final ZIP at `/var/folders/qn/fzq2ymy1219bnchgrdvmcrdc0000gp/T/kltimage-release.MEV7ae/KLT-Image-1.1.0-build-4.zip` has SHA-256 `4e884df54b06c393dbbb48c77bc96477b915dc4ba79cf26c6a29c7f59f672442`.
- The independent verifier matched that checksum, revalidated the exact signatures and entitlements, validated the stapled ticket, applied quarantine to an extracted copy, and received Gatekeeper `accepted` with `source=Notarized Developer ID`.
- The final candidate is not published. Build 3 and all tailnet/server state remain untouched pending the explicit deployment gate.
- Security remediation: the release archive and checksum now remain under `UNVERIFIED-…pending` names while the independent verifier runs. A verifier rejection is routed through the release script's explicit failure path, preserves the staged app/workspace/pending diagnostics, and leaves no final-named artifact. Only verifier success permits same-volume atomic renames to the final ZIP and checksum names.
- `./scripts/release-macos.sh --self-test-promotion` passed both regression branches: forced verifier failure retained pending diagnostics with no final names and emitted the release failure path; forced success removed pending names, atomically promoted both final names, and left a valid checksum naming the promoted archive.
- The packaging-boundary change does not alter the already accepted, stapled app or archive bytes. The existing candidate and SHA-256 were re-run through the real independent verifier after remediation and again passed signatures, entitlements, ticket validation, quarantine, and Gatekeeper acceptance, so a duplicate Apple submission was neither required nor created.
