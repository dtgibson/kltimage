# QA Report — Batch Processing

**Verification tier: 2 — Full weave.** Deterministic classification: `CLASSES logic`, `TRIGGERS runtime-data`, 18 files, base `383756798707e651e5363a5babfdd20c5ecabdbb`.

**Date:** 2026-10-03  
**Test runner:** XCTest via xcodebuild on this Mac and local iOS simulators; signed direct XCTest fallback on Mac.  
**Result:** NEEDS FIX after correction/re-verification 1 — QA-F1 and QA-F2 resolved; new full-resolution memory retention finding QA-F3 blocks acceptance. Native coverage remains partial. No production files changed by this QA stage; one opt-in QA diagnostic was added with orchestrator authorization.

## Current finding requiring correction

### QA-F3 — Settled full-resolution memory grows with completed image count

**Blocking acceptance:** FR-08, NFR-03, QA-04 and QA-25. The real runner processed a three-image batch followed by 100 identical 6000×4000 PNG sources, exporting PNG and version-1 JSON at full resolution. `task_info(TASK_VM_INFO).phys_footprint` was sampled in each settled callback, after `BatchRunner` returns from its per-item processing autorelease pool and completes item cleanup (`SharedBatch/BatchRunner.swift:39`, `:53`). This is current physical footprint at each boundary, not merely a historical peak.

| Measurement | Bytes |
|---|---:|
| Short run settled item 1 | 373,769,608 |
| Short run settled item 2 | 494,011,952 |
| Short run settled item 3 / short maximum | 614,221,504 |
| First 10 items of long run maximum | 1,818,594,520 |
| Last 10 items of long run maximum / final | 2,179,190,336 |
| Long run resident peak (distinct metric) | 3,884,204,032 |

The footprint rose by roughly 120 MB per early item, reached approximately 2.18 GB around long-run item 16–20, and remained there through item 100. The final footprint is 1.565 GB above the short-run maximum. Later plateau does not demonstrate the approved requirement to release completed full-resolution resources before acquiring the next source. The diagnostic also allowed ten long-run warm-up items, yet its last-ten maximum exceeded that warm-up maximum by 360,595,816 bytes. The test's 64 MiB tolerance is a diagnostic allowance, not a new product requirement.

All 103 outcomes succeeded, private staging was empty, cleanup debt was zero, the long run produced 200 final artifacts, and the final image remained 6000×4000. Those assertions passed; the one failure was the memory assertion at `BatchTests/BatchProcessingTests.swift:450`. One test executed in 216.805 seconds. The test starts at line 426 behind **`BATCH_QA_MEMORY && os(macOS)`**, absent normal test and shipping builds. No image-size or quality reduction was used.

Read-only `vmmap -summary` and `heap -s` near item 80 independently show frame-sized allocations: DefaultPurgeableMallocZone held about 3.2 GB allocated, 1.8 GB resident/dirty across 32 blocks; the summary reports zero volatile bytes. Heap reports 17 allocations of approximately 117,200 KB and 16 of approximately 93,808 KB, predominantly untyped non-object memory. This is evidence of retained large allocations, **not proof of a Swift array leak, identified root cause, or proved reclaimable cache**. One outcome array was 14,336 bytes and one entry array 10,240 bytes. No allocator pressure-relief experiment was performed. Sampling a live task may perturb timing slightly; per-item values before and after the sample show the same plateau.

Evidence: `qa-evidence/retry-1/memory-24mp.log`, `memory-build.log`, `memory-vmmap-item80.txt`, `memory-heap-item80.txt`, `memory-samples.csv`, and `commands.md`. Build was optimized ReleaseTests with the explicit QA compilation flag, direct signed hosted XCTest. No mobile memory measurement is claimed. The orchestrator requested immediate hand-back after the completed diagnostic so Engineer can investigate; no second 100-item diagnostic was run, and the earlier empty-failure baseline result is historical only. Do not treat this new diagnostic as an existing-suite regression or a recorded baseline update.

## Correction 1 delta verification

