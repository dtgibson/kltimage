# PRD — KLT Image for iPhone and iPad
**Feature:** ios-app
**Date:** 2026-10-01
**Stage:** 2 — The Planner
**Source:** strategic-brief.md (approved)

## Feature Overview

KLT Image will add a native iPhone and iPad app for local decorrelation-stretch analysis, comparison, method reuse, provenance inspection, and explicit export. It will use the same scientific methods and versioned documents as the Mac app while adapting image navigation and controls to touch and each screen size.

## User Stories

> **US-01** — As a naturalist with a photograph in Photos or Files, I want to analyze it on my iPhone, so that I can explore color structure without moving it to a Mac.

> **US-02** — As a researcher using an iPad, I want to select a precise source region and keep analysis context visible while comparing images, so that I can judge what the enhancement actually shows.

> **US-03** — As a photographer, I want to compare the unchanged source with a full-resolution result, so that I can see the effect and export a usable image without losing the original.

> **US-04** — As an analyst who uses both Mac and iOS, I want to exchange working-space and saved-transform documents, so that the same method keeps the same meaning on either device.

> **US-05** — As an analyst reusing a saved transform, I want the app to distinguish replay from a new calculation, so that I never mistake frozen mathematics for statistics measured from the current photograph.

> **US-06** — As a researcher documenting an observation, I want to inspect and export the exact current analysis record, so that I can retain the source and method provenance alongside the image.

> **US-07** — As a user of a smaller or older device, I want processing to remain cancellable and limits to be explained before large allocations, so that a source that cannot be handled does not silently become a lower-resolution or different analysis.

## Functional Requirements

### Platform and Source Import

> **FR-01** — The app shall provide native iPhone and iPad workspaces on iOS/iPadOS 18 or later; the existing macOS 14-or-later app shall remain available with its current behavior and release channel.

> **FR-02** — The app shall let the user explicitly choose one JPEG, PNG, TIFF, or HEIC source from Files or Photos and shall analyze the selected original-resolution image representation, not a picker thumbnail, edited preview, or reduced-resolution substitute.

> **FR-03** — When the chosen provider cannot supply a complete supported representation, access is denied, or decoding fails, the app shall explain the failure, present a retry or choose-another-image action, and retain the last accepted workspace.

> **FR-04** — The app shall orient the first image frame and convert it to the existing 8-bit sRGB analysis source before processing, preserve that decoded source unchanged, and report its oriented dimensions and source identity in the workspace and record.

> **FR-05** — Choosing a replacement source shall leave the current accepted source and result usable during import; cancellation or failure shall retain them, and only the latest successful import shall atomically replace the workspace. A successfully accepted new source shall clear the region and view position, select whole-image sampling, and retain the session's calculation controls as on Mac.

### Analysis and Resource Boundary

> **FR-06** — For a new calculation, the app shall offer RGB, CIE Lab D65, every shipped curated working space, and valid user working spaces, with RGB as the clean-launch default.

> **FR-07** — For a new calculation, the app shall independently offer covariance or correlation and whole-image or one rectangular source-pixel sample; clean-launch defaults shall be covariance and whole image.

> **FR-08** — A valid calculation shall derive statistics only from the selected source-pixel population, apply its one resulting transform to the entire unchanged decoded image, and preserve the established limited-variation, transparent-pixel, gamut, and alpha behavior. The selected method, matrix mode, and sample source shall remain visible with the result.

> **FR-09** — A selected-region calculation shall not start until one valid rectangle exists. Invalid, empty, out-of-bounds, fewer-than-four-pixel, or insufficiently varied selections shall produce a specific editable error, with no silent clamping, whole-image fallback, or result export under the invalid request.

> **FR-10** — The app shall accept images of at most 26,000,000 oriented pixels and at most 256 MiB of encoded source data for iOS analysis. Files and Photos imports shall reject an encoded file above that fixed byte limit before full copy or decode, and reject larger or invalid oriented dimensions before a full-resolution decode or app-owned full-frame allocation. The applicable message shall state the exceeded limit and ask for a smaller source; the app shall not downsample, raise either limit based on free memory, or use the Mac's 64-million-pixel limit on iOS. Temporary source staging shall be removed after failure or cancellation and recovered after an interrupted import.

