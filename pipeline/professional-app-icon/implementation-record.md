# Implementation Record — Professional App Icon

Engineer stage 3 of 7, Improve with design pass. Completed September 14, 2026 against the user-approved “Registered color” artwork. The Weft design doctrine and project design system informed fidelity checks; this static resource introduces no motion or application UI.

## Changes

- Added `KLTImage/Resources/Assets.xcassets/AppIcon.appiconset/` with all ten standard macOS slots: 16, 32, 128, 256, and 512 points at 1× and 2×, plus catalog metadata.
- Added `scripts/export-app-icon.py`, which renders the unchanged editable `icon-master.svg` using `rsvg-convert`, reuses identical pixel sizes, and supports non-mutating `--check`. Generated production PNGs are byte-identical to the corresponding approved review PNGs. Normal builds need no exporter dependency.
- Made `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` explicit in `project.yml` and regenerated `KLTImage.xcodeproj` using XcodeGen. XcodeGen already supplied that setting implicitly; the generated project diff only registers the new asset catalog and its resource build phase.
- Updated review-sheet labels from draft to approved and regenerated its HTML and presentation PNG without changing artwork. Updated `PR_DESCRIPTION.md` and `HOW_TO_RUN.md` with review and reproduction instructions.
- Preserved the user's existing `CLAUDE.md` change. No Swift, framework, behavior, entitlement, release-tool, global-state, or production-publication changes.

## Verification

- `python3 scripts/export-app-icon.py --check`: passed for all ten slots and both metadata files (librsvg 2.56.3).
- Image inspection: all ten slots have exact expected dimensions, RGBA data, transparent corners, and byte-for-byte parity with approved review PNGs. The 16-pixel lower-edge shadow has alpha 3/255 on its bottom row, consistent with the approved master; larger exports have fully transparent outer rows. No geometry or optical variant was introduced.
- Reviewed the regenerated presentation PNG: approved label fits; artwork, diagonal continuity, light/dark separation, and small-size silhouette remain intact.
- `weft-design-lint check pipeline/professional-app-icon/design.html`: clean, 0 findings. Motion/controls/type-in-app checks do not apply to a static icon asset.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project KLTImage.xcodeproj -scheme KLTImage -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .derived-data/professional-app-icon -quiet`: passed, exit 0, signing enabled.
- Built app contains `Contents/Resources/AppIcon.icns` (24,295 bytes); generated Info.plist has both `CFBundleIconFile = AppIcon` and `CFBundleIconName = AppIcon`.
- `git diff --check`: passed.
- HTTPS preview returned HTTP 200: https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-icon/design.html

## Handoff

Built app: `.derived-data/professional-app-icon/Build/Products/Debug/KLT Image.app`. Orchestrator/Tester will independently inspect Finder, Dock, and app-switcher presentation, run complete signed Debug and optimized ReleaseTests suites, and assess release packaging. No new XCTest cases were added for static artwork; deterministic source-to-asset checks and actual asset compilation validate this change directly.

The source version remains 1.3.1 build 7 at this stage. Coordinate the planned bump to **1.3.2 build 8** in `project.yml` and regenerate before the later signed release build. Do not overwrite the published Build 7 artifact. No distributable has been created by this stage.

## Convention Flags

- Keep the original editable icon master in the feature design artifacts, committed native PNG slots in the app catalog, and use `python3 scripts/export-app-icon.py --check` to detect divergence after future artwork changes. Regenerate only after the design is approved.