- **QA-F1 resolved for the observed defects:** independently confirmed iPhone Files 87×44, Photos 134×44, Clear 55.3×44, Remove 44×44, folder 119×44, Start 105×44 and Close 58.3×45. Return to setup activates at (26,782), two points inside its new edge. On iPad, tapping two points inside the 532×44 JSON row changes accessible value 1→0→1. Largest accessibility heading wraps completely; content size restored to Medium. Remaining Mac keyboard/VoiceOver and announcement coverage is still unverified.
- **QA-F2 resolved:** current native setup/outcome show **Selected Files folder** and the separate actual run-folder name, with no provider container path rendered. Independent snapshots: `iphone-initial.txt`, `iphone-return-edge.txt`.
- Reviewed Engineer's correction record and focused batch results: 12/12 pass on each Mac, iPhone and iPad; populated workspace preservation, frozen recipe across rename/removal, low/unknown capacity, destination loss and image-only partial outcome coverage were added. These are Engineer-provided results, not independently repeated QA suite runs. Unchanged full suites and core benchmark below retain their original scope.
- **Native iPhone active background/foreground:** before Home, native UI showed Processing image 1 of 3. After Home and tapping the app's SpringBoard icon to foreground, native summary showed **Batch interrupted**, Total 3 / Successful 1 / Partial 0 / Failed 0 / Canceled 1 / Not processed 1. The 24 MP second input was canceled; the third remained unprocessed. No automatic restart was observed. Evidence `iphone-before-background.txt`, `iphone-foreground-outcome.txt/png`. The intermediate `iphone-after-background` capture is SpringBoard, not the final outcome. This adds iPhone lifecycle/UI accounting evidence; output-file reconciliation, iPad lifecycle and process-termination cases remain unverified.
- **Mac native limitation persists:** a separate disposable signed QA copy with unique `com.kltimage.batchqa.local` identity also returned `cgWindowNotFound` through native capture despite appearing in app inventory. Its empty process PID 95770 was terminated; unrelated PID 10436 was untouched. No global preference or test service was changed. Native Mac focus/close/quit/VoiceOver checks remain unverified.

Private native delta review: https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-batch-review/qa-retry-1/ . Source/native ownership released to the orchestrator for focused correction. No remaining broad acceptance exercise was continued around the memory blocker.

## Initial findings — resolved by correction 1

The following reproductions preserve the initial failing evidence; they do not describe the corrected interface.

### QA-F1 — RESOLVED: Mobile batch controls are smaller than the approved 44-point targets

On the iPhone 17 Pro simulator at its original Medium content size, the native accessibility **Button** elements for Add files, Add from Photos and Clear are 15 points high; Choose/Change folder is 15; Close is 33; Start and Return to setup are 32. These measurements are the control bounds, not the separate StaticText children. The iPad Pro 13-inch (M5) reports 16.5-point Add/Photos/folder buttons and 32-point Start. This fails the design's explicit mobile target requirement and QA-24/NFR-04 acceptance.

Reproduce: launch → Workspace actions → Batch processing; inspect the enabled Add files/Photos controls, choose a destination, and inspect Start/Return. `SharedBatch/BatchView.swift:36`, `:136`, `:203`, `:259`, `:265`, `:269` reuse unpadded buttons or the desktop 32-point action styles (`KLTImage/DesignSystem.swift:80`, `:102`). Include the remove target, which is explicitly only 32 points wide at `BatchView.swift:119`, in the corrective sweep. Verify actual accessible/tappable bounds of every mobile action after correction, preserving Mac presentation.

Evidence: `qa-evidence/iphone-native-batch-empty.txt`, `ipad-empty.txt`, `iphone-calculated-success.txt`, and the screenshots. Maximum accessibility text was also exercised: content remains scrollable and the footer is reachable, but the heading visibly truncates to “Batch process…” and Add from Photos truncates at the largest size. The requested fix should keep essential control names and status visible at those sizes too. Simulator content size was restored to Medium.

### QA-F2 — RESOLVED: Destination labels expose internal file-provider paths

