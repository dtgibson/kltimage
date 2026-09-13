# PRD — Reproducible Analysis
**Feature:** reproducible-analysis
**Date:** 2026-09-12
**Stage:** 2 — The Planner
**Source:** strategic-brief.md (approved)

## Feature Overview

KLT Image will create an inspectable analysis record for each current enhanced result and let the user export that record as versioned JSON. The record will bind the source identity and selected settings to the statistics and transform actually used to render the result.

## User Stories

> **US-01** — As an image analyst, I want to see the settings and numerical transform for the current enhancement, so that I can understand exactly how the result was produced.

> **US-02** — As a researcher or naturalist, I want the record tied to the exact decoded source and sample region, so that I do not mistake one image or crop-derived transform for another.

> **US-03** — As a technically curious photographer, I want brief explanations and explicit channel conventions, so that I can interpret the matrices without reverse-engineering the app.

> **US-04** — As an image analyst, I want to export the current record as stable JSON, so that I can archive it with the enhanced image or compare it with another analysis using external tools.

> **US-05** — As a user changing images and settings interactively, I want stale records removed immediately, so that I can never inspect or export numbers belonging to a different result.

## Functional Requirements

### Record Lifecycle and Currency

> **FR-01** — The app shall create an analysis record only after an enhancement completes successfully.

> **FR-02** — The app shall bind each record to the exact source identity, analysis request, and completed processing job that produced the displayed enhanced result.

> **FR-03** — The app shall remove the current record and disable its export whenever the source image or any analysis setting changes, and shall not restore a record until the matching enhancement completes.

> **FR-04** — The app shall leave the prior valid enhanced image and record unavailable while replacement processing is in progress or has failed, consistent with the existing result-currency rules.

### Source and Request Description

> **FR-05** — The record shall identify the source by display filename, oriented pixel width and height, color-model basis used for analysis, fingerprint algorithm, and deterministic fingerprint of the decoded oriented analysis pixels.

> **FR-06** — The record shall identify the selected color space, matrix mode, and sampling mode using stable, documented values rather than localized display text.

> **FR-07** — For rectangular sampling, the record shall contain normalized x, y, width, and height values plus the resolved integer source-pixel bounds used for statistics; for whole-image sampling, the region shall be explicitly absent.

> **FR-08** — The record shall identify the channel order and units for every vector and matrix, including RGB and CIE Lab D65 analyses.

### Numerical Analysis Data

> **FR-09** — The record shall contain the sample pixel count, per-channel means, and the covariance or correlation matrix used for eigendecomposition.

> **FR-10** — The record shall contain eigenvalues and eigenvectors in a documented deterministic order and orientation.

> **FR-11** — The record shall contain the final transform coefficients and every output-centering, scaling, or clipping value needed to describe what the app rendered.

> **FR-12** — The record shall contain only finite numerical values; if a valid finite record cannot be produced, the enhancement shall fail with a clear user-facing error and no record shall become current.

> **FR-13** — The record shall distinguish mathematical inputs, derived eigensystem values, and final applied-output values so that a consumer does not have to infer their roles from field position.

### In-App Inspection

> **FR-14** — The app shall provide an Analysis Record action whenever a current enhanced result exists and shall keep the original, enhanced, and split comparison modes available after the record view is dismissed.

> **FR-15** — The in-app record view shall present source identity, settings, sample geometry, matrices, vectors, and output scaling in labeled groups with short explanations of covariance versus correlation and RGB versus Lab channel conventions.

> **FR-16** — The in-app record view shall state that the values document an exploratory enhancement and do not establish a biological or scientific conclusion.

### JSON Export and Comparison

> **FR-17** — The app shall offer an explicit Export Analysis Record action only when a current record exists and shall let the user choose the destination without modifying or overwriting the source image.

> **FR-18** — The exported filename shall default to the enhanced image base name followed by `.klt-analysis.json`, while allowing the user to choose another name.

> **FR-19** — The JSON shall include a top-level schema identifier and version, use stable field names and channel ordering, document all units and conventions in the schema, and encode matrices as fixed three-by-three row-major arrays.

> **FR-20** — The JSON shall use deterministic, locale-independent numeric encoding with enough precision to round-trip every stored floating-point value and shall not include volatile values such as export time or file-system path.

> **FR-21** — Exporting the same current record more than once shall produce byte-identical JSON.

> **FR-22** — Canceling the save panel shall create no file; an encoding or write failure shall preserve the current image and record and shall report the failure without leaving a partial final-named file.

## Non-Functional Requirements

> **NFR-01 — Performance:** Record generation, including the source fingerprint, shall keep the existing 24-megapixel Release analysis benchmark below five seconds on supported Apple silicon and shall not add more than 10 percent to its median processing time.

> **NFR-02 — Responsiveness:** Opening, scrolling, copying from, and dismissing the record view shall remain responsive for every supported image size, with no numerical formatting work that perceptibly blocks the main interface.

> **NFR-03 — Determinism:** The same decoded oriented source pixels, analysis settings, and app algorithm version shall produce identical record values and byte-identical exported JSON across repeated runs on the same supported architecture.

