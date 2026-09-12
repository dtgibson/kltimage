# Strategic Brief — Analysis Controls

**Feature:** analysis-controls
**Date:** 2026-09-11
**Stage:** 1 — The Strategist

## What We're Building

Extend the shipped decorrelation-stretch workflow with three explicit analysis choices:

- **Color space:** RGB or Lab.
- **Matrix mode:** covariance or correlation.
- **Statistical sample:** the whole image or one user-selected rectangular region.

The chosen statistics still drive an enhancement of the entire image. The unchanged source remains available for comparison, and the latest completed result remains exportable at full resolution through the existing local workflow.

## Why Now

The narrow RGB-covariance baseline has proven the complete import, transform, comparison, and export path. The next product risk is no longer whether KLT Image can perform a useful decorrelation stretch; it is whether users can keep irrelevant background pixels from controlling the result and choose an analysis basis appropriate to the color structure they are examining.

These controls belong in one build because they describe one coherent method. Color space defines the variables, matrix mode defines how those variables are normalized, and sampling defines which pixels establish the transform. Shipping them together gives users a small, legible analysis system rather than a sequence of partially compatible modes.

## The User Problem

Whole-image RGB covariance can hide or distort the subtle subject variation a user cares about:

- A large or colorful background can dominate the statistics for a bird or feather.
- RGB channel values are strongly coupled to display encoding and do not separate lightness from chromatic axes.
- Covariance gives higher-variance channels more influence, which is not always the comparison a user intends.

The user needs to choose the basis of the enhancement without losing the immediate visual relationship between the source and the result. They should be able to answer, at a glance, “What space, matrix, and pixels produced this view?” without being asked to interpret raw transformation data.

## Strategic Outcome

KLT Image becomes a focused visual analysis tool rather than a single preset. A technically informed user can test the same photograph across a compact set of understandable methods, isolate the subject as the statistical sample, and compare the resulting full-image enhancement with the unchanged source.

This build is successful if the new flexibility improves exploration while the existing RGB + covariance + whole-image path remains an exact, trustworthy baseline.

## Success Criteria

- A user can independently choose RGB or Lab processing, covariance or correlation, and whole-image or selected-region sampling.
- The current combination is always visible in plain language and is represented accurately in status and method guidance.
- Choosing Lab performs the analysis and transform in a documented Lab working representation, then produces a valid displayable result while preserving the source and its alpha behavior.
- Choosing correlation uses a correlation matrix derived from the selected color-space variables, with safe handling for zero or near-zero channel variance.
- A user can create, move, resize, replace, and clear one rectangular sample region without altering or cropping the source.
- The sample region is stored in source-image coordinates, remains aligned through zoom, pan, and comparison changes, and is never burned into the enhanced image or export.
- Region statistics alone determine the transform, but that transform is applied to every pixel in the full-resolution image.
- An invalid, too-small, or insufficiently varied region never silently falls back to whole-image statistics. The app keeps the source safe and explains what the user needs to change.
- A changed analysis setting or region produces a new result without freezing the interface; superseded work cannot replace a newer requested result.
- Repeating the same source, settings, and region produces the same enhanced pixels.
- RGB + covariance + whole image preserves the shipped result as the regression baseline.
- All supported combinations preserve existing import, orientation, comparison, alpha, privacy, numerical-stability, cancellation, and full-resolution export guarantees.
- The existing 24-megapixel performance target remains the benchmark for a completed enhancement on supported Apple silicon.
- Controls and region editing have meaningful VoiceOver descriptions, visible focus, and a keyboard-operable path.
- Guidance continues to describe enhancements as exploratory visual evidence and warns that Lab conversion, normalization, noise, compression, and region choice can all affect the view.

## Scope

### Analysis method

- RGB and Lab working modes, with RGB remaining the default.
- Covariance and correlation matrix modes, with covariance remaining the default.
- Clear, concise explanations of how each option changes the analysis.
- Deterministic processing across all supported combinations.
- Safe conversion back to a displayable and exportable image when transformed Lab colors exceed the output gamut.

### Statistical sampling