Choose **On My iPhone** in the native Files folder picker, then complete a Photos-input batch. Setup and outcome display `/Users/developer/Library/Developer/CoreSimulator/Devices/.../Containers/Shared/AppGroup/<UUID>/File Provider Storage` and its run subfolder. That is not the user-facing location selected in Files. On a device it would expose similarly opaque container paths. FR-14 and the approved destination presentation require a readable location.

`SharedBatch/BatchView.swift:202` and `:216` directly render `URL.path`. Preserve the granted URL internally but present a native/provider-friendly location and the actual run-folder name. Evidence: `iphone-calculated-success.txt`, `iphone-calculated-record-success.txt`, `iphone-folder-browse.png`, `iphone-calculated-record-success.png`.

## Verification scope and results

During the initial verification below, production code was unchanged. Correction 1 and its delta checks are distinguished above. Untracked new feature sources were read in addition to the tracked base diff. Full xcodebuild suite runs were attempted on both platforms; the Mac test-service failure required direct signed XCTest execution. No test failures were hidden by the workaround.

| Run | Result | Full evidence |
|---|---|---|
| Current iPhone 17 Pro, iOS 26.4.1, full Debug suite | **82 passed, 0 failed, 0 skipped** | `qa-evidence/iphone-full.log`, `iphone-summary.json`; `/tmp/klt-batch-qa-iphone.xcresult` |
| Current iPad Pro 13-inch (M5), iOS 26.4.1, full Debug suite | **82 passed, 0 failed, 0 skipped** | `ipad-full.log`, `ipad-summary.json`; `/tmp/klt-batch-qa-ipad.xcresult` |
| Mac Debug core, signed direct XCTest | **64 passed, 0 failed** | `mac-debug-core-direct.log` |
| Mac Debug hosted app, signed direct XCTest injection | **39 passed, 0 failed**, including 8 batch tests | `mac-debug-app-direct-library-path.log` |
| Mac optimized ReleaseTests core, signed direct XCTest | **66 passed, 0 failed** | `mac-release-core-direct.log` |
| Mac optimized ReleaseTests hosted app, signed direct XCTest injection | **39 passed, 0 failed**, including 8 batch tests | `mac-release-app-direct.log` |
| Mac full Debug / ReleaseTests xcodebuild test runs | **Blocked before first test**, builds completed | `mac-debug.log`, `mac-release.log`, `mac-debug-session-stall.log`, `mac-testmanagerd-stall.log`, `mac-debug-stall-sample.txt` |
| Mac UI XCTest suite | **Not executed** because of test-service blockage | Six existing UI tests remain unverified at current code |
| 24 MP optimized benchmark | **Pass**: affine 4.151 s, replay 1.978 s; RGB/Lab including fingerprint and record max 2.774 s; median complete 2.091 s | `mac-release-core-direct.log` |
| Diff whitespace validation | Pass | `git diff --check` |

The Mac xcodebuild diagnostics begin with **unhosted KLTCoreTests**, obtain a socket, then report **“XPC connection for control was invalidated”** while initiating the testmanagerd session. No app test had launched. Exact stalled xcodebuild PIDs were terminated after collecting diagnostics. The preexisting unrelated KLT app PID 10436 (`/private/tmp/klt-rgb-zoom-debug/...`) was preserved; there is no evidence it caused the failure. A separate current QA app was opened, but Computer Use could not capture it (`cgWindowNotFound`); only that QA process was terminated afterward. No machine-wide service, Xcode selection, keyboard/accessibility preference, or unrelated app was changed.

The first direct app diagnostic lacked the XCTest Swift library search path and exited 83 before test loading. Adding the explicit per-process `DYLD_LIBRARY_PATH` produced the complete passing runs above; the initial diagnostic remains in `mac-debug-app-direct.log`. Neither run disabled signing. This is app/core test evidence, **not** a substitute for native Mac keyboard/VoiceOver or UI-test evidence.

Baseline check with the actual empty failing-test set returned `RESULT new=0 known=0 resolved=0 baseline=2026-10-02T00:18:52Z`; `baseline-check.txt` preserves it. Baseline was not re-recorded. Incomplete checks and acceptance defects prevent a QA pass despite zero failed executed tests.