> **NFR-04 — Accessibility:** Every record section, value, action, status, and error shall be reachable by keyboard and exposed to VoiceOver with meaningful labels and reading order.

> **NFR-05 — Appearance:** The record view shall retain readable contrast and hierarchy in both macOS appearance settings while honoring the app's fixed light scientific palette.

> **NFR-06 — Compatibility:** The feature shall support macOS 14 and later and all existing JPEG, PNG, TIFF, and HEIC import paths.

> **NFR-07 — Privacy:** Record generation and export shall remain entirely local and shall introduce no network request, analytics, account, or persistence service.

> **NFR-08 — Numerical Safety:** Degenerate, constant-channel, near-singular, and clipped out-of-gamut inputs shall never produce NaN or infinity in the interface or exported record.

> **NFR-09 — Data Integrity:** Display and export shall use an immutable snapshot of the completed analysis record and shall never read mutable settings to reconstruct values after processing.

> **NFR-10 — Regression Safety:** Existing image import, orientation, enhancement, cancellation, comparison, and image-export behavior shall remain unchanged except for the new record actions and processing metadata.

## Out of Scope

- Saving analysis history or projects in the app.
- Importing a record or reapplying a saved transformation matrix.
- In-app diffing, charting, aggregation, or statistical comparison of multiple records.
- Batch processing or batch comparison.
- Automated significance claims, classification, or biological interpretation.
- New color spaces, segmentation, hue isolation, or changes to the decorrelation-stretch algorithm.
- Embedding the record in image metadata.
- Cloud storage, accounts, sharing, or collaboration.
- General CSV, PDF, or report export in this release.

## Open Questions

None — all decisions are resolved in this document.

## Success Metrics

| ID | What's Being Verified | Pass Condition |
|---|---|---|
| QA-01 | Record creation and exact result binding (FR-01, FR-02, NFR-09) | A successful enhancement exposes one immutable record whose source, request, and job identities match the displayed result; canceled or failed work exposes none. |
| QA-02 | Stale-record protection (FR-03, FR-04) | Changing the image, color space, matrix mode, sampling mode, or rectangle immediately removes record access and export until the matching replacement result completes. |
| QA-03 | Source description and fingerprint (FR-05) | The record reports the expected filename, oriented dimensions, analysis basis, fingerprint algorithm, and a repeatable fingerprint of the decoded oriented pixels; a one-pixel source change changes the fingerprint. |
| QA-04 | Request and region description (FR-06, FR-07) | Every supported settings combination records stable values, and rectangular sampling records both normalized coordinates and the exact integer bounds used while whole-image sampling records no region. |
| QA-05 | Channel conventions (FR-08, FR-15) | RGB and Lab records label channel order and units consistently in the app and schema documentation, including the D65 basis for Lab. |
| QA-06 | Statistical values (FR-09) | Fixture analyses report sample count, means, and covariance or correlation matrices within the established numerical tolerance of independently calculated expectations. |
| QA-07 | Eigensystem reproducibility (FR-10, NFR-03) | Repeated fixture analyses return eigenvalues and eigenvectors in the same documented order and orientation with expected values within tolerance. |
| QA-08 | Applied-output description (FR-11, FR-13) | A fixture record separates inputs, derived values, and applied-output values, and the recorded final transform and scaling agree with the values used to render the enhanced pixels. |
| QA-09 | Finite-value handling (FR-12, NFR-08) | Constant, near-singular, and clipped fixtures either produce a fully finite record or fail clearly with no current result or partial record; no NaN or infinity appears in UI or JSON. |
| QA-10 | In-app inspection and product boundary (FR-14, FR-15, FR-16) | A user can open and dismiss the grouped record from any comparison mode, read all required values and explanations, see the exploratory-use notice, and continue comparing the unchanged images. |
| QA-11 | Export workflow and naming (FR-17, FR-18) | Export is unavailable without a current record; with one, the save panel suggests `<enhanced-base>.klt-analysis.json`, accepts another destination, and never modifies the source image. |
| QA-12 | JSON schema and encoding (FR-19, FR-20) | The exported UTF-8 JSON validates against the documented schema, includes its identifier and version, uses stable fields and row-major 3×3 matrices, round-trips stored numeric values, and contains no timestamp or file-system path. |
| QA-13 | Deterministic export (FR-21) | Two exports of the same current record have identical SHA-256 checksums. |
| QA-14 | Export cancellation and failure (FR-22) | Cancel creates no file; simulated encoding and write failures leave no partial final-named file, preserve the current result and record, and present a clear error. |
| QA-15 | Performance and responsiveness (NFR-01, NFR-02) | Release benchmarks remain below five seconds at 24 megapixels with less than 10 percent median overhead, and UI interaction remains responsive while displaying the largest supported record. |
| QA-16 | Accessibility and appearance (NFR-04, NFR-05) | Keyboard-only and VoiceOver checks reach every value and action in logical order, and contrast remains readable in both macOS appearance settings. |
| QA-17 | Compatibility, privacy, and regressions (NFR-06, NFR-07, NFR-10) | Debug and Release XCTest pass for all existing import and processing paths on macOS 14+, dynamic inspection finds no new network activity, and existing comparison and image-export behavior remains unchanged. |
