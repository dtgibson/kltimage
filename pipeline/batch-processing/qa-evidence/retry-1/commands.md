# QA correction 1 verification commands

Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` per process. No global Xcode change.

## Opt-in 24 MP memory diagnostic

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project KLTImage.xcodeproj -scheme KLTImage -configuration ReleaseTests \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/klt-batch-qa-memory \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG BATCH_QA_MEMORY' build-for-testing
```

Build log: `memory-build.log`. Build succeeded. Existing project signing retained.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  DYLD_FRAMEWORK_PATH=/tmp/klt-batch-qa-memory/Build/Products/ReleaseTests:/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks \
  DYLD_LIBRARY_PATH=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib \
  DYLD_INSERT_LIBRARIES=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/libXCTestBundleInject.dylib \
  XCInjectBundle='/tmp/klt-batch-qa-memory/Build/Products/ReleaseTests/KLT Image.app/Contents/PlugIns/KLTImageTests.xctest' \
  XCInjectBundleInto='/tmp/klt-batch-qa-memory/Build/Products/ReleaseTests/KLT Image.app/Contents/MacOS/KLT Image' \
  '/tmp/klt-batch-qa-memory/Build/Products/ReleaseTests/KLT Image.app/Contents/MacOS/KLT Image' \
  -XCTest KLTImageTests.BatchProcessingTests/testQAFullResolutionShortAndHundredItemMemory
```

Result: one test, one memory assertion failure, 216.805 seconds. `memory-24mp.log` preserves complete output. Test-only process PID96087 finished naturally. Read-only samples near long-run item80:

```sh
vmmap -summary 96087
heap -s 96087
```

No pressure-relief experiment or repeat 100-image run; orchestrator requested immediate hand-back after the completed run. Assertion compares settled physical footprint, independently of `resident_size_peak`. Sandbox-extension warnings refer to not-yet-created intended output names; all103 outcomes and final200-artifact/dimension assertions passed. CSV is extracted without modifying raw log.

## Native correction and lifecycle checks

Existing `../simulator-ui.py` wraps AXe with per-process Xcode settings. Only local iPhone17Pro UUID068373BA-E6B6-4640-B923-26B8BDB472DB and iPadPro UUID7816C5F3-F485-40BB-A6C6-C86BE97B3287 used. No physical-device discovery or access.

- iPhone Return edge (26,782) activates; independent setup bounds in `iphone-return-edge.txt`.
- iPad native JSON row edge (252,589) toggles 1→0→1; snapshots preserve both values.
- iPhone content size accessibility-extra-extra-extra-large screenshot recorded, then restored to medium.
- Upsampled known hummingbird fixture to6000×4000 JPEG with `sips --resampleHeightWidth 4000 6000` and added to these explicit simulators using `simctl addmedia`.
- iPhone selected small/24MP/small Photos sources and retained native Files destination. Started via batch-start; snapshot Processing1of3; pressed native Home. `simctl launch` alone did not foreground the app; intermediate screenshot is SpringBoard. Tapped observed SpringBoard KLT Image icon to foreground and captured interrupted summary1saved/1canceled/1unprocessed. No output-file reconciliation performed for this run.
- Created disposable /tmp/KLT Batch QA.app from current QA Debug build, changed only copied bundle identity to com.kltimage.batchqa.local, re-signed with existing entitlements. Unique copy still cgWindowNotFound despite inventory recognition. Terminated only its empty PID95770 and verified absent. Unrelated PID10436 preserved.

Current native/source ownership released. UI remains on interrupted iPhone outcome and iPad batch setup. No current QA batch process remains active.

Private review verification: index, iphone-largest-text.png and iphone-foreground-outcome.png each returned HTTP200 over normal certificate-verified HTTPS at https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-batch-review/qa-retry-1/ . Existing private service/routes/root index unchanged. Final git diff --check passed.