> **FR-11** — The app shall run import decoding, calculation, replay, record generation, and image encoding without blocking normal interface interaction; shall show progress or a busy state and a Cancel action; and shall make cancellation or a processing failure leave no partial current result. A late completion shall never replace a newer accepted source, method request, or job.

> **FR-12** — Selecting a saved transform shall replay its frozen source-space mapping, centering, transform, and output behavior on the current source without fitting target statistics or changing the recipe. The app shall identify replay as reuse, show the originating and target source identities, report applicable clipping or range warnings, and offer a separate Calculate for This Image action.

> **FR-13** — Replaying a recipe on its original decoded source shall produce the same enhanced pixel bytes as the originating calculation; replaying on another source shall be deterministic and shall never present origin statistics as if measured from the target.

### Touch Workspace and Comparison

> **FR-14** — The app shall provide Original, Side-by-Side, Slider, and Processed comparison views. Each shall let the user return to the unchanged source, and neither a region outline nor interface labels shall be burned into exported pixels.

> **FR-15** — On iPhone, the image shall remain the primary canvas, with analysis controls and record or library inspection reachable without obscuring the comparison permanently. On iPad, the layout shall use available width to keep the image comparison and active analysis context visible together whenever the display is wide enough.

> **FR-16** — On both iPhone and iPad, a two-finger pinch on the image canvas shall zoom the registered source/result view, and a drag while zoomed shall pan it. Fit shall restore the full image; accessible zoom controls shall provide the same view changes without a pinch. Zoom and pan shall not alter source pixels, analysis, region coordinates, or exports. The Slider reveal control shall move the divider without panning or zooming the image, and region-edit gestures shall not move the divider or canvas until the edit ends.

> **FR-17** — The user shall be able to create, move, resize, replace, and clear one rectangular sample on the source with touch and also enter exact X, Y, width, and height source-pixel values without a precision gesture. The rectangle shall remain aligned after zoom, pan, rotation, and comparison-mode changes, and the app shall state that its statistics apply to the full result image.

> **FR-18** — Rotating an iPhone or iPad or resizing an iPad window shall adapt the layout without discarding the accepted source, current result, selected method, rectangle, or comparison mode.

### Methods and Cross-Platform Documents

> **FR-19** — The local method library shall show standard, curated, user working-space, and saved-transform entries without requiring an open image; it shall persist only user working spaces and saved transforms across launches.

> **FR-20** — The user shall be able to create, inspect, edit, duplicate, rename, delete, import, and export user working spaces. Standard and curated spaces shall allow inspection and duplication but not mutation of the shipped definition.

> **FR-21** — The user shall be able to save a valid calculated result as an immutable transform recipe and inspect, duplicate, rename, delete, import, export, and apply saved transforms. Editing a source working space or renaming or deleting a library item shall not change an already captured recipe or current result snapshot.

> **FR-22** — iOS method export shall produce the existing canonical version-1 `org.kltimage.working-space` or `org.kltimage.transform-recipe` document, and iOS import shall accept compatible documents produced by the Mac app without altering definition versions, stable identities, coefficient values, or recipe meaning. The same unchanged item shall export byte-identically on both platforms.

> **FR-23** — Method import shall apply the existing strict schema, version, exact-field, finite-value, duplicate-key, and 256-KiB artifact limits before any library change. It shall reject analysis records as methods and report an unsupported, corrupt, oversized, or wrong-type file without changing the library or current workspace.

> **FR-24** — A method import with a name or stable-identity conflict shall show the incoming and local types and versions and offer only the applicable Replace, Import as Copy, or Cancel choices. It shall not silently replace an item, replace across method types, downgrade an existing definition, or change the current result.

> **FR-25** — A missing method store shall open with standard and curated methods and empty user sections. A corrupt, inconsistent, or future-version store shall remain untouched, prevent user-library mutation until recovery, explain the problem, and leave standard and curated calculations available.

### Provenance and Explicit Export

> **FR-26** — Every accepted calculated or replayed result shall expose exactly one immutable, inspectable analysis record bound to the displayed pixels, source, method snapshot, execution mode, and completed job. Changing the source or effective method request shall remove access to the prior record and result export until a matching result completes, except while a replacement source is still being imported under FR-05.

> **FR-27** — The record inspector shall identify whether the result was calculated or replayed, show target source and method provenance, distinguish any replay origin from target-derived values, expose the documented matrices and channel conventions, and state that enhanced color is exploratory evidence rather than a biological or scientific conclusion.

