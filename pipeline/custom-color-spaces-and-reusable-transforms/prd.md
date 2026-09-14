# PRD — Custom Color Spaces and Reusable Transforms
**Feature:** custom-color-spaces-and-reusable-transforms
**Date:** 2026-09-12
**Stage:** 2 — The Planner
**Source:** strategic-brief.md (approved)

## Feature Overview

KLT Image will add a local method library with two explicitly different artifact types. A working-space definition supplies three reversible coordinates in which the app calculates a new decorrelation stretch; a saved transform recipe freezes the complete numerical method behind one valid calculated result for deterministic replay without recalculating from the target image. The feature includes a small, transparent set of KLT Image working-space presets, a bounded editor for user-defined affine spaces over encoded sRGB or CIE Lab D65, safe local persistence and interchange, and result provenance that remains compatible with the shipped version-1 analysis-record contract.

## User Stories

> **US-01** — As an image analyst, I want documented alternatives to RGB and Lab so that I can explore color distinctions that those coordinates may not separate clearly.

> **US-02** — As a technically informed user, I want to define three reversible channels from a supported base space so that I can test a transparent method without writing code or installing a plug-in.

> **US-03** — As a researcher, I want to inspect every channel equation, coefficient, convention, and output rule so that no curated or custom space behaves like an opaque effect.

> **US-04** — As a user developing a useful method, I want to save the exact current transform as a named recipe so that I can reproduce it after relaunch.

> **US-05** — As an analyst comparing related photographs, I want to apply one frozen transform to another image without refitting it so that the method stays controlled across sources.

> **US-06** — As a user interpreting a result, I want to know whether it was newly calculated or replayed and which source established a reused recipe so that I do not mistake replay for target-specific analysis.

> **US-07** — As a user maintaining a method library, I want to inspect, rename, duplicate, edit where appropriate, delete, export, and import items so that I can manage and move them deliberately.

> **US-08** — As a security-conscious user, I want imported definitions and recipes treated as untrusted local data so that a malformed file cannot run code, corrupt my library, or replace my current work.

> **US-09** — As an existing KLT Image user, I want RGB and Lab results and version-1 analysis JSON to stay unchanged so that prior fixtures and archived records retain their meaning.

## Functional Requirements

### Method Model and Identity

> **FR-01** — The app shall model and label **working spaces** and **saved transforms** as separate artifact types: selecting a working space calculates a new image-specific transform, while selecting a saved transform replays frozen values.

> **FR-02** — The existing RGB and CIE Lab D65 working spaces shall remain available with their current stable identifiers, calculations, defaults, and user-facing meanings; RGB shall remain the launch default.

> **FR-03** — Every completed result, processing state, inspector, and exportable analysis record shall identify its execution mode as `calculated` or `replayed` and shall identify the exact working-space definition or saved-transform recipe used.

> **FR-04** — Switching between calculated and replayed modes, changing a working space or recipe, editing the active custom definition, or replacing the source shall immediately invalidate current-result actions and shall use the existing cancellable request-supersession gate before a replacement becomes current.

### Curated and User-Defined Working Spaces

> **FR-05** — The initial curated collection shall contain three KLT Image presets covering (a) general luma/chroma separation, (b) red-versus-complement distinction, and (c) blue/yellow distinction in a Lab-derived basis; none shall use a DStretch preset name or claim DStretch-compatible pixels.

> **FR-06** — Each curated preset shall have a stable identifier and version and shall expose its KLT Image name, purpose, encoded-sRGB or CIE Lab D65 base, base-channel conventions, three output-channel names, 3×3 forward coefficients, three affine offsets, derived inverse, and base-specific output behavior.

> **FR-07** — Curated presets shall use the same versioned working-space definition model, validation path, processing path, inspection presentation, and deterministic fixtures as user-created spaces; curated status shall confer no hidden calculation or scientific rank.

> **FR-08** — A user shall be able to create a working space by choosing encoded sRGB or CIE Lab D65, entering a non-empty library name and three non-empty channel names, and specifying three affine equations of the bounded form `working = A × base + b`, where `A` is exactly 3×3 and `b` has exactly three values.

> **FR-09** — The editor shall accept decimal numeric coefficients and offsets only; it shall not accept scripts, free-form expressions, functions, file references, plug-ins, shader code, additional channels, or executable content.

> **FR-10** — Before a custom definition can be saved or used, the app shall verify exact field counts, finite values, documented coefficient bounds, a nonsingular forward matrix, a finite derived inverse, and a documented maximum condition number; it shall show the specific failed rule beside the affected definition.

