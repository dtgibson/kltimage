# Strategic Brief — Reproducible Analysis

## What We're Building

Add an analysis record for every completed enhancement that exposes the exact settings and numerical transform behind the displayed result. Users can inspect the record in the app and export a stable, machine-readable sidecar alongside the enhanced image so an analysis can be repeated or compared later.

## Why Now

KLT Image now supports the interactive choices that materially change a decorrelation stretch: RGB or Lab, covariance or correlation, and whole-image or rectangular sampling. Without a durable record of those choices and the resulting transform, two visually similar exports cannot be distinguished, reproduced, or compared with confidence. This is the next useful step from exploratory viewing toward defensible quantitative work while preserving the app's focused, local workflow.

## The User Problem

A researcher, naturalist, photographer, or image analyst can reveal a useful color pattern today, but the exported image does not explain how it was produced. They need enough source identity, settings, sampling geometry, and numerical output to repeat the same analysis and compare it with another run without relying on memory, screenshots, or hidden implementation details.

## Success Criteria

- Every current enhanced result has an analysis record tied to the exact source, request, and processing job that produced it.
- The record identifies the source image by filename, pixel dimensions, and a deterministic content fingerprint.
- The record captures color space, matrix mode, sampling mode, and normalized sample-region coordinates when a rectangle is used.
- The record exposes the numerical inputs and outputs needed to understand and reproduce the transform, including channel means, the covariance or correlation matrix, eigenvalues, eigenvectors, and the final applied transform and output scaling values.
- Users can inspect the record without losing the original-versus-enhanced comparison.
- Users can export a versioned JSON sidecar whose values are deterministic for the same decoded source and analysis settings.
- Exported records make two analyses directly comparable by using stable field names, units, channel ordering, numeric precision, and schema versioning.
- Changing the image or any analysis setting invalidates stale records so displayed and exported data can never describe a different result.

## Scope

- A compact in-app analysis-record view for the current result.
- Exact capture of source identity, request settings, sample geometry, computed statistics, eigensystem, applied transform, and output scaling.
- A documented, versioned JSON schema and explicit numeric conventions.
- Export of the analysis record as a JSON sidecar through an explicit user action.
- Clear explanatory copy that distinguishes reproducibility data from biological or scientific conclusions.
- Determinism, stale-result protection, accessibility, and regression coverage for record generation and export.

## Out of Scope

- Saving analysis history or projects inside the app.
- Reapplying or importing a saved transformation matrix.
- Batch processing or batch comparison.
- Automated statistical significance claims, classification, or biological interpretation.
- New color spaces, segmentation, hue isolation, or changes to the decorrelation-stretch algorithm itself.
- Embedding the record into image metadata or adding a cloud, account, or collaboration service.

## Key Decisions

- Treat the analysis record as a new product capability, not a change to the existing transform.
- Make JSON the first durable interchange format because it can preserve structured matrices, settings, units, and schema versioning without flattening or ambiguity.
- Bind every record to the same exact source, request, and job identity rules already used for displayed and exportable images.
- Fingerprint the decoded, oriented analysis source rather than relying only on a file path, which may change or point to different bytes later.
- Record both the mathematical intermediates and the final applied transform so the exported data describes what the app actually rendered.
- Keep comparison support format-based in this first release: stable records can be inspected side by side or compared by external tools, without introducing persistent in-app projects or saved transforms.
- Preserve the product's exploratory boundary. Numerical transparency supports reproducibility but does not make the enhancement a scientific conclusion.
