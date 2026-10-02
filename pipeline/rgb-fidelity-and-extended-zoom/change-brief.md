# Change Brief — RGB Fidelity and Extended Zoom

## What is changing
Strengthen the existing full-resolution RGB analysis/display/export path and raise the existing zoom ceiling to 1000% on iPhone, iPad, and Mac. Investigate the reported intermittent blocky RGB appearance with controlled fidelity comparisons before selecting a correction. Use one consistent maximum for buttons and pinch, preserving the existing fit-relative percentage meaning and interaction model.

## Why now
The user reports RGB results sometimes looking lower-resolution or blocky while Lab looks fine, and the iPhone's 400% ceiling prevents close inspection. Code confirms 400% mobile and 800% Mac ceilings. Static inspection finds full-frame per-pixel processing, not an RGB-specific downsample; the reported image-quality symptom has not yet been reproduced.

## User-facing impact
Existing comparison canvases can reach 1000% through current controls and gestures. Supported sources must retain their complete oriented pixel dimensions through calculation and export, and displayed detail must faithfully represent those results. Full resolution does not promise removal of compression artifacts already present in a source.

## Design pass
Not needed — this is numerical limit and correctness work within the existing presentation, with no visual design change. Preserve layout, labels, fit-relative zoom semantics, interpolation policy, and gesture ownership. Any proposed new viewing mode, smoothing treatment, or interaction redesign requires renewed scoping.

## Decisions touched
- “Ship the narrow RGB covariance foundation first” (2026-09-10): preserve the reproducible shipped arithmetic baseline unless a demonstrated defect requires an explicitly documented compatibility decision.
- “Keep results exploratory and local” (2026-09-10): distinguish amplified source compression/noise from resolution loss; no implicit denoising or scientific claims.
- “Keep full-frame processing within a fixed 64 MP boundary” (2026-09-11) and “Set independent mobile image limits” (2026-10-01): preserve fixed limits and reject over-limit images without reducing resolution.
- “Make reproducibility a versioned, local analysis protocol” (2026-09-12) and “Separate transparent working spaces from frozen transform recipes” (2026-09-13): preserve result provenance, existing protocol bytes, and frozen replay mathematics.
- “Coordinate competing canvas gestures through shared ownership” and “Treat image replacement as an atomic workspace transaction” (2026-09-14): retain registered geometry, gesture ownership, and result currency.

## Scope
Expected changes: `KLTImageIOS/IOSWorkspace.swift`, `KLTImageIOS/RegisteredCanvas.swift`, `KLTImage/WorkspaceModel.swift`, `KLTImage/ComparisonCanvas.swift`, a shared zoom-limit definition in `KLTCore`, and relevant core/app tests.
Conditional changes only when evidence supports them: `KLTCore/ImagePipeline.swift` for decode/render fidelity invariants, platform image rendering, and directly related regression fixtures.
Out of scope: new screens, new analysis modes, smoothing/sharpening, automatic source repair, changed working-space mathematics or recipe/schema semantics, persistence, higher image-size limits, and release-channel changes.

## What done looks like
Controlled fine-detail lossless and compressed-source comparisons distinguish source artifacts, RGB/Lab processing, export, and display; independently check mapped pixel values/detail as well as oriented dimensions, alpha, deterministic output, and unchanged source. Fix any reproduced loss of fidelity with a regression; explicitly retain an evidence gap if the reported symptom cannot be reproduced.
Buttons and pinch reach and clamp at exactly 1000% on Mac and local iPhone/iPad simulators; zoom-out, fit/reset, pan, source/result registration, sample geometry, and slider ownership remain correct at maximum zoom.
Required Mac Debug/optimized suites, iOS simulator checks, and Release 24 MP performance requirement pass or report concrete limitations; any shared review preview uses verified tailnet-only HTTPS. No physical device access or on-device acceptance claim.