## Native evidence

Verified reachable private review: https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-batch-review/qa-2026-10-03/ . Index and linked native result image returned HTTP 200 with normal HTTPS certificate verification. Files were added beneath the existing private review directory; the approved index, service, routes, and public exposure were not changed.

On iPhone, opened Batch from an empty workspace, canceled Files selection, selected the known hummingbird fixture using native Photos, chose **On My iPhone** using native Files, and ran Calculate RGB/covariance/PNG with JSON off. Result: Batch complete, exactly one successful item, 1280×720 output matching the source dimensions, no JSON. Returned to setup, enabled JSON and explicitly started again: a fresh run folder contains the same image bytes plus a 1,959-byte version-1 analysis record. Both outcome filenames exist. `native-output-audit.json` records exact file lists, sizes and hashes. Both PNG hashes are `e8603e8620479a2df34c009c5d60caef9df8eb9726849004edd1340d394dadc2`.

On iPad, entered from an empty workspace, switched to replay and verified “No saved transforms yet” plus corrective copy and disabled Start. Captured native accessibility trees and screens. There was no library-wide Photos permission request. Local simulator Files publication works for the exercised destination; this does not establish third-party/cloud-provider behavior.

## Acceptance criteria verification

“Partial” means the named evidence passed but the rest of that criterion is not established. It is not a waiver or a claim that the remaining behavior works.