> **FR-11** — Invalid, singular, non-finite, out-of-range, ill-conditioned, or unsupported definitions shall start no processing and shall never cause a silent fallback to RGB, Lab, a curated preset, or a prior valid version.

> **FR-12** — For a valid selected working space, the app shall convert unchanged decoded source pixels into its declared base, apply the forward affine mapping, calculate covariance or correlation from the whole image or valid selected region, apply the resulting plan to the complete image, apply the derived inverse mapping, and use the declared base-specific output behavior to return to displayable sRGB.

> **FR-13** — Curated and custom working spaces shall support every existing covariance/correlation and whole-image/selected-region combination, including the current region validity, pixel-inclusion, limited-variation, alpha, cancellation, stale-result, comparison, and 64-megapixel behaviors.

> **FR-14** — A working-space detail view shall present the forward and inverse equations, channel order and conventions, version, output behavior, purpose or user origin, and a concise explanation that the space changes exploratory coordinates rather than proving a feature.

> **FR-15** — A user shall be able to rename, duplicate, inspect, edit, export, and delete a user-created working space; curated spaces shall be inspectable and duplicable into an editable user copy but shall not be renamed, edited in place, or deleted.

> **FR-16** — Committing a mathematical edit to a user-created working space shall create the next immutable definition version; prior analysis records and saved-transform snapshots shall retain the exact earlier version, while renaming only the library label shall not change its mathematics or version.

> **FR-17** — If the user deletes the active custom working space, the app shall confirm the action, explain that saved recipes remain independent, switch calculated selection to RGB, and recalculate from the unchanged source when one is open; canceling shall change nothing.

### Local Method Library and Interchange

> **FR-18** — The method library shall present separate sections for curated working spaces, user-created working spaces, and saved transform recipes, with artifact type, name, version, base or origin, and last modified status available without opening an image.

> **FR-19** — User-created working spaces and saved transform recipes shall survive normal app relaunch in an application-managed local store; source images, results, regions, analysis history, and ordinary analysis settings shall not be added to that store.

> **FR-20** — Every library mutation shall validate the complete resulting library and replace the prior local store atomically; interruption or write failure shall leave the last valid store readable and shall report that the requested change was not saved.

> **FR-21** — A missing local store shall produce an empty user library plus curated presets; a corrupt, internally inconsistent, or unsupported-version store shall not be partially loaded, automatically overwritten, or prevent ordinary RGB/Lab analysis, and shall produce a recoverable user-facing error.

> **FR-22** — A user shall be able to export or import one working-space definition or one saved-transform recipe at a time through the standard sandboxed Mac file workflow, with suggested suffixes `.klt-space.json` and `.klt-transform.json` respectively.

> **FR-23** — Interchange documents shall use UTF-8 JSON with a type-specific schema identifier and integer version, stable nonlocalized field names and enum values, fixed row-major arrays, locale-independent round-trippable numbers, sorted keys, no timestamps or absolute paths, and one trailing newline.

> **FR-24** — Import shall read no more than 256 KiB per document and shall reject a wrong artifact type, unsupported schema version, missing or duplicate required field, wrong array length or type, non-finite or out-of-bound number, invalid identifier or string, singular or ill-conditioned definition, inconsistent inverse or transform snapshot, and trailing non-JSON payload.

> **FR-25** — Import shall decode and validate an entire document in memory before presenting its identity and effects; malformed or rejected input shall add, replace, or delete no library item and shall not change the current source, method, result, record, or export availability.

> **FR-26** — A valid import whose stable identifier or normalized name conflicts with a local item shall require an explicit Replace, Import as Copy, or Cancel choice, shall preview the artifact type and version, and shall never overwrite silently or replace an artifact of the other type.

> **FR-27** — Export cancellation shall create no file, and encoding or write failure shall leave the library and current work unchanged and shall leave no partial file at the final chosen name.

### Saving and Applying Frozen Transforms

> **FR-28** — A Save Transform action shall be available only for a current, successfully calculated, non-limited-variation enhancement; it shall not be available for a stale, processing, failed, canceled, identity, or already replayed result.

> **FR-29** — Saving shall require a non-empty library name and shall capture the accepted result snapshot directly rather than reconstructing values from current controls or recalculating the image.