> **FR-28** — An explicit record export shall write the existing deterministic `org.kltimage.analysis-record` version-1 JSON for standard RGB/Lab calculations or the existing version-2 extension for custom-space calculations and replay, with the same schema meanings and canonical bytes as Mac for the same immutable record. Analysis records shall remain documentary and never become executable method input.

> **FR-29** — The user shall be able to explicitly export the current full-resolution enhanced image as PNG, TIFF, or JPEG to a chosen Files destination or share destination. Export shall retain the accepted source's oriented pixel dimensions, follow the existing alpha policy for each format, and never modify the source or automatically save a copy to Photos.

> **FR-30** — Canceling an image, record, or method export shall create no destination artifact. Encoding or destination-write failure shall report the error, leave the accepted workspace and library unchanged, and leave no partial final-named document under the app's control.

> **FR-31** — The app shall keep source images, results, records, and method documents in the app or the user-selected provider until the user chooses an export or share action. It shall not create a source sidecar, image history, project, account, app-managed upload, or automatic cross-device sync.

## Non-Functional Requirements

> **NFR-01 — Scientific parity:** For identical decoded 8-bit sRGB source pixels and identical immutable method data, iOS and Mac calculations, frozen replay, source fingerprints, and record values shall match the established reference fixtures and documented floating-point tolerances; any required platform-specific rounding tolerance shall be explicit in the fixture rather than a changed scientific rule.

> **NFR-02 — Determinism:** Repeated work on the same supported device and architecture shall produce identical enhanced pixel bytes and canonical document bytes for unchanged inputs; exports shall contain no volatile timestamp or device path.

> **NFR-03 — Compatibility:** iOS/iPadOS 18 or later shall be the minimum OS for the mobile target. The macOS target shall continue to build and run on macOS 14 or later, retaining its 64-million-pixel ceiling, formats, document compatibility, and established regression behavior.

> **NFR-04 — Memory safety:** The fixed iOS 26-million-pixel and 256 MiB encoded-file boundaries shall be enforced before expensive allocation or staging in both Files and Photos paths. The full workflow, including comparison and export, shall complete without memory termination on the lowest-memory supported iPhone and iPad used for release verification; any failure to meet this criterion shall require a documented lower fixed cap before release.

> **NFR-05 — Responsiveness:** Normal touch, sheet dismissal, navigation, and cancellation controls shall remain responsive during maximum-supported-size calculation or replay. Cancellation shall stop active work and make the busy state disappear without publishing stale pixels or a stale record.

> **NFR-06 — Accessibility:** VoiceOver, Dynamic Type, sufficient contrast, Reduce Motion, non-color-only status, and accessible alternatives for zoom, precision region entry, and slider movement shall cover both form factors and all library, analysis, error, comparison, and export actions.

> **NFR-07 — Local data and security:** App-owned processing shall work offline. Imported files shall be treated as bounded data with no executable content, path traversal, external resolution, or implicit network transfer; only a user-selected system provider or share destination may move data outside the app.

> **NFR-08 — Persistence integrity:** Method-library changes and app-controlled document writes shall be atomic; an interrupted or failed write shall preserve the last valid store or destination state. Source pixels, results, regions, records, and ordinary workspace settings shall not persist as an app history.

> **NFR-09 — Format fidelity:** Supported orientation, color conversion, transparent-pixel handling, alpha retention or JPEG flattening, and output dimensions shall match the Mac scientific and export contracts across JPEG, PNG, TIFF, and HEIC input fixtures.

> **NFR-10 — Distribution:** The first iOS delivery channel shall be a signed TestFlight build distributed through App Store Connect to verified testers; it shall use iOS provisioning and verification separate from the Mac Developer ID, notarization, ZIP, and GitHub Release path. Public App Store publication requires a later explicit release decision.

> **NFR-11 — Testability:** Numerical parity, method codecs, resource-boundary rejection, import conflicts, result currency, cancellation, and export data shall be independently testable without relying on manual visual inspection; device testing shall cover a lowest-memory supported iPhone and iPad plus representative current devices.

> **NFR-12 — Scientific communication:** Interface guidance and exported records shall distinguish calculation from replay, explain that compression, sensor noise, lighting, and gamut clipping can affect results, and shall never claim that enhanced color proves a biological feature.

## Out of Scope

