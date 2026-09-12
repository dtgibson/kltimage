# PRD — Analysis Controls
**Feature:** analysis-controls
**Date:** 2026-09-11
**Stage:** 2 — The Planner
**Source:** strategic-brief.md (approved)

## Feature Overview

Analysis Controls extends KLT Image's shipped decorrelation-stretch workflow with independent choices for RGB or Lab processing, covariance or correlation analysis, and whole-image or single-region statistical sampling. Every valid combination enhances the full source image while preserving the existing comparison, local processing, accessibility, and full-resolution export guarantees.

## User Stories

> **US-01** — As an image researcher, I want to compare RGB and Lab analyses of the same photograph, so that I can explore color structure in either display-oriented or lightness-and-chroma variables.

> **US-02** — As a technically informed image analyst, I want to choose covariance or correlation, so that I can examine results with or without the original per-axis variance scale dominating the analysis.

> **US-03** — As a naturalist examining a subject against a distracting background, I want to calculate statistics from one selected rectangle, so that the subject rather than the background determines the enhancement applied to the full photograph.

> **US-04** — As a keyboard or VoiceOver user, I want to create and edit a sample region using source-pixel bounds, so that region sampling does not depend on precise pointer use.

> **US-05** — As a researcher comparing methods, I want the active color space, matrix mode, and sample source to remain visible, so that I always know which choices produced the result in view.

> **US-06** — As a photographer, I want every supported method to retain the source's comparison and export behavior, so that changing the analysis does not compromise the original or the full-resolution result.

> **US-07** — As a careful investigator, I want weak or invalid selections explained without hidden substitutions, so that I never mistake a fallback result for the analysis I requested.

## Functional Requirements

### Analysis Method

> **FR-01** — The app shall provide three independent analysis choices for an open image: color space (RGB or Lab), matrix mode (covariance or correlation), and statistical sample (whole image or selected region).

> **FR-02** — The app shall begin each launch with RGB, covariance, and whole image selected, matching the shipped workflow's defaults.

> **FR-03** — The app shall display the requested color space, matrix mode, and sample source together in plain language during processing and after completion; a completed result shall also remain associated with the exact choices that produced it.

> **FR-04** — RGB mode shall analyze and transform the oriented 8-bit sRGB working image using the shipped channel definitions and alpha behavior.

> **FR-05** — Lab mode shall convert the oriented sRGB color values to CIE 1976 L*a*b* using a D65 reference white before calculating statistics or applying the decorrelation transform.

> **FR-06** — Lab mode shall convert the transformed full-image result back to sRGB for display and export, map non-finite values to a processing failure, and clip finite out-of-gamut sRGB channels to the displayable range without changing alpha.

> **FR-07** — Covariance mode shall calculate the sample mean and sample covariance of the three variables in the selected color space and shall derive the decorrelation basis from that covariance matrix.

> **FR-08** — Correlation mode shall derive its matrix by normalizing each stable covariance term by the corresponding sample standard deviations, so stable color-space variables contribute on a unit-variance basis.

> **FR-09** — Correlation mode shall exclude zero- or near-zero-variance variables from normalization, leave excluded variables unamplified, identify the limited-variation condition to the user, and never divide by zero, emit non-finite values, or substitute covariance mode.

> **FR-10** — The app shall derive means, variances, matrix terms, and the decorrelation basis only from the active sample, then apply the resulting basis and component gains to every source pixel at full resolution.

> **FR-11** — Every recalculation shall start from the unchanged decoded source; no analysis combination shall use a previously enhanced result as its input.

> **FR-12** — The app shall support all eight combinations formed by two color spaces, two matrix modes, and two sample sources, subject only to the selected-region validation requirements in this document.

### Statistical Sample and Region Editing

> **FR-13** — Whole-image sampling shall include the same oriented source-pixel population used by the shipped RGB-covariance baseline, and selected-region sampling shall include only source pixels whose pixel centers fall inside the active rectangular bounds.

> **FR-14** — When selected-region sampling is chosen without an existing valid region, the app shall enter an awaiting-region state, explain that a region is required, and shall not calculate with whole-image statistics.

