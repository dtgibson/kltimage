## Professional App Icon

### What this does

KLT Image previously had no custom application icon. It now compiles the approved original navy-and-teal image-comparison artwork into a native macOS AppIcon asset catalog, covering all ten 16–512-point slots at 1× and 2×. The editable SVG, reproducible exporter, and small-size review proofs remain in the repository; application behavior is unchanged.

### How to test

1. Review the [approved icon preview](https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-icon/design.html).
2. Run `python3 scripts/export-app-icon.py --check` to verify production assets match the SVG.
3. Run `xcodegen generate`, then build the KLTImage scheme. Confirm the built app contains `Contents/Resources/AppIcon.icns` and its Info.plist identifies `AppIcon`.
4. Verify the universal release's bundled icon, Developer ID signatures, notarization, stapling, and quarantined Gatekeeper acceptance. The user approved icon-focused verification for this resource-only change; do not rerun unrelated application suites.

### Notes for reviewer

The SVG artwork matches the direction approved by the user on September 14, 2026. Production export requires librsvg (`rsvg-convert`); review-sheet export additionally uses Pillow and the already-bundled fonts. Generated PNGs are committed, so normal Xcode builds need neither dependency. Motion, controls, data handling, entitlements, and document icons are outside this resource-only change.

The implementation Debug build and deterministic asset checks are recorded in `pipeline/professional-app-icon/implementation-record.md`. QA records the accepted icon-focused scope, the actual 95/96 Debug result (one imposed timeout), and 92/92 optimized core/app tests; no full-suite pass is claimed. Version 1.3.2 build 8 is published at https://github.com/dtgibson/kltimage/releases/tag/v1.3.2 after explicit approval. Its fresh GitHub download is byte-identical to the approved ZIP and passes universal architecture, Developer ID signature, notarization, stapling, checksum, quarantine and Gatekeeper verification. Version 1.3.1 build 7 remains the rollback release.