- Changing the decorrelation-stretch algorithm, RGB/Lab definitions, curated or user-space semantics, frozen-recipe behavior, or any versioned document schema.
- Raising the Mac 64-million-pixel ceiling, accepting mobile sources above the stated iOS cap, or adding tiled or out-of-core processing.
- Camera capture inside KLT Image, RAW decoding, automated segmentation, batch work, multi-image projects, or analysis history.
- Automatic iCloud or other cross-device synchronization, accounts, a backend, app-managed uploads, or a shared image library. A user may explicitly select an OS provider or share destination.
- Scientific classification, quantitative conclusions, biological proof, or a new analysis method.
- Replacing the Mac app or distributing iOS through the Mac GitHub ZIP, Developer ID, or notarization channel.
- Public App Store publication in the first mobile delivery; that requires a separate approval after TestFlight verification.

## Open Questions

None — all product decisions are resolved in this document. The fixed 26-million-pixel iOS limit is subject to the release safety criterion in NFR-04: if the lowest-memory supported device fails, lower and record the fixed cap before shipping rather than adding a runtime fallback.

## Success Metrics

| ID | What's Being Verified | Pass Condition |
|---|---|---|
| QA-01 | Native targets and Mac continuity (FR-01, NFR-03) | The iOS app installs and launches on an iOS 18-or-later iPhone and iPad; the macOS 14-or-later Debug and Release suites and app build retain existing behavior. |
| QA-02 | Full-resolution Files and Photos import (FR-02, FR-04) | Supported JPEG, PNG, TIFF, and HEIC fixtures selected through both applicable system providers decode at the original oriented dimensions, yield the established 8-bit sRGB pixel fingerprint, and leave the source file unchanged. |
| QA-03 | Import errors and replacement transaction (FR-03, FR-05) | Denied, unavailable, unsupported, corrupt, canceled, and out-of-order replacement fixtures each show the applicable recovery action and preserve the prior accepted workspace; only the latest valid replacement installs, resets region/view state, and retains calculation choices. |
| QA-04 | Calculation choices and defaults (FR-06, FR-07) | Clean launch selects RGB, covariance, and whole image; RGB, Lab, every curated space, and an imported user space each calculate with independently selected covariance/correlation and whole-image/region settings. |
| QA-05 | Scientific calculation behavior (FR-08, NFR-01) | Cross-platform fixtures match established statistics and enhanced pixels within documented numerical tolerances for all method combinations; selected-region statistics affect the plan while the full source receives it, with matching limited-variation, transparency, gamut, and alpha behavior. |
| QA-06 | Invalid region behavior (FR-09) | No-region, empty, out-of-bounds, fewer-than-four-pixel, and insufficient-variation selections show specific editable errors, start no fallback calculation, and expose no export for the invalid request. |
| QA-07 | Fixed mobile limit and failure state (FR-10, NFR-04) | A source within both limits proceeds; a 26,000,001-pixel or larger source is rejected before full decode/allocation, and an encoded file above 256 MiB is rejected before full staging/decode with its stated limit. Rejection preserves current work and leaves no staged source, with no downsample, free-memory exception, or changed Mac limit. |
| QA-08 | Processing ownership and cancellation (FR-11, NFR-05) | During a maximum-size calculation/replay, normal UI remains responsive; Cancel stops the job, clears busy state, and publishes no partial or stale result, including when an older job completes after a newer one. |
| QA-09 | Frozen replay semantics (FR-12, FR-13) | Original-source replay matches the calculated enhanced pixel buffer byte-for-byte; different-source replay repeats identically, leaves recipe bytes unchanged, labels target and origin separately, reports applicable warnings, and does not compute target statistics. |
| QA-10 | Comparison modes (FR-14) | Original, Side-by-Side, Slider, and Processed are reachable on both devices; the unchanged source remains available and exported image pixels contain no overlay or labels. |
| QA-11 | Adaptive layout (FR-15, FR-18) | iPhone portrait and landscape keep image comparison reachable without a permanent controls overlay; iPad wide layouts show comparison and active analysis context together; rotation/window resizing preserves source, result, method, region, and mode. |
| QA-12 | Touch gesture ownership (FR-16) | A two-finger pinch zooms and a drag pans the registered source/result view on iPhone and iPad; Fit and accessible zoom controls work without gestures. Zoom leaves analysis, source-pixel region bounds, and export unchanged; dragging the Slider divider changes only reveal position, and editing a rectangle changes neither reveal nor pan until the edit ends. |
| QA-13 | Region precision and alignment (FR-17) | Touch and exact X/Y/width/height entry create, move, resize, replace, and clear one rectangle; its source-pixel bounds remain identical through zoom, pan, rotation, and mode changes, and the full-image application message is visible. |
| QA-14 | Library sections and persistence (FR-19, NFR-08) | All listed library sections open without an image; user methods survive relaunch, while no source image, result, region, record, or workspace history is restored. |
| QA-15 | Working-space actions (FR-20) | Create, inspect, edit, duplicate, rename, delete, import, and export work for user spaces; standard and curated definitions cannot be mutated but can be inspected and duplicated. |
| QA-16 | Saved-transform actions and snapshot safety (FR-21) | A valid calculated result can be saved, inspected, duplicated, renamed, deleted, imported, exported, and applied; later source-space edits or library changes leave its frozen bytes and an already current result unchanged. |
| QA-17 | Cross-platform method bytes (FR-22, NFR-02) | Mac-produced working-space and recipe documents import on iOS and vice versa; stable identity, definition version, coefficients, replay output, and repeated canonical SHA-256 checksums agree for equivalent items. |
| QA-18 | Strict method boundary (FR-23, NFR-07) | Wrong schema/version/type, unknown or missing fields, duplicate keys, invalid values, malformed JSON, an oversized method document, and an analysis record are rejected before mutation with no external resolution or executable behavior. |
| QA-19 | Import conflicts (FR-24) | Name and identity collisions display incoming/local type and version and permit only applicable Replace, Import as Copy, or Cancel; cross-type replacement and definition downgrade are unavailable and no choice alters the current result. |
| QA-20 | Library recovery (FR-25) | Missing store yields usable standard/curated methods and empty user sections; corrupt, inconsistent, and future stores are left byte-unchanged, block user-library writes, show recovery guidance, and still allow standard/curated calculation. |
| QA-21 | Current record lifecycle (FR-26) | Each accepted result has one record matching displayed source, request, mode, pixels, and job; invalidation immediately disables stale record/result export, while an in-progress source import retains the prior accepted workspace until replacement commits. |
| QA-22 | Provenance and scientific guidance (FR-27, NFR-12) | Calculated and replayed inspectors label target, origin where relevant, method, matrices, conventions, and exploratory limits correctly; no view claims target-derived replay statistics or biological proof. |
| QA-23 | Record compatibility and export (FR-28, NFR-02) | RGB/Lab calculated fixtures retain version-1 golden JSON bytes, custom/replayed fixtures retain version-2 schema and canonical bytes, repeated exports match SHA-256, and both method importers reject either record version. |
| QA-24 | Full-resolution image export (FR-29, NFR-09) | PNG, TIFF, and JPEG exports from calculated and replayed results match oriented source dimensions and established format-specific alpha behavior; no export alters the source or appears in Photos without an explicit user choice. |
| QA-25 | Export cancellation and write failure (FR-30, NFR-08) | Cancel creates no artifact; injected encode/write failures show an error, preserve accepted work and library, and leave no partial app-controlled final-named file. |
| QA-26 | Local-only workflow (FR-31, NFR-07) | Offline import, calculation, replay, library work, record inspection, and local export succeed; inspection finds no app-managed upload, source sidecar, automatic sync, or retained image/history store. |
| QA-27 | Mobile memory and device coverage (NFR-04, NFR-11) | Files and Photos paths, comparison, calculation, replay, record export, and image export complete at the final fixed cap on the lowest-memory supported iPhone and iPad without memory termination; representative current devices pass the same suite. |
| QA-28 | Accessibility (NFR-06) | VoiceOver and Dynamic Type checks on iPhone and iPad reach and explain all required controls, errors, region coordinates, slider values, library actions, statuses, and exports; Reduce Motion and contrast remain usable. |
| QA-29 | Independent deterministic verification (NFR-01, NFR-02, NFR-11) | Core fixture tests verify parity, codec bytes, cancellation, resource rejection, and result currency without UI automation; repeated device runs yield identical pixels/documents on each architecture within the declared cross-platform numerical tolerance. |
| QA-30 | iOS distribution isolation (NFR-10) | A signed TestFlight build installs through App Store Connect on verified iPhone and iPad testers; its provisioning and artifact checks are documented separately, and the Mac GitHub release bytes and advertised channel remain unchanged. |