> **FR-15** — The app shall support exactly one axis-aligned rectangular region for the current source and shall let the user create, replace, move, resize, and clear it.

> **FR-16** — The app shall keep the region in oriented source-image pixel coordinates, constrain committed bounds to the source dimensions, and map the same bounds accurately through fit, zoom, pan, and Original, Split, or Enhanced presentation changes.

> **FR-17** — In addition to direct manipulation over an image pane, the app shall provide a fully keyboard-operable way to enter and edit the region's integer source-pixel X, Y, width, and height values, with the coordinate origin and valid ranges stated in the interface.

> **FR-18** — While selected-region sampling is active, the app shall show a clear non-destructive overlay for the sampled rectangle on every visible image pane, mirror the same source bounds in both Split panes, and distinguish the sample from the full image that receives the enhancement.

> **FR-19** — A committed selected region shall be valid only when it is inside the source, has positive width and height, contains at least four source pixels, and supplies at least one numerically stable color component in the requested color space and matrix mode.

> **FR-20** — If direct or numeric editing produces invalid, too-small, or insufficiently varied bounds, the app shall retain the attempted bounds for correction, state the specific problem, disable processing and export for that request, and never silently clamp a committed numeric value, expand the region, or fall back to another sample or method.

> **FR-21** — Switching from selected-region to whole-image sampling shall keep the current region available but visibly inactive for the current source; switching back shall reuse it if it remains valid, and Clear Region shall remove it.

> **FR-22** — Opening a different source image shall clear the previous region, switch sampling to whole image, reset comparison navigation, retain the current session's color-space and matrix choices, and process the new source with those visible choices.

> **FR-23** — The app shall not persist analysis choices or region geometry after the app closes and shall not provide saved regions, presets, or reusable analyses.

### Recalculation, Comparison, and Export

> **FR-24** — The app shall automatically request a new full-resolution enhancement when the user changes color space or matrix mode, changes to whole-image sampling, activates an existing valid region, or commits a valid region creation, move, resize, or numeric edit.

> **FR-25** — When multiple recalculations overlap, the app shall cancel or supersede older requests and shall allow only the newest request matching the current source, method, and region to become the current displayed or exportable result.

> **FR-26** — During recalculation, the app shall remain interactive, show a processing state with the requested method, mark any previously completed enhancement as updating rather than current, and disable export until the requested result completes successfully.

> **FR-27** — If recalculation fails or the current region becomes invalid, the app shall preserve the unchanged source and any prior enhancement for comparison, clearly mark the prior enhancement as not matching the current request, keep export disabled, and allow correction or selection of another valid method without reopening the image.

> **FR-28** — All analysis combinations shall preserve the decoded source buffer unchanged, shall exclude alpha as an analysis variable, and shall preserve each source pixel's alpha in the enhanced result.

> **FR-29** — Original, Split, and Enhanced comparison modes shall remain available for every completed result with synchronized zoom and pan, and region overlays shall never alter the source or enhanced pixel buffers.

> **FR-30** — Export Result shall export only the current successfully completed enhancement whose source, analysis choices, and region match the current request; it shall omit selection overlays and other interface decoration.

> **FR-31** — PNG, TIFF, and JPEG export shall retain the source pixel dimensions for every supported analysis combination, PNG and TIFF shall preserve source transparency, and JPEG shall retain the existing opaque export behavior.

> **FR-32** — The existing JPEG, PNG, TIFF, and HEIC import, orientation handling, readable input errors, explicit save destination, replacement confirmation, and operation-cancellation behavior shall remain available with the new analysis controls.

### Status and Guidance

> **FR-33** — The method details shall explain, in concise plain language, the active color-space variables, the distinction between covariance and correlation, the active sample source, that a selected region supplies statistics while the full image receives the transform, and the number of stable components or a limited-variation notice.

> **FR-34** — The app shall state that RGB, Lab, covariance, and correlation are alternative exploratory bases rather than ranks of accuracy, and shall warn that Lab conversion, normalization, output-gamut clipping, noise, compression, lighting, and region choice can affect the result.

