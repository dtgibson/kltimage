# PRD — Core RGB Enhancement Workflow
**Feature:** core-klt-image-enhancement
**Date:** 2026-09-10
**Stage:** 2 — The Planner
**Source:** strategic-brief.md (approved)

## Feature Overview

A native Mac workflow that opens one image, applies a whole-image RGB covariance decorrelation stretch, compares the result with the unchanged original, and exports the enhanced image at full resolution.

## User Stories

> **US-01** — As an image researcher, I want to open a photograph and enhance subtle color differences so that patterns hidden in ordinary RGB rendering become visible.

> **US-02** — As a naturalist examining feathers, I want the original and enhanced images visible together so that I can interpret changes in context.

> **US-03** — As a technically informed user, I want a concise explanation of the operation so that I understand what the result does and does not demonstrate.

> **US-04** — As a photographer, I want to export the enhanced result at full resolution so that I can inspect or share it outside the app.

> **US-05** — As a researcher, I want identical inputs to produce identical outputs so that visual comparisons remain reproducible.

## Functional Requirements

### Image Input

> **FR-01** — The app shall open single-frame JPEG, PNG, TIFF, and HEIC images through the standard Mac file picker.

> **FR-02** — The app shall respect image orientation and preserve the source image unchanged.

> **FR-03** — The app shall show a clear error when an image is corrupt, unsupported, or cannot be decoded, while remaining ready to open another image.

> **FR-04** — The app shall preserve an input image's alpha channel without including alpha in the color analysis.

### Decorrelation Stretch

> **FR-05** — The app shall calculate RGB means and a 3×3 covariance matrix from every image pixel.

> **FR-06** — The app shall derive an orthonormal principal-component basis from the covariance matrix and order components consistently by variance.

> **FR-07** — The app shall center RGB values, transform them into the principal-component basis, equalize all numerically stable component variances, apply the inverse basis, and restore the mean.

> **FR-08** — The app shall use one uniform final scaling step and bounded channel values to produce a valid displayable image.

> **FR-09** — The app shall prevent zero or near-zero component variance from causing division by zero, non-finite values, or unbounded amplification.

> **FR-10** — The app shall produce a valid unchanged or effectively unchanged result for an image with no usable color variance, accompanied by a concise explanation.

> **FR-11** — The app shall produce the same enhanced pixel values whenever the same source image is processed again.

### Comparison

> **FR-12** — The app shall display the original and enhanced images side by side after processing completes.

> **FR-13** — The app shall label both views clearly and keep their zoom and pan positions synchronized.

> **FR-14** — The app shall provide visible processing, success, and failure states without blocking normal Mac interaction.

### Export

> **FR-15** — The app shall export the enhanced image at the source image's pixel dimensions.

> **FR-16** — The app shall support PNG, TIFF, and JPEG export through the standard Mac save workflow.

> **FR-17** — The app shall preserve transparency when exporting to a format that supports it.

> **FR-18** — The app shall never overwrite the source image unless the user explicitly chooses the same destination and confirms replacement through the standard Mac workflow.

### Guidance

> **FR-19** — The app shall briefly explain decorrelation stretch, covariance, and the visual purpose of the enhancement in plain language.

> **FR-20** — The app shall state that enhanced colors are exploratory visual evidence and do not by themselves establish a scientific conclusion.

## Non-Functional Requirements

> **NFR-01 — Numerical correctness:** Matrix calculations shall use sufficient precision to keep all intermediate and output values finite for valid inputs.

> **NFR-02 — Performance:** A 24-megapixel image shall produce an initial enhanced view within five seconds on a supported Apple Silicon Mac under normal load.

> **NFR-03 — Responsiveness:** Image processing and export shall not freeze the app's controls or prevent cancellation.

> **NFR-04 — Accessibility:** Controls, image panes, progress, and errors shall have meaningful VoiceOver labels and full keyboard access.

> **NFR-05 — Color consistency:** Input images shall be converted into one documented RGB working space so embedded profiles do not produce unpredictable calculations.

> **NFR-06 — Privacy:** All image processing shall occur locally. The app shall not upload images or transformation data.

> **NFR-07 — Testability:** The mathematical core shall be independently testable using known covariance matrices and synthetic images.

## Out of Scope

- Lab color processing.
- Correlation-matrix mode.
- Selected-region sampling.
- Enhancement-strength controls.
- Quantitative reports or exported matrices.
- Custom color spaces.
- Saved transformations.
- Batch processing.
- RAW image decoding.
- Automated bird or feather segmentation.
- Scientific interpretation of enhanced features.

## Open Questions

- Which RGB working space should govern calculation and export? Default assumption: normalize inputs to sRGB and export with an sRGB profile.
- What threshold should define a numerically unstable component? Default assumption: The Architect will specify a scale-relative threshold that is covered by reference tests.
- Should an entirely uniform image remain unchanged or produce no result? Default assumption: display the unchanged image with a "not enough color variation" message.

## Success Metrics

| ID | What's Being Verified | Pass Condition |
|---|---|---|
| QA-01 | Supported image import | JPEG, PNG, TIFF, and HEIC fixtures open with correct dimensions and orientation. |
| QA-02 | Source safety | Processing and export never modify the source file. |
| QA-03 | Invalid input | Corrupt and unsupported fixtures produce a readable error and the app remains usable. |
| QA-04 | Alpha handling | Transparent pixels retain their original alpha values and alpha does not affect covariance. |
| QA-05 | Covariance calculation | Computed means and covariance match reference values within the documented tolerance. |
| QA-06 | Principal components | Eigenvectors are orthonormal and reconstruct the covariance matrix within tolerance. |
| QA-07 | Variance equalization | Stable transformed components have equal variance within the documented tolerance. |
| QA-08 | Numerical safety | Uniform and near-uniform fixtures produce no NaN, infinity, crash, or uncontrolled amplification. |
| QA-09 | Determinism | Repeated processing of the same fixture produces identical output pixels. |
| QA-10 | Comparison view | Original and enhanced images appear together with labels and synchronized navigation. |
| QA-11 | Full-resolution export | Exported dimensions exactly match source dimensions in PNG, TIFF, and JPEG tests. |
| QA-12 | Transparency export | PNG and TIFF retain source alpha values. |
| QA-13 | Responsiveness | A 24-megapixel fixture processes within five seconds without freezing controls. |
| QA-14 | Accessibility | Every interactive control is keyboard reachable and has a meaningful VoiceOver label. |
| QA-15 | Guidance | The app explains the operation and displays the exploratory-use limitation. |
| QA-16 | Privacy | Network inspection confirms that processing and export make no outbound requests. |
