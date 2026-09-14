# Replacement Image Crash

## What this does

- Keeps the current source, accepted result and analysis record available while a replacement image decodes. Canceling the import or rejecting an unreadable replacement leaves that workspace unchanged.
- Installs a successfully decoded replacement as one main-actor state change, gives it a fresh source generation and analysis job, clears the prior result, and resets image-specific selection, comparison, reveal, zoom and pan state.
- Restarts an analysis that was interrupted by a canceled or failed replacement instead of restoring a `.processing` phase with no live task.
- Revalidates both image and analysis-record export captures after their save panels close. If another import or analysis took ownership meanwhile, the stale export is rejected visibly without canceling that operation or leaving the workspace in `.exporting`.
- Rejects new image and analysis-record exports visibly while a replacement import owns the workspace operation slot. The preserved result remains visible, the import continues through analysis, and ordinary exports resume when the workspace is ready.
- Passes the source unwrapped by `ContentView` into `ComparisonCanvas`, so the canvas renders a captured non-optional source and never force-unwraps mutable model state.
- Adds deterministic decode, analysis and delayed-export coverage for ordinary replacement success, cancellation, decode failure, overlapping opens, stale analysis completion, both stale export paths, exports captured after import begins and safe rendering in every comparison mode.

## How to test

Run the focused Debug replacement tests:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project KLTImage.xcodeproj -scheme KLTImage \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .derived-data/replacement-debug \
  -only-testing:KLTImageTests/MethodImportAndWorkspaceTests
```

Run the same focused tests in the optimized test configuration:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project KLTImage.xcodeproj -scheme KLTImage \
  -configuration ReleaseTests \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .derived-data/replacement-release-tests \
  -only-testing:KLTImageTests/MethodImportAndWorkspaceTests
```

Build the Debug app:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build -project KLTImage.xcodeproj -scheme KLTImage \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .derived-data/replacement-build-debug \
  CODE_SIGNING_ALLOWED=NO
```

## Notes for reviewer

- The retained-during-decode behavior already present at HEAD is preserved; this change does not reintroduce clear-before-decode.
- Import operation UUIDs still reject superseded decode callbacks. Source generation, request key and job UUID checks still reject stale analysis callbacks.
- Save-panel captures carry the operation UUID that owned the result when the panel opened. The model rechecks that UUID plus the result/job identity before starting either export; export callbacks also require matching operation and export-kind ownership before changing phase.
- The captured-export boundary refuses to take ownership while `phase == .importing`, before either export implementation can cancel the shared operation task.
- The injected calculated-analysis closure is an internal deterministic test seam. Production defaults to the existing local `ImagePipeline.enhance` path; replay, sandboxing, export encoding and persistence remain local and unchanged.
- Native panel cancellation makes no model mutation because `openImage` is called only after the panel returns a URL. Model cancellation, failure and delayed-confirmation behavior are covered at the captured-export boundary without automating AppKit panels.