> **FR-35** — The app shall not display or export transformation matrices, eigenvectors, per-channel statistics, numerical reports, settings manifests, or other reproducibility artifacts in this feature.

### Full-Frame Resource Boundary

> **FR-36** — The app shall support full-frame processing up to 64,000,000 source pixels. It shall reject declared first-frame dimensions above that limit, invalid dimensions, and overflowing pixel or RGBA byte counts before requesting a full-resolution ImageIO decode; it shall validate the decoder's actual output dimensions again before allocating its working buffer and show the 64-megapixel limit in the import error.

## Non-Functional Requirements

> **NFR-01 — Numerical correctness:** All supported combinations shall keep intermediate and output values finite for valid inputs and shall use documented scale-relative stability thresholds covered by reference fixtures.

> **NFR-02 — Baseline compatibility:** RGB + covariance + whole image shall produce pixel-identical output to the shipped implementation for the same decoded source, including transparent inputs and degenerate-image notices.

> **NFR-03 — Determinism:** Repeating a calculation with the same decoded source, analysis choices, and integer source-pixel region shall produce identical enhanced pixel bytes and the same validation outcome.

> **NFR-04 — Performance:** Each valid analysis combination shall complete a 24-megapixel enhancement within five seconds on a supported Apple Silicon Mac under normal load.

> **NFR-05 — Responsiveness:** Import, color conversion, statistical analysis, transformation, recalculation, cancellation, and export shall run without freezing controls or blocking normal Mac interaction.

> **NFR-06 — Accessibility:** Every analysis control, region-editing action, numeric region field, status, overlay meaning, validation error, and progress state shall have meaningful VoiceOver output, visible keyboard focus, and a complete keyboard-operable path.

> **NFR-07 — Visual consistency:** New controls, overlays, focus, errors, and status treatments shall follow the fixed-light scientific design system, remain legible under macOS light and dark system settings, and respect Reduce Motion.

> **NFR-08 — Compatibility:** The feature shall support macOS 14 or later on Apple Silicon and Intel Macs without changing the supported import or export formats.

> **NFR-09 — Privacy and security:** All source pixels, sample coordinates, statistics, and results shall remain local to the Mac; analysis and export shall make no network requests and shall retain the app sandbox's file-access boundaries.

> **NFR-10 — Testability:** Color conversion, covariance, correlation normalization, region inclusion, coordinate mapping, transform application, gamut handling, cancellation, and request supersession shall be independently testable outside the presentation layer using reference and synthetic fixtures.

> **NFR-11 — Memory safety:** The 64-megapixel product ceiling shall remain fixed across supported hardware rather than expanding from volatile free-memory readings. A 64-megapixel RGBA frame is 256 MB, leaving a conservative five-frame working-set budget of about 1.28 GB for source, result, decoder, flattening, and encoding storage on the lowest-memory supported Mac class.

## Out of Scope

- Exported transformation data, settings manifests, numerical reports, or quantitative comparisons, including the separate Reproducible analysis roadmap item.
- Saved or reusable matrices, regions, settings, presets, or analysis sessions.
- Custom color spaces, user-supplied color profiles, or a choice of Lab reference white.
- Enhancement-strength or component-gain controls.
- Multiple, polygonal, freehand, feathered, or automatically detected sample regions.
- Cropping, masking, or applying the enhancement only inside the selected region.
- Live recalculation during an uncommitted region drag or partially entered numeric bounds.
- Batch processing or multi-image comparison.
- RAW decoding.
- Hue isolation or unrelated image-enhancement methods.
- Biological interpretation or any claim that one method or result proves a feature is real.
- Exporting the sample-region overlay as part of an enhanced image.

## Open Questions

None — all decisions are resolved in this document.

## Success Metrics

