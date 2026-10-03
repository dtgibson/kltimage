# Strategic Brief — Batch Processing

Status: Complete. The user approved both scientific modes ("Please build both, and give the user the option to choose") and Mac, iPhone, and iPad together ("all platforms please"). Remaining scope decisions were resolved under the user's Autopilot instruction.

## What We're Building

A local batch workflow for Mac, iPhone, and iPad that lets a user select photographs, choose a method and output configuration, and explicitly create full-resolution enhancements with a visible outcome for every input. Each batch offers a clear choice between calculating a fresh transform for each photograph and replaying one saved frozen transform unchanged across all photographs, preserving the sources and the product's exploratory scientific purpose.

## Why Now

The user selected batch processing from the roadmap after the product shipped transparent working spaces, saved transform replay, and native mobile workflows. The shared scientific core already provides the two different operations a useful batch needs: independent image-specific calculation and unchanged application of a captured recipe. Batch processing earns this build slot by removing repeated import, method selection, and export actions while preserving what each result means.

## The User Problem

A researcher, naturalist, photographer, or image analyst reviewing a set of photographs currently repeats a single-image workflow for every file. That repetition adds effort and makes it harder to keep method choices and exported results organized. They need an explicit, bounded run whose outputs remain attributable to their sources, including when one image fails or they stop before the end.

## Success Criteria

- A user can select multiple supported photographs, review the selected inputs and intended outputs, choose a method, and start one explicit batch action.
- In independent calculation mode, each photograph uses its own whole-image statistics with the selected working space and matrix mode. Its result matches the existing single-image calculation with equivalent inputs and settings.
- In frozen replay mode, every target uses the same captured recipe, including its output mapping, without refitting any target statistics. Its result matches existing single-image replay of that recipe.
- The user can distinguish calculation from replay before starting and in the run's outcome. Replay never claims that the target supplied the recipe's original sample or statistical fit.
- Each successful output retains the source's oriented full resolution and existing format/alpha behavior. No input is silently downsampled or modified.
- Duplicate source names and existing destination files cannot overwrite each other or the original photographs; output naming remains understandable and traceable to each input.
- Progress identifies the current item and completed, failed, canceled, or unprocessed items. One invalid input does not erase successful work or prevent other valid inputs from being attempted.
- Cancellation prevents queued work from starting, stops active work cooperatively, and accurately reports which outputs were already committed. Partial work is never described as a completed batch.
- When the user elects to export analysis records, each JSON document belongs to the exact source, method snapshot, and result exported for that item and uses the existing compatible record format.
- The existing interactive workspace and local method library remain intact. Batch processing remains responsive and bounded without keeping the entire set decoded in memory.

## Scope

- A dedicated, foreground batch workflow alongside the interactive workspace on Mac, iPhone, and iPad in this release.
- Explicit selection and review of multiple JPEG, PNG, TIFF, or HEIC inputs through native platform file workflows. On mobile, use the established Files and Photos access model; request only user-selected inputs.
- An explicit choice between independent calculation and frozen replay, with one immutable method snapshot per run.
- For calculated batches, whole-image statistics only, with existing standard, curated, and user-defined working spaces and covariance/correlation modes. Clearly require whole-image calculation rather than silently inheriting or dropping an interactive region.
- For replay batches, one selected saved transform copied into the run's immutable request. A recipe originally calculated from a region remains valid; that region describes its origin, not a region to impose on each target.
- One output image format per run from existing PNG, TIFF, and JPEG export support, with PNG as the default. The user explicitly chooses the destination and starts the export-producing run after seeing its output choices.
- Optional per-image analysis JSON alongside the enhanced images, explicitly selected in the run setup and off by default, matching the current product's separate, user-directed record export. This is documentary provenance, not a new batch report or executable method.
- A new, uniquely named set of output files with safe collision handling. Never silently replace existing files. Native destination presentation may differ by platform, but the user must understand what is saved and where.
- A bounded queue that processes one full-resolution image at a time, releases completed image buffers, supports cancellation, and shows a per-item outcome and a concise final count. Inputs may fail independently; a shared destination failure should stop further writes with clear recovery guidance.
- Existing per-image limits: 64 million pixels on Mac; 26 million oriented pixels and 256 MiB encoded input on iOS. The Planner and Architect must define bounded intake/staging and output-storage behavior; selecting many inputs must not bypass these protections.
- Temporary, app-owned staging only where native providers/export require it, with bounded storage and cleanup. No saved batch history, queued source bookmarks, or automatic reopening of a past run.

## Out of Scope

- Pooled statistics across images, automatic color matching, calibration, or claims that identical settings make independently calculated colors quantitatively comparable.
- Per-image regions, normalized region propagation, per-item method overrides, automatic segmentation, or silently applying the current interactive selection across a batch.
- New transform mathematics, new working spaces, new image formats, or an increase to existing image limits.
- Recursive folder scanning, watched folders, command-line automation, scheduled jobs, parallel multi-image processing, or an unattended background service.
- Durable queues, pause/resume after relaunch, guaranteed continuation while iOS is backgrounded, cloud processing, synchronization, accounts, or a project/history database.
- Batch comparison galleries, quantitative aggregation, charts, exported batch reports, and automated interpretation of enhanced images.
- Automatic Photos-library writes, replacement of originals, or automatic publication/sharing of outputs.

## Key Decisions

- **Authorized strategy expansion:** Batch processing was excluded from the original v1 founding scope and remains deferred in current product context, but the user explicitly selected it for this new feature run. This extends the same local exploratory-imaging purpose and audience; it does not reopen unrelated deferred capabilities.
- **User-approved method scope:** Include both independent calculation and exact frozen replay; the user selects one mode per batch.
- **User-approved platform scope:** Ship batch processing on Mac, iPhone, and iPad together. The historically Mac-only founding brief does not narrow the current product or this feature.
- **Scientific distinction:** A working space establishes coordinates for a new fit; a saved transform replays captured mathematics. A batch must preserve this existing type and language boundary, and each run uses one mode.
- **Region policy:** Calculated batches use whole-image statistics. Users needing one region-derived method across a set can create a saved transform in the interactive workflow and choose frozen replay.
- **Explicit artifacts:** Starting a batch authorizes only the selected images and optional records at the chosen destination. Show those choices before starting; do not add undisclosed manifests, reports, history, or automatic exports elsewhere.
- **Snapshot ownership:** Method/library edits during or after a run cannot change its accepted request or result provenance. Item completion and export must be tied to the correct run and item, preserving the existing immutable result/record contract.
- **Failure policy:** Continue after an item-specific read, validation, or processing failure; retain successful output. Treat cancellation and shared destination failures distinctly from a fully successful run, and never report an item complete if a requested artifact failed to save.
- **Platform lifecycle:** This is an active-app workflow. Define visible mobile interruption and cleanup behavior without promising background execution or durable recovery. Exact destination mechanics and resource caps belong in the PRD and architecture.
- **Verification and delivery:** Use the development Mac and local simulators only; no physical-device access. Native provider behavior and TestFlight installation can be verified only by the user and testers. Development/design previews use verified tailnet-only HTTPS Tailscale links; Mac GitHub releases and iOS TestFlight retain their existing independent release requirements.

Strategy evidence: `product-brief.md`, `PRODUCT_CONTEXT.md`, `ROADMAP.md`, `CLAUDE.md`, `DECISIONS.md`, `pipeline.config.json`, `pipeline/session-state.json`, `pipeline/batch-processing/run-context.md`, and a bounded read of the shared analysis, recipe, image-pipeline, and existing workspace contracts. No new market or scientific claims are inferred from this evidence.