- Whole-image sampling as the default and existing baseline.
- One axis-aligned rectangular sample region per open image.
- Direct creation and adjustment of the region over the image, with an accessible non-pointer path.
- Clear visual distinction between the sampled area and the full image receiving the transform.
- Validation and guidance for regions that contain too few useful pixels or too little color variation.
- Region reset when a different source image is opened; no saved or reusable regions.

### Existing workflow integration

- Automatic recalculation when an analysis choice or valid region changes.
- Original, Split, and Enhanced comparison with synchronized navigation.
- Full-resolution PNG, TIFF, and JPEG export of the latest completed enhancement.
- Local-only, cancellable processing with no accounts, uploads, or project history.
- Regression coverage for the shipped whole-image RGB covariance result and focused reference coverage for each new analysis dimension.

## Product Decisions

- Present the method as three separate choices—color space, matrix mode, and sample source—rather than opaque named presets.
- Keep RGB + covariance + whole image as the default and the exact compatibility baseline.
- Apply a region-derived transform to the whole image. Region selection is statistical sampling, not cropping, masking, or localized enhancement.
- Support one rectangular region in this release. Multiple regions, freehand shapes, and automated subject selection add interaction and interpretation costs without proving the core value.
- Recalculate from the immutable decoded source whenever the method changes; never chain one enhanced result into another.
- Never silently substitute a different color space, matrix mode, or sampling source when the chosen analysis is weak or degenerate.
- Preserve the selected method while the current image is open, but reset image-specific region geometry when the source changes. Saved settings and reusable analyses belong to later reproducibility work.
- Keep result interpretation visual. The UI may identify the active method and region, but it does not expose or export numerical matrices, eigenvectors, channel statistics, or reports in this build.
- Continue requiring explicit user action for image export, and export only the latest successfully completed result.

## Pressure Test

### Why this is a coherent feature

The surface area is bounded: two color spaces × two matrix modes × two sampling sources. Each choice addresses the same user question—what statistical model should reveal the color structure?—and all combinations share the shipped comparison and export workflow.

### Main risks

- **Scientific ambiguity:** “Lab” and “correlation” can sound inherently more accurate. Copy must describe them as alternative exploratory bases, not superior evidence.
- **Color conversion and gamut:** Lab processing introduces explicit conversion, reference-white, and output-gamut decisions. The architecture must document and test them so a mode label corresponds to stable behavior.
- **Degenerate samples:** Small, flat, transparent, clipped, or noisy regions can yield unstable statistics. Validation and bounded numerical behavior must be visible rather than masked by fallback.
- **Coordinate integrity:** A region drawn on a fitted, zoomed, panned, or split image must map exactly to source pixels. Selection geometry needs one canonical source-coordinate representation.
- **Combinatorial regression:** Eight visible analysis combinations can multiply defects. The core API and test fixtures should treat color space, matrix mode, and sample bounds as explicit inputs.
- **Stale asynchronous results:** Rapid control or region changes may overlap processing. Only the newest request may become the displayed or exportable result.

### Why not include reproducibility export now

Exposing transformation data adds a different promise: durable method records, serialization formats, numerical provenance, and quantitative comparison. Those requirements should be designed after the interactive analysis model is stable. This build makes the method explicit in the live workspace but does not create a saved analysis artifact.

## Out of Scope

- Exported transformation data, settings manifests, numerical reports, or quantitative comparisons.
- Saved or reusable matrices, regions, presets, or analysis sessions.
- Custom color spaces or user-supplied profiles.
- Enhancement-strength controls.
- Multiple, polygonal, freehand, feathered, or automatically detected sample regions.
- Cropping, masking, or applying the enhancement only inside the selected region.
- Batch processing.
- RAW decoding.
- Hue isolation or unrelated enhancement methods.
- Biological interpretation or claims that one method proves a feature is real.

## Dependencies and Guardrails

- Build on the independently testable `KLTCore` transform and keep image processing outside the app's presentation layer.
- Preserve the decoded source buffer unchanged and perform every recomputation from that source.
- Keep all image data and analysis local to the Mac.
- Use explicit, documented color-conversion and numerical-stability rules with reference fixtures.
- Retain the existing comparison context, full-resolution output, accessibility baseline, and fixed-light scientific visual system.
- Treat the next roadmap item, Reproducible analysis, as a separate build with its own strategy for method records and exported transform data.
