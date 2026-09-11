# Strategic Brief — Core RGB Enhancement Workflow

## What We're Building

A native Mac workflow for opening one image, applying a covariance-based RGB decorrelation stretch, comparing the enhanced result with the original, and exporting it at full resolution.

## Why Now

The transform is the product's central technical claim. Building the smallest complete workflow first lets us validate the mathematics and visual usefulness before adding Lab processing, correlation mode, or region selection.

## The User Problem

Subtle color differences in feathers can be hidden by strongly correlated RGB channels. The user needs a focused way to amplify those differences while retaining the original image as an immediate visual reference.

## Success Criteria

- A user can open a common image format from their Mac.
- The app calculates the RGB covariance matrix and its principal components from the whole image.
- Component variances are stretched safely, including images with nearly constant color channels.
- The inverse transform produces a viewable RGB approximation without crashing or corrupting the source.
- Original and enhanced images can be compared side by side.
- Processing is deterministic for the same image and settings.
- The enhanced image can be exported at its original pixel dimensions.
- The interface briefly explains what the enhancement does and warns that the result is exploratory, not scientific proof.
- Reference tests validate the transform against known matrices and synthetic images.

## Scope

- Native Mac application foundation.
- Single-image import.
- Whole-image RGB covariance analysis.
- Karhunen–Loève transform and inverse transform.
- Variance-equalizing contrast stretch with numerical safeguards.
- Side-by-side original and enhanced preview.
- Full-resolution image export.
- Basic accessible descriptions of the process and controls.

## Out of Scope

- Lab color processing.
- Correlation-matrix mode.
- Selected-region sampling.
- Quantitative reports or exported transformation data.
- Custom color spaces.
- Saved transformation matrices.
- Batch processing.
- Automated feather detection or segmentation.
- Hue isolation or unrelated image enhancement tools.

## Key Decisions

- Validate one mathematically correct end-to-end path before broadening the controls.
- Use RGB covariance for the first implementation.
- Calculate statistics from the entire image in this feature.
- Apply the calculated transform to the entire image.
- Keep the original visible throughout comparison.
- Preserve full image resolution on export.
- Treat enhanced colors as exploratory visual evidence, not measurements or conclusions.
- Make numerical stability and reference-test coverage part of the feature, not deferred cleanup.
