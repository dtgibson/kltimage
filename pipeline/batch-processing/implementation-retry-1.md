# Engineer correction — QA retry 1

2026-10-03. Scoped correction to QA-F1/QA-F2 and priority coverage; no stage or lifecycle transition.

## Changes

- Mobile Batch action labels own their minimum 44×44 hit geometry. This includes intake, clear, remove, folder, close, start, cancel, return, disclosure and method/format menu triggers. Essential labels can wrap; the heading stacks above Close at accessibility sizes. The JSON row preserves a native switch, with one full-row action and native accessible on/off state. Mac retains its existing action styles, default quiet controls and layout.
- Destination presentation resolves a localized folder name, rejects provider plumbing names/opaque IDs, and falls back to **Selected Files folder** on mobile. Start freezes this presentation; the runner reports its actual created run folder separately. Picker-granted URLs and their security-scoped lifetime are unchanged. No destination `URL.path` is rendered.
- Added missing lease checks to Mac `updateRegionDraft`, `applyRegionDraft`, `commitPointerRegion`, and `clearRegion`. The populated-workspace test attempts all four, including an unapplied valid draft so a forbidden Apply would be observable.
- Added real-model/runner coverage for exact populated workspace preservation through complete/fail/cancel/dismiss, delayed cancellation drainage and lease retention, frozen replay through library rename/removal and setup edits, low/unknown capacity, destination access loss, and image-committed/JSON-failed outcomes. Source identity, accepted job/request, canonical record bytes, library/method/region and viewport geometry are preserved. Saved pixels and output file lists are reconciled. Capacity and publication fault hooks are per-run and `#if DEBUG` only.

## Verification

Evidence directory: `implementation-evidence/retry-1/`.

| Check | Result |
|---|---|
| iPhone 17 Pro focused batch suite | 12 passed, 0 failures; `iphone-tests.log` |
| iPad Pro 13-inch (M5) focused batch suite | 12 passed, 0 failures; `ipad-tests.log` |
| Signed direct Mac focused batch suite | 12 passed, 0 failures after the unapplied-draft assertion; `mac-build.log`, `mac-batch-tests.log` |
| True Release Mac and iOS Simulator builds | Both succeeded without DEBUG; no `BatchTestFaults`/`testFaults` symbols. `*-shipping-release.log`, `shipping-release-audit.json` |
| Final mobile UI build / whitespace | Build succeeded; `git diff --check` passed |

The iPhone/iPad test runs preceded final view-only toggle/header refinements; those refinements compile in Debug and both shipping Release configurations and were checked natively. No unchanged core benchmark or full suite was rerun. Release Simulator compilation is not an iOS distribution archive or TestFlight verification.

Native iPhone button bounds: Files 87×44, Photos 134×44, Clear 55.3×44, Remove 44×44, folder 118/119×44, Close 58.3×45, Start 105×44, Return 113×44, disclosures 354×44; method/format triggers are at least 51.7 points high. Start was activated at (26,782), two points inside its new upper-left edge. At maximum accessibility size, **Batch processing** wraps completely and **Add from Photos…** retains its full label. Original Medium content size restored.

Native iPad final view shows Files/Photos/Clear/folder/Start at 44 points high and Close at 45. JSON row is 532×44; tapping (252,589), two points inside its upper-left edge, changes the native accessible value from 0 to 1 (`ipad-settings.txt`, `ipad-toggle-edge-tap.txt`). An earlier padded-toggle experiment enlarged accessibility bounds without making that edge tappable; it was replaced. `iphone-toggle-edge-tap.txt` is that superseded diagnostic, not passing final evidence. Apple-owned remote picker chrome was not modified.

Native Photos → On My iPhone → Start completed one source. Setup/outcome show **Selected Files folder**, since this provider supplies no useful localized root name, plus actual run folder `KLT Batch 2026-10-03 01-18-56 1163E43D-EF1F-4CA4-AF16-F5BB8C4F8245`. See `iphone-destination.txt`, `iphone-running.txt`, `iphone-result.txt` and screenshots. No container path appears in those location labels. The run had JSON off.

Native screenshot review: https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-batch-review/retry-1/ . Existing private review service, routes and index remain unchanged.

## Handoff limits

Independent QA still owns true foreground/background/window/quit transitions, visible cancellation timing, full-resolution short-versus-100 memory profiling, and remaining native acceptance. No physical device was enumerated or used; no global Xcode/accessibility setting, unrelated process, release artifact, public route, pipeline state, telemetry or handoff state was changed.

Commands reuse `qa-evidence/commands.md`, with `-only-testing:KLTImageIOSTests/BatchProcessingTests` on mobile and `-XCTest KLTImageTests.BatchProcessingTests` on the direct signed Mac command. Builds use per-process `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; shipping builds use `-configuration Release`, Mac destination `platform=macOS,arch=arm64` and iOS destination `generic/platform=iOS Simulator`. Native automation uses the recorded `qa-evidence/simulator-ui.py` and only the two documented simulator UUIDs.
