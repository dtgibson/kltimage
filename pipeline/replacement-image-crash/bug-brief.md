# Bug Brief — Replacement Image Crash
## What is broken
Image replacement has an unsafe split invariant: `ContentView` checks `source != nil`, but the already-mounted `ComparisonCanvas` later force-unwraps `model.source!`.
The affected clear-before-decode reload path can therefore publish `source == nil` before SwiftUI removes the canvas, producing a fatal nil-unwrap; cancel or decode failure also discards the prior image.
Current `openImage` retains the prior source during decode, but the force unwrap remains and ordinary Open Image has no replacement regression test, so the crash contract is not closed.
## Steps to reproduce
1. In an affected build, open image A, wait for **Result ready**, and leave Original, Side-by-Side, Slider, or Processed active.
2. Choose **Open Image** and select image B; the faulty path clears `source` before its detached decode completes while the comparison canvas is still mounted.
3. SwiftUI evaluates `ComparisonCanvas.originalPane`, `model.source!` traps, and the app exits; choosing a corrupt B or canceling also loses A on that path.
## Expected behavior
Keep A and its current result visible and exportable while B decodes, then atomically install B only after the current import succeeds.
Cancel or decode failure must restore A; a superseded import/analysis callback must not publish, and replacing during prior analysis must not restore a dead `.processing` phase.
The canvas must render from a safely unwrapped source rather than depending on a parent-view timing invariant.
## Blast radius
The shared `openImage` path serves the open panel, empty-workspace drop, and Apply to Another Image; all comparison modes reach the force-unwrapped original pane.
Operation UUIDs protect import callbacks and source-generation/request/job IDs protect analysis results, but replacement also touches method selection, region, comparison, record, export, zoom, and pan state.
Existing tests cover recipe-open cancellation/failure and superseded decodes, not ordinary successful replacement, the AppKit panel/drop flow, replacing during analysis, or the SwiftUI crash.
## What done looks like
An automated pre-fix regression reproduces the reload failure, while the fixed app repeatedly replaces A with B without a crash or transient loss of A.
Controlled tests cover success, cancel, corrupt input, overlapping opens, and replacement during analysis, proving stale decode/analysis completions cannot win.
Assertions verify A remains current through import failure/cancel and B alone receives fresh generation, request, result/record, whole-image selection, and reset presentation state after acceptance.