> **FR-30** — A saved transform recipe shall contain a stable identifier and format version; library name; exact working-space definition and version; base and channel conventions; forward mapping and derived inverse; calculation mean or affine centering values; final applied 3×3 transform; frozen output mapping, ranges, scale, gamut and clipping policy; originating covariance/correlation and sampling modes; source fingerprint, oriented dimensions, and display filename; algorithm version; and exploratory-use notice.

> **FR-31** — A recipe shall snapshot all working-space content needed for replay and shall not depend on a mutable or subsequently deleted library definition; editing, renaming, replacing, or deleting the originating working space shall not change the recipe or its output.

> **FR-32** — A user shall be able to inspect, rename, duplicate, export, import, and delete a saved transform recipe; these library-management actions shall not recalculate or alter a current result that already owns an immutable recipe snapshot.

> **FR-33** — From a recipe, the user shall be able to apply it to the current image or choose another supported image through the existing open-and-replace workflow; applying to another image shall retain the recipe selection after the new source is accepted.

> **FR-34** — Replay shall convert the target's unchanged decoded pixels through the frozen base and forward working-space mapping, apply the frozen centering and 3×3 transform, use the frozen inverse and output mapping, and preserve target alpha without calculating target covariance, correlation, sample statistics, eigensystem, gains, centering, minimum, maximum, scale, gamut fit, or clipping policy.

> **FR-35** — Replaying a recipe on a decoded source whose fingerprint and dimensions match the recipe origin shall produce pixel bytes identical to the original calculated enhancement from which the recipe was saved.

> **FR-36** — Replaying a recipe on any other supported source shall be deterministic, shall label the result as reuse on a different source, and shall expose both the target identity and originating source identity without implying that the transform was calculated from the target.

> **FR-37** — A replayed result that clips heavily, has poor contrast, or appears visually unhelpful shall remain the honest fixed output; the app shall report the applicable clipping or range condition and offer a route back to calculated analysis without adapting and retaining the same recipe identity.

> **FR-38** — Replayed processing shall retain the supported input formats, orientation, immutable decoded source, 64-megapixel limit, fully transparent-pixel behavior, alpha preservation, full-frame application, responsive cancellation, and request-acceptance protections of calculated processing.

> **FR-39** — While replayed mode is selected, covariance, correlation, and sampling controls shall be visibly inactive with an explanation that the recipe is frozen; choosing Calculate for This Image shall leave the recipe unchanged, restore the last calculated controls for the session, and calculate from the unchanged source.

> **FR-40** — Original, Split, and Enhanced comparison modes and full-resolution PNG, TIFF, and JPEG image export shall work for a current replayed result exactly as for a current calculated result, with no method overlays or library metadata burned into exported pixels.

### Analysis Records and Provenance

> **FR-41** — Every current custom-space calculation or replayed result shall have one immutable in-app analysis record bound to the accepted source, execution mode, method snapshot, processing job, and displayed pixels; it shall become unavailable whenever that result is no longer current.

> **FR-42** — Existing calculated RGB and Lab combinations shall continue to export `org.kltimage.analysis-record` version 1 with byte-identical canonical JSON for the same immutable record; no version-1 field, enum, convention, ordering, or meaning shall be changed.

> **FR-43** — Custom-space calculations and all replayed results shall use an explicitly versioned analysis-record extension that identifies execution mode and embeds the exact working-space definition; a replayed record shall separately identify target source, recipe, originating source, and frozen recipe mathematics and shall not present them as target-derived statistics.

> **FR-44** — An exported analysis record shall remain documentary and shall never be accepted by the working-space or transform-recipe importer as an executable method, regardless of overlapping fields.

> **FR-45** — In-app inspection and versioned analysis JSON shall use the same immutable current snapshot and shall distinguish library labels from stable identities and mathematical versions, including when an item has been renamed or deleted after processing.

### Guidance and Existing Workflow

> **FR-46** — Method guidance shall explain that a working space changes the variables used to calculate a new transform, while a saved transform applies an earlier calculation unchanged; the active mode distinction shall be available visually and to VoiceOver.

> **FR-47** — Curated preset guidance shall describe intended exploratory color distinctions without terms such as “best,” “accurate,” “scientific,” “detects,” or other claims that the space establishes a pigment, structure, or biological conclusion.

> **FR-48** — Custom-space and replay guidance shall warn that coordinate choice and fixed reuse can amplify noise, compression, color-management effects, and lighting differences, and that inverse conversion or target mismatch can produce clipping, gamut loss, or misleading visual emphasis.