| ID | What's Being Verified | Pass Condition |
|---|---|---|
| QA-01 | FR-01 — Independent analysis choices | With an image open, color space, matrix mode, and sample source can each be changed without forcing either of the other choices. |
| QA-02 | FR-02 — Launch defaults | A clean launch shows RGB, covariance, and whole image before and after the first image opens. |
| QA-03 | FR-03 — Method identity | Processing and completed states show all three requested choices, and a retained prior result is never labeled as if it used newer choices. |
| QA-04 | FR-04 — RGB working behavior | RGB reference fixtures use the decoded sRGB channel values and match the established alpha-analysis behavior. |
| QA-05 | FR-05 — Lab definition | Published sRGB-to-CIE-L*a*b* D65 reference colors match expected L*, a*, and b* values within the documented tolerance. |
| QA-06 | FR-06 — Lab return and gamut | Lab fixtures containing in-gamut, out-of-gamut, and non-finite transformed values respectively return expected sRGB, clip every finite channel to its valid range, or produce a readable failure while preserving alpha. |
| QA-07 | FR-07 — Covariance mode | For RGB and Lab reference samples, means, sample covariance, eigenvalue ordering, and orthonormal basis match reference values within tolerance. |
| QA-08 | FR-08 — Correlation mode | For RGB and Lab samples with three stable variables, the derived correlation matrix has unit diagonal and reference off-diagonal values within tolerance. |
| QA-09 | FR-09 — Unstable correlation variables | Zero- and near-zero-variance fixtures produce no division by zero or non-finite output, do not amplify excluded variables, show limited variation, and do not run covariance instead. |
| QA-10 | FR-10 — Region statistics, full-image transform | A fixture with distinct foreground and background proves that only in-region pixels determine the statistical plan while pixels inside and outside the region both receive the same plan. |
| QA-11 | FR-11 — Immutable recomputation | Returning to a prior method after other enhancements yields the same pixels as a fresh calculation from the decoded source. |
| QA-12 | FR-12 — Combination coverage | Each of the eight color-space × matrix-mode × sample-source combinations completes on a valid reference image and identifies the requested combination. |
| QA-13 | FR-13 — Sample inclusion rule | Border and subview fixtures include exactly those source pixels whose centers are inside the whole-image or selected bounds, with no view-space pixels entering the sample. |
| QA-14 | FR-14 — Region-required state | Choosing selected region without a region shows an actionable awaiting-region message, starts no analysis, and never produces a whole-image fallback. |
| QA-15 | FR-15 — Single-region operations | Pointer tests create, replace, move, resize, and clear one rectangle; no action can leave two active regions. |
| QA-16 | FR-16 — Coordinate integrity | A known source-pixel rectangle retains identical bounds and alignment after fit, zoom, pan, and every comparison-mode transition, including image edges. |
| QA-17 | FR-17 — Numeric region editing | Keyboard-only and VoiceOver tests set X, Y, width, and height to valid boundary values and communicate the coordinate origin and allowed range. |
| QA-18 | FR-18 — Overlay meaning | The active region is visible on every displayed pane, Split shows matching mirrored bounds, and the interface states that the full image—not only the rectangle—is enhanced. |
| QA-19 | FR-19 — Region validity | Regions with fewer than four pixels, zero area, out-of-bounds values, or no stable component are rejected; the smallest valid varied four-pixel region is accepted. |
| QA-20 | FR-20 — Invalid-region recovery | Each invalid-region class retains editable attempted values, explains the exact defect, disables processing and export, and performs no clamping, expansion, or fallback. |
| QA-21 | FR-21 — Inactive region reuse and clear | Switching to whole image preserves but visibly deactivates the region, switching back reuses it, and Clear Region returns selected sampling to awaiting-region state. |
| QA-22 | FR-22 — New-source reset | Opening another image clears region geometry, selects whole-image sampling, resets zoom and pan, retains color-space and matrix choices for the session, and processes only the new source. |
| QA-23 | FR-23 — No persistence | After quitting and relaunching, defaults are restored and no prior region, preset, or analysis session is available. |
| QA-24 | FR-24 — Recalculation triggers | Every listed committed method or region change starts exactly one request using the resulting current configuration; uncommitted drag and incomplete numeric edits start none. |
| QA-25 | FR-25 — Superseded work | A controlled out-of-order completion test proves that only the newest source/method/region request becomes displayed or exportable. |
| QA-26 | FR-26 — Updating state | During a deliberately delayed recalculation, controls stay responsive, requested choices and progress are visible, any prior result is marked updating, and export is disabled. |
| QA-27 | FR-27 — Failure recovery | A forced calculation failure and an invalidated region each leave the source and prior result visible, label the result as non-current, keep export disabled, and recover after a valid correction without reopening. |
| QA-28 | FR-28 — Source and alpha safety | Hashes of the decoded source remain unchanged across all combinations; alpha never changes the calculated color statistics and output alpha bytes match source alpha bytes. |
| QA-29 | FR-29 — Comparison regression | Every completed combination supports Original, Split, and Enhanced views with synchronized navigation, and buffer comparison confirms overlays alter no image pixels. |
| QA-30 | FR-30 — Current clean export only | Export is unavailable for processing, invalid, failed, or stale requests; a current result exports without region outline or interface decoration. |
| QA-31 | FR-31 — Format, dimensions, and transparency | Every combination exports PNG, TIFF, and JPEG at exact source dimensions; PNG/TIFF alpha bytes match the source and JPEG uses the existing opaque behavior. |
| QA-32 | FR-32 — Existing workflow regression | Supported-format, orientation, corrupt-input, save-destination, replacement-confirmation, and cancellation tests pass with the controls present. |
| QA-33 | FR-33 — Method guidance | Method details correctly describe all eight combinations, selected-region full-image application, and the stable-component or limited-variation state. |
| QA-34 | FR-34 — Exploratory-use guidance | Visible and VoiceOver-readable copy presents modes as alternatives and names Lab conversion, normalization, clipping, noise, compression, lighting, and region choice as possible influences. |
| QA-35 | FR-35 — Reproducibility boundary | UI and exported image files expose no matrices, eigenvectors, channel statistics, numeric reports, settings manifests, or other transformation-data artifacts. |
| QA-36 | NFR-01 — Numerical correctness | Reference, uniform, near-singular, clipped, transparent, and high-dynamic-variation fixtures produce finite bounded outputs or the specified validation/failure state under documented thresholds. |
| QA-37 | NFR-02 — Shipped baseline | Golden fixtures for RGB + covariance + whole image are byte-identical to version 1.0.0 build 2 and retain the same degenerate notices. |
| QA-38 | NFR-03 — Determinism | Repeating every valid combination, including fixed integer regions, produces identical pixel bytes and validation outcomes. |
| QA-39 | NFR-04 — 24-megapixel performance | In Release, every valid combination completes the 6,000 × 4,000 benchmark in less than five seconds on supported Apple Silicon under normal load. |
| QA-40 | NFR-05 — Responsiveness | Interaction and cancellation tests during import, conversion, analysis, transformation, recalculation, and export show no main-thread stall that prevents control response. |
| QA-41 | NFR-06 — Accessibility | Automated inspection plus keyboard-only and VoiceOver passes reach and explain every control, field, action, status, error, and overlay meaning with visible focus. |
| QA-42 | NFR-07 — Visual consistency | Review under macOS light/dark settings and Reduce Motion shows legible fixed-light controls, overlays, focus, errors, and restrained transitions consistent with the design system. |
| QA-43 | NFR-08 — Platform compatibility | Debug and Release tests pass on macOS 14+ for Apple Silicon and Intel targets, and all existing import/export formats remain available. |
| QA-44 | NFR-09 — Privacy and sandboxing | Network inspection records no requests during analysis/export, and sandbox tests allow only user-selected file access. |
| QA-45 | NFR-10 — Independent testability | Automated tests exercise conversion, matrices, sample inclusion, coordinate mapping, gamut handling, cancellation, and request ordering without launching the production presentation UI. |
| QA-46 | FR-36 / NFR-11 — Pre-decode image limit | Pure boundary tests accept exactly 64,000,000 pixels, reject one pixel above the limit, reject invalid and overflowing dimensions, and an oversized metadata-only image returns the readable 64-megapixel error before full-frame decoding. Existing supported-format, orientation, alpha, golden, and 24-megapixel tests remain green. |