| Criterion | Result | Evidence and remaining gap |
|---|---|---|
| QA-01 Entry/workspace preservation | Partial | Native empty iPhone/iPad entry and dismissal; lease test and existing workspace regressions pass. Populated source/result/record/region/geometry preservation through complete/fail/cancel/dismiss on all three platforms is not demonstrated. |
| QA-02 Native intake | Partial | Native iPhone Photos JPEG fixture and Files picker cancellation; file type/staging validation tests. Full mixed JPEG/PNG/TIFF/HEIC native Files selection on Mac/mobile and repeated native order still unverified. |
| QA-03 Bounds/setup | Partial | 100-entry model cap and rejection pass; empty Start disabled in native mobile. Complete 100-row native review, remove/clear and existing-list picker cancellation not all exercised. |
| QA-04 Sequential/stale intake | Partial | 100-item test sees peak acquisition 1, no prior-item private files; delayed canceled acquisition drains without starting second item. Fixture is 4×4, so it is not a full-resolution memory profile or actual late Photos callback test. |
| QA-05 Pixel/encoded bounds | Partial | Existing core/import regressions and parameterized byte-limit/growing-source staging pass. Exact Mac/mobile pixel-limit and 1GiB/256MiB batch boundary matrix was not run. |
| QA-06 Stable source/identity | Partial | Changed-source/link rejection and mismatched identity predicate pass. Queued replacement/revoked provider and stale completion at actual publisher/UI boundary not fully injected. |
| QA-07 Temp/output bounds | Partial | Encoder cap, temp quota/debt and 100-item cleanup tests pass. Exact per-artifact/platform ceilings and persistent prior-output behavior at all budget failures need tests. |
| QA-08 Defaults/invalid replay | Partial | Model defaults and native empty-replay corrective state pass. Reopen defaults across platforms and invalid/deleted/unsupported library recipes need dedicated checks. |
| QA-09 Calculation parity | Partial | RGB/Lab/curated covariance/correlation pixels and records match direct core in shared batch test. User-defined space, two calculated sources and warning-success batch cases not all covered. |
| QA-10 Replay parity | Partial | Region-origin RGB/Lab/curated frozen replay on different target dimensions and diagnostics match. Whole-image recipe and multi-target frozen field immutability need explicit batch coverage. |
| QA-11 Immutable request | Partial | Engineer correction adds frozen replay through library rename/removal and setup edits; focused suite passes on all three platforms. Independent native mutation matrix remains unverified. |
| QA-12 Destination/start failure | Partial | QA-F2 resolved: friendly location and run-folder labels independently verified. Engineer adds destination-loss test; native provider-specific refusal/revocation matrix remains unverified. |
| QA-13 Collision/naming | Partial | Between-image/JSON collision test preserves sentinel and paired names; 100 duplicate inputs get distinct names. Long/empty/Unicode names and preexisting run-folder matrix incomplete. |
| QA-14 Export/alpha | Partial | Encoder PNG/TIFF/JPEG byte parity and existing orientation/alpha regression pass; native PNG dimensions exact. Native rotated JPEG/HEIC and transparent batch format matrix not exercised. |
| QA-15 Optional records | Partial | Native JSON off/on, version-1 artifact and identical PNG bytes; full core golden codecs pass. Native/custom/curated/replay artifact matrix still incomplete. |
| QA-16 Partial commit | Partial | Existing publisher boundary tests pass; Engineer adds image-committed/JSON-failed runner/model coverage. Native partial-state rendering still unverified. |
| QA-17 Capacity/shared failures | Partial | Engineer adds passing low/unknown capacity and destination-access-loss tests. Native provider failure matrix remains unverified. |
| QA-18 Progress/item failures | Partial | Valid/corrupt/valid runner continues and native success accounting correct. Unreadable/unsupported/warning mixed native phases not all exercised. |
| QA-19 Cancellation races | Partial | Delayed acquisition cancellation and publication boundaries covered; one-second visible acknowledgment and separate calculation/encoding/active commit UI cancellation not timed. |
| QA-20 Lifecycle | Partial | Actual iPhone active-run Home→app-icon foreground yields interrupted1-success/1-canceled/1-unprocessed summary. iPad, process termination and Mac focus/close/quit remain unverified. |
| QA-21 Final accounting | Partial | Native all-success counts/files verified and model/runner statuses tested. Warning/partial/interruption/destination-stop full summaries not all rendered and reconciled. |
| QA-22 New attempt | Partial | Native Return to setup retains selection and explicit second Start creates fresh folder with prior output intact. Cross-platform dismiss/reopen reset and changed method/destination cases incomplete. |
| QA-23 Cleanup | Partial | Durable debt/reinitialization, wrong-folder rejection and saved sentinel preservation pass. Actual process termination/grant-loss, private cleanup and all receipt crash windows not exercised. |
| QA-24 Accessibility/layout | Partial | QA-F1 observed defects resolved: actual mobile bounds, edge taps and largest text independently checked. Mac keyboard/VoiceOver and progress announcements remain unverified. |
| QA-25 Regression/resources | **Fail** | QA-F3: full-resolution settled footprint614MB short→2.18GB long. Original suites/benchmark remain green in their recorded scope; Mac UI suite blocked. |
| QA-26 Privacy/review | Pass (scoped) | No new network client/Photos writes/bookmarks/queue/history found in batch code; anonymous receipts only; native picker selections and verified existing tailnet HTTPS review. Physical-device/provider/TestFlight acceptance expressly unclaimed. |

## Required next step

Return to The Engineer for **QA-F3**. Diagnose the retained frame-sized allocations and satisfy the approved per-item memory lifetime requirement; preserve full image resolution and output behavior. Re-run the focused diagnostic and relevant changed paths, then resume remaining acceptance evidence. QA-F1/QA-F2 are resolved. Do not approve or ship on this report. The Guide owns deterministic retry accounting and routing.

## Verification limitations

No physical device was enumerated, inspected, connected to, launched, or tested. Native cloud-provider semantics and TestFlight installation remain unverified by design. No Release distribution binary, signing/notarization, upload or publication was performed; optimized ReleaseTests evidence is not distribution verification. No full suite was silently replaced with an all-pass claim: the Mac UI bundle remains explicitly blocked. A single opt-in QA memory diagnostic was authorized and added; it is excluded unless explicitly compiled with BATCH_QA_MEMORY.

## Convention flags

- Preserve a documented per-process native simulator automation path so a machine-wide Xcode selection cannot silently turn UI acceptance into unit-test-only acceptance.
- Check control accessibility bounds, not just readable text, when reusing Mac button styles on mobile.