> **FR-49** — Opening, replacing, comparing, inspecting, and exporting an image shall preserve the existing source-safety and current-result rules; the method library shall never modify, relocate, embed data in, or automatically create a sidecar beside a source image.

> **FR-50** — The feature shall provide no batch action, multi-image queue, watched folder, automatic application on import, analysis-history project, network gallery, account, synchronization, or cloud sharing path.

## Non-Functional Requirements

> **NFR-01 — Numerical correctness:** Forward mapping, covariance or correlation analysis, frozen replay, inverse mapping, and output conversion shall use finite `Double`-precision operations with documented scale-relative validation thresholds and shall either produce bounded display pixels or fail clearly without a partial result.

> **NFR-02 — Determinism:** Repeated calculation or replay from identical decoded pixels and immutable method data shall produce identical pixel bytes and protocol values on the same supported architecture; repeated exports of an unchanged library item or record shall be byte-identical.

> **NFR-03 — Compatibility:** The feature shall support macOS 14 or later on Apple Silicon and Intel Macs and shall preserve all supported JPEG, PNG, TIFF, HEIC, PNG-export, TIFF-export, and JPEG-export paths.

> **NFR-04 — Baseline regression:** RGB + covariance + whole image and every currently shipped RGB/Lab combination shall retain established numerical, pixel, limited-variation, region, alpha, cancellation, comparison, and export fixtures.

> **NFR-05 — Version-1 protocol stability:** Golden version-1 analysis JSON shall remain byte-identical; new semantics shall be expressed only by a new versioned analysis document or a type-specific recipe document.

> **NFR-06 — Performance:** A 24-megapixel curated or custom calculation and a 24-megapixel replay shall each complete in less than five seconds in Release on supported Apple Silicon under normal load, and library launch decoding with 500 valid items shall complete in less than one second.

> **NFR-07 — Responsiveness:** Working-space validation, library management, import/export, calculation, replay, cancellation, inspection, and image export shall not freeze controls or prevent normal Mac interaction.

> **NFR-08 — Memory safety:** The fixed 64-million-pixel ceiling and conservative existing full-frame memory budget shall remain in force for conversion, calculation, replay, comparison, and export; recipe application shall not retain avoidable duplicate full-resolution buffers.

> **NFR-09 — Persistence integrity:** Library writes shall be atomic and crash-safe, migrations shall be deterministic and covered by fixtures, and unsupported or corrupt data shall fail closed without destroying the last readable store.

> **NFR-10 — Import security:** All imported content shall be handled as bounded data with no evaluation, dynamic loading, path traversal, external entity, bookmark, network, or automatic file-access behavior.

> **NFR-11 — Privacy:** Processing and library storage shall remain local; no image pixels, fingerprints, definitions, recipes, analysis values, filenames, or usage data shall be transmitted.

> **NFR-12 — Accessibility:** Every library section, item, equation, matrix, validation error, conflict choice, mode, status, warning, and action shall have logical keyboard navigation, visible focus, meaningful VoiceOver output, and non-color-only state communication.

> **NFR-13 — Appearance:** Library, editor, provenance, clipping, and error treatments shall follow the fixed-light scientific design system, remain readable under macOS light and dark settings, and respect Reduce Motion and text-size accommodations.

> **NFR-14 — Testability:** Working-space validation and conversion, persistence codecs and migration, import limits, transform capture and replay, provenance, analysis-record routing, and request supersession shall be independently testable outside the presentation layer with reference, synthetic, malformed, golden-byte, and randomized fixtures.

## Out of Scope

- DStretch preset names, matrix files, schema, or pixel-output compatibility.
- Arbitrary code, expressions, scripts, plug-ins, shaders, LUTs, neural transforms, or working spaces with other than three channels.
- ICC profile authoring or import, device calibration, spectral data, alternate Lab reference whites, RAW decoding, or a change to the decoded 8-bit sRGB source contract.
- Automatic selection, ranking, or scientific validation of a working space or saved transform.
- Adaptive reuse that refits range, centering, gamut, statistics, or any other recipe value to the target while retaining the same recipe identity.
- Batch processing, queues, watched folders, multi-image comparison, aggregation, or automatic application during import.
- Image projects, persisted source images, analysis history, saved regions, cross-launch undo, or importing analysis records as executable methods.
- Cloud sync, accounts, collaboration, remote preset galleries, telemetry, or automatic sharing of source fingerprints or recipes.
- Hue shifting, hue histogram equalization, saturation stretching, hue isolation, background flattening, segmentation, or unrelated DStretch features.

## Open Questions

