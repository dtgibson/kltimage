# Engineer correction — QA retry 2

2026-10-03. Scoped correction to the full-resolution batch memory failure. No stage, handoff, or lifecycle transition.

## Change and ownership

`KLTCore/ImagePipeline.swift` now allocates each full-frame RGBA buffer with checked, explicitly owned zeroed storage. A shared helper initializes raw bytes before transferring the allocation to `Data(bytesNoCopy:deallocator:.free)`. This covers decode, baseline enhancement, frozen working-space rendering, RGB rendering, Lab rendering, and JPEG white-background compositing. The existing ImageIO thumbnail decoder, EXIF transform, color conversion, interpolation, numerical loops, rounding, alpha behavior, and JSON codecs remain unchanged. The baseline identity path reuses source bytes without making an unused output allocation.

The helper frees its allocation when initialization throws (including cancellation), then rethrows the original error. On success, Data owns the single free, including downstream cancellation and image-provider failure. Decoder CGContext lifetime ends in a separate non-inlined function before ownership transfer. JPEG byte-count arithmetic is checked without imposing a new export pixel ceiling. All other output counts come from the validated decoded RGBA data.

The runner retains the existing per-item autorelease pool. Result rows still retain only outcome metadata, not images. No allocator-pressure API, forced cache purge, dimension reduction, quality reduction, or math change was added.

## Evidence and rejected alternatives

Evidence: `implementation-evidence/retry-2/`, with independent read-only allocation review in `reviewer/`.

- QA's original 24 MP run ended around 2.18 GB, compared with a three-item maximum around 614 MB. Heap/vmmap showed approximately 1.8 GB resident/dirty in the purgeable allocation zone; the zone name alone did not establish reclaimability.
- The existing thumbnail decoder drawn into Data reproduced growth. Standalone decoder allocation ownership fixed decode-only, but production decode plus enhancement still grew from 330 MB to 932 MB over six images. One full batch run with only that partial correction failed and is preserved as `mac-app-and-memory.log`.
- Independent probes isolated the overlap: a second 96 MB Data allocation, even without a second CGImage/draw/encoder, restored the growth. Explicit ownership of both buffers was bounded. A Data-only control without ImageIO/CoreGraphics was also bounded. These observations identify an allocation/render interaction; they do not prove a generic Foundation leak or a private CoreGraphics root cause.
- The final production decode + enhancement + bounded PNG encoder probe stays at 332,547,008–336,266,872 bytes over six 24 MP images (`isolation-all-owned-encode.log`).
- Direct full-resolution image decoding plus explicit orientation was evaluated and rejected: 86 of 384 comparisons differed, including 16-bit transparent PNG and HEIC cases. No tolerance was relaxed. No direct-decoder/orientation replacement remains in production. Diagnostic logs preserve those failures; they are not final-candidate results.
- `invalid-prebuild-enhance.log` and `invalid-prebuild-encode.log` launched an older diagnostic executable while its rebuild was unfinished. They are invalid evidence and were superseded by the explicitly named `isolation-owned-*.log` runs after successful compilation.

## Regression coverage

Added a frozen reference for the old thumbnail/CGContext decoder: 384 exact byte comparisons across PNG/TIFF/JPEG/HEIC, sRGB/Display P3/Adobe RGB, 8/16-bit source fixtures, alpha/no-alpha, and all eight EXIF orientations. Existing golden source/output bytes, scientific tests, canonical JSON, export and replay checks remain unchanged.

The opt-in Mac memory test now compares both the first ten and last ten samples of the 100-image queue with the **three-image** warm-up maximum plus 64 MiB. The former ten-image warm-up could conceal retained full frames. The test also requires all outputs successful, 200 saved image/JSON files, original 6000×4000 dimensions, empty private staging, and no cleanup debt.

The diagnostic ReleaseTests build overrides compilation conditions per command with `BATCH_QA_MEMORY` and no DEBUG, enabling the existing release-only core performance tests. This is not a project-configuration edit or the canonical ReleaseTests configuration. One app test using DEBUG-only fault hooks is conditionally excluded in this diagnostic and in the canonical optimized Mac test bundle, whose test target does not define DEBUG; both mobile Debug batch suites exercise it. The pre-correction Mac Debug suite also passed this test in retry 1. Shipping Release remains free of both flags.

## Verification

All checks below ran against the final six-buffer ownership change. The earlier `*-regression.log` and `*-shipping-release.log` files without `all-owned` are partial-candidate evidence, superseded by these results.