None — all product decisions are resolved in this document. Exact curated coefficient values, numerical conditioning thresholds, and storage type boundaries are implementation details for The Architect to specify within these requirements and pin with fixtures.

## Success Metrics

| ID | What's Being Verified | Pass Condition |
|---|---|---|
| QA-01 | Artifact distinction and current method identity (FR-01, FR-03) | Calculating from a working space and replaying a recipe produce visibly and accessibly distinct modes, and every processing/current state names the exact definition or recipe used. |
| QA-02 | Existing defaults and invalidation (FR-02, FR-04) | Clean launch still selects RGB, and every listed method, definition, recipe, or source change immediately removes stale actions; only the newest matching job becomes current. |
| QA-03 | Curated collection and independence (FR-05) | The app ships the three required exploratory categories under KLT Image names, and repository/UI inspection finds no DStretch compatibility claim or copied preset identifier. |
| QA-04 | Curated transparency and shared model (FR-06, FR-07) | Each preset exposes every required field and passes the same validator, processing API, and deterministic fixture path as an equivalent imported user definition. |
| QA-05 | Custom definition entry boundary (FR-08, FR-09) | Keyboard-only tests create valid RGB- and Lab-based 3×3 affine spaces, while extra channels, expressions, functions, file references, code, and executable payloads cannot be entered or imported. |
| QA-06 | Definition validation and no fallback (FR-10, FR-11) | Wrong-count, NaN, infinity, bounded-range, singular, near-singular, bad-inverse, and condition-limit fixtures each show the correct rule, start no job, and leave the active method unchanged rather than running a fallback. |
| QA-07 | Custom processing order (FR-12) | Independent fixtures confirm base conversion, forward affine mapping, selected statistical population, full-image frozen plan, inverse mapping, and base output behavior in the specified order. |
| QA-08 | Full method combination coverage (FR-13) | Every curated/custom × covariance/correlation × whole-image/region combination completes or reaches its established limited-variation state while existing alpha, inclusion, cancellation, stale-request, comparison, and size-limit tests pass. |
| QA-09 | Definition inspection and management (FR-14, FR-15) | The detail view exposes all required equations, conventions, origin, behavior, and warning; user items support all listed actions and curated items permit only inspection and duplication. |
| QA-10 | Definition versions and active deletion (FR-16, FR-17) | Mathematical edit increments an immutable version, rename does not, old records/recipes retain old math, confirmed active deletion selects RGB and recalculates, and cancel changes nothing. |
| QA-11 | Library organization and persistence scope (FR-18, FR-19) | All three library sections and metadata are available with no image open; user methods survive relaunch, while source, result, region, history, and ordinary settings do not. |
| QA-12 | Atomic library mutation (FR-20, NFR-09) | Injected interruption and write failure at every replacement boundary leave the prior store byte-valid and readable and report that the requested mutation was not saved. |
| QA-13 | Missing, corrupt, and future library stores (FR-21) | Missing-store launch shows curated plus empty user sections; corrupt/inconsistent/future-version fixtures load no partial user data, are not overwritten, show recovery guidance, and leave RGB/Lab analysis usable. |
| QA-14 | Type-specific interchange and canonical encoding (FR-22, FR-23) | Each artifact exports through a save panel with the correct suggested suffix; repeated exports validate against the right schema and have identical bytes, sorted stable fields, row-major arrays, round-trippable numbers, and one newline. |
| QA-15 | Bounded import rejection (FR-24, NFR-10) | Every listed malformed class, a 256-KiB-plus-one file, duplicate-key fixture, and trailing-payload fixture fail before commit with no code execution, dynamic loading, path access, network access, or external resolution. |
| QA-16 | Import atomicity and conflict handling (FR-25, FR-26) | Rejected input changes no current or library state; valid name/ID collisions show type and version and honor Replace, Import as Copy, and Cancel without cross-type or silent replacement. |
| QA-17 | Interchange cancellation and write failure (FR-27) | Cancel creates no file, and forced encode/write failures preserve current work and library state with no partial final-named file. |
| QA-18 | Save-transform eligibility and snapshot source (FR-28, FR-29) | Save is enabled only for the listed valid calculated state, requires a name, and the stored bytes match the accepted result snapshot even if controls mutate before the write completes. |
| QA-19 | Complete recipe contract (FR-30) | A covariance/region/custom-space fixture recipe contains every required identifier, mapping, centering, transform, output, origin, algorithm, and interpretation field and validates without consulting mutable app state. |
| QA-20 | Recipe independence and management (FR-31, FR-32) | Editing, renaming, replacing, or deleting the source working space cannot change recipe bytes or replay output; every recipe action works and does not alter an already current snapshot. |
| QA-21 | Apply workflow (FR-33) | A recipe applies to the open image and, through the existing confirmation/open flow, to another supported image while remaining selected after successful replacement; cancellation retains the prior source and result. |
| QA-22 | Frozen replay semantics (FR-34) | Instrumented replay reads only target pixels and frozen recipe values; it performs no target statistical/eigen/range fit, preserves alpha, and matches an independent application of the documented affine formula. |
| QA-23 | Exact original replay (FR-35) | Saving and replaying RGB, Lab, curated, and user-space recipes on their original decoded source yields enhanced pixel buffers byte-identical to the originating calculated results. |
| QA-24 | Deterministic cross-source reuse and provenance (FR-36) | Repeating a recipe on a different target yields identical bytes and identifies both target and origin, with no UI or record text claiming target-derived analysis. |
| QA-25 | Honest poor-result handling (FR-37) | Deliberately mismatched fixtures retain fixed clipped or low-contrast pixels, show the applicable warning and Calculate route, and never adjust recipe parameters under the same identity. |
| QA-26 | Replay safety and calculated-mode return (FR-38, FR-39) | Import, orientation, limit, transparency, cancellation, and out-of-order completion fixtures pass in replay; analysis controls are inactive and explained until Calculate restores the prior session controls and starts a fresh calculation. |
| QA-27 | Comparison and image export (FR-40) | Original, Split, and Enhanced modes work for replay with synchronized navigation, and PNG/TIFF/JPEG exports retain source dimensions and established alpha behavior with no overlay or method metadata in pixels. |
| QA-28 | Current extended record lifecycle (FR-41) | Custom and replay jobs expose exactly one record bound to the accepted source, mode, method snapshot, job, and pixels; any invalidating action removes inspection and export until matching completion. |
| QA-29 | Version-1 compatibility (FR-42, NFR-05) | Golden RGB/Lab version-1 analysis exports from the shipped fixtures retain identical SHA-256 checksums and schema meanings after the feature is installed. |
| QA-30 | Extended provenance and non-executability (FR-43, FR-44, FR-45) | Custom/replayed JSON validates at the new version and cleanly separates target, origin, definition, recipe, and frozen mathematics; inspector matches it, and both method importers reject version-1 and extended analysis records. |
| QA-31 | Guidance and accessible mode distinction (FR-46, FR-47, FR-48) | Visible and VoiceOver-readable copy accurately explains calculate versus replay, uses no prohibited authority claims, and names noise, compression, color management, lighting, clipping, gamut, and target mismatch. |
| QA-32 | Source and scope boundaries (FR-49, FR-50) | File monitoring proves no source mutation, relocation, metadata edit, or automatic sidecar; UI and process inspection find no batch, queue, history, project, gallery, account, sync, or cloud path. |
| QA-33 | Numerical safety and determinism (NFR-01, NFR-02) | Reference, randomized, near-singular, extreme-coefficient, clipped, transparent, and repeated fixtures produce finite bounded output or the specified failure, with stable pixels and byte-identical repeated documents on each architecture. |
| QA-34 | Platform and shipped-regression safety (NFR-03, NFR-04) | Debug and Release suites pass on macOS 14+ Apple Silicon and Intel targets for every existing input/output format and all established RGB/Lab numerical, region, alpha, cancellation, comparison, and export fixtures. |
| QA-35 | Performance, responsiveness, and memory (NFR-06, NFR-07, NFR-08) | Release benchmarks meet both 24-megapixel five-second limits and the 500-item one-second launch limit; controls remain interactive throughout, and memory profiling stays within the existing 64-megapixel working-set budget without avoidable replay buffers. |
| QA-36 | Privacy and persistence (NFR-09, NFR-11) | Migration and crash fixtures preserve the last valid store, and network inspection records no transmission during editing, storage, calculation, replay, inspection, import, or export. |
| QA-37 | Accessibility and appearance (NFR-12, NFR-13) | Keyboard-only and VoiceOver passes reach and explain every required state and action in logical order, and review under both macOS appearances, Reduce Motion, and larger text shows legible non-color-only treatments. |
| QA-38 | Independent testability (NFR-14) | Automated tests exercise validation, conversion, codecs, migration, size limits, capture, replay, provenance, record routing, and supersession without launching the production SwiftUI workspace. |