- Optimized Mac core: **67 passed**, including the 384-case decoder parity matrix, exact Build 2 golden output, canonical JSON, and 64 MP replay incremental-memory check. `mac-all-owned-core.log`.
- 24 MP benchmark run without concurrent heavy tests/builds: complete median **1.791 s**, slowest of the eight recorded matrix cases **2.476 s**, affine calculation **3.176 s**, frozen replay **1.582 s**, fingerprint/record overhead **2.23%**. All required bounds pass.

- Optimized Mac app: **43 passed** including the opt-in 3+100-item, 24 MP memory test. Three-item maximum **374,032,040 bytes**, first-ten maximum **378,129,408**, last-ten/final **258,428,192**. All 100 outcomes succeeded, all 200 image/JSON files were reconciled, original dimensions were checked, and no temporary files or cleanup debt remained. `mac-all-owned-app-memory.log`, `final-memory-verification.json`.
- Both early and late live heap/vmmap snapshots report **246.4 MiB physical footprint**, **635.8 MiB physical-footprint peak**, and **512 KiB resident/dirty** in the purgeable zone. That zone still reserves approximately **2.9 GiB virtually**; `resident_size_peak` reached **3,660,775,424 bytes** and plateaued. The correction removes the observed multi-gigabyte dirty retention; it does not eliminate all framework reservations. `all-owned-memory-{vmmap,heap}-{early,late}.txt`.

- Canonical Mac ReleaseTests configuration: build succeeded and focused batch suite **11 passed** (`mac-canonical-{build,batch}.log`). Its app target defines DEBUG, but its test target does not; the DEBUG-only fault-injection test is intentionally excluded here. No configuration file was changed for this retry.
- iPhone Simulator: full mobile core **65 passed** (including the 384 parity cases) and batch **12 passed** (`iphone-all-owned-regression.log`).
- iPad Simulator: decode-policy **3 passed** (including the 384 parity cases) and batch **12 passed** (`ipad-all-owned-regression.log`).
- True shipping Release: Mac and generic iOS Simulator builds succeeded; neither DEBUG nor BATCH_QA_MEMORY compiler definitions nor test-fault/memory-test symbols are present. `mac-all-owned-shipping-release.log`, `ios-all-owned-shipping-release.log`, `final-shipping-release-audit.json`. This verifies Simulator compilation, not an iOS distribution archive.
- `git diff --check` passed. Retry-only core changes are captured in `final-allocation.diff` against the pre-memory-correction source.

## Reproduction

Use per-process `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for all commands. The diagnostic Mac build is:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KLTImage.xcodeproj -scheme KLTImage -configuration ReleaseTests -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/klt-batch-retry-2-release SWIFT_ACTIVE_COMPILATION_CONDITIONS=BATCH_QA_MEMORY build-for-testing
```

After successful build completion, the signed direct XCTest commands in `qa-evidence/commands.md` apply with `/tmp/klt-batch-retry-2-release` as DerivedData. Run the core bundle once with no filter for the 67-test suite, then the hosted app once with no filter for all 43 tests including the memory diagnostic. Do not run heavy builds/tests alongside the core benchmark or memory run. The canonical Mac check uses `/tmp/klt-batch-qa-release`, no compilation-condition override, and hosted-app filter `-XCTest KLTImageTests.BatchProcessingTests`.

Mobile commands use `/tmp/klt-batch-qa-ios`, Debug, `-parallel-testing-enabled NO`, and only the authorized destinations: iPhone `068373BA-E6B6-4640-B923-26B8BDB472DB`, iPad `7816C5F3-F485-40BB-A6C6-C86BE97B3287`. iPhone selectors are `-only-testing:KLTCoreIOSTests -only-testing:KLTImageIOSTests/BatchProcessingTests`; iPad selectors are `-only-testing:KLTCoreIOSTests/IOSDecodePolicyTests -only-testing:KLTImageIOSTests/BatchProcessingTests`.

Shipping builds use `-configuration Release`, no compilation-condition override, scheme KLTImage with `platform=macOS,arch=arm64` and DerivedData `/tmp/klt-batch-retry-release-mac`, or scheme KLTImageIOS with `generic/platform=iOS Simulator` and DerivedData `/tmp/klt-batch-retry-release-ios`.

## Scope and remaining acceptance

Independent Tester owns acceptance of the final memory correction and the remaining native lifecycle/provider behavior. The previously accepted actual iPhone background/foreground outcome (successful 1, canceled 1, unstarted 1) remains valid and was not repeated by the Engineer. No physical device was enumerated or used. Unrelated Mac app PID 10436, global Xcode/accessibility settings, tailnet preview services/routes, release artifacts, pipeline state and telemetry were preserved. No distribution archive, TestFlight upload, or production publication was performed.
