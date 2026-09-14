# Strategic Brief — Custom Color Spaces and Reusable Transforms

## What We're Building

Turn KLT Image's current set of analysis choices into a small, transparent method library with two complementary capabilities:

- **Custom color spaces:** add a curated set of documented three-channel working-space presets, and let a technically informed user define, name, inspect, save, edit, duplicate, export, and import their own reversible three-channel working space.
- **Saved transforms:** let a user explicitly save the exact transform behind a current enhancement and apply that same frozen transform recipe to the current or another image without recalculating a covariance matrix or eigensystem.

A color-space definition and a saved transform remain distinct. A color space defines the variables in which KLT Image calculates a new decorrelation stretch. A saved transform freezes a particular calculation for exact replay and controlled reuse. The interface must always make clear which of those two paths produced the displayed result.

The feature is inspired by DStretch's use of modified YUV- and Lab-derived spaces, user-adjustable YXX/LXX spaces, and saved matrix-plus-colorspace files. It is not a DStretch compatibility layer. KLT Image will use its own documented definitions, validation rules, file formats, names, and scientific guardrails rather than copying opaque preset names or promising equivalent output.

## Why Now

Custom color spaces and saved transformation matrices were explicitly out of scope in the founding product brief, the Analysis Controls build, and the Reproducible Analysis build. That sequencing was intentional: KLT Image first needed a correct RGB baseline, then stable RGB/Lab, covariance/correlation, and region-sampling semantics, and finally an immutable record of the exact source, settings, transform, and output mapping behind every result.

Reproducible Analysis has now shipped those prerequisites. KLT Image can identify the decoded source, retain the actual applied matrix and output mapping, reject stale results, and export deterministic versioned records. Expanding scope now builds on an inspectable numerical protocol instead of introducing reusable but ambiguous visual effects. It also advances both items already named on the roadmap and directly answers the user's request to explore DStretch-inspired spaces while supporting their own.

The two capabilities belong together. New working spaces broaden the hypotheses a user can explore; saved transforms let a useful result become a controlled method that can be replayed or applied across related photographs. Together they move KLT Image from one-result-at-a-time exploration toward repeatable method development without taking on batch processing, projects, or cloud collaboration.

The relevant DStretch material supports the product opportunity while also showing where KLT Image should be more explicit. Its [algorithm description](https://www.dstretch.com/AlgorithmDescription.html) says that modified YUV- or Lab-derived spaces can emphasize different color distinctions, that users can design their own spaces, and that a calculated matrix can be saved and applied to other images for more consistent enhancement. Its [help documentation](https://www.dstretch.com/DStretchHelp.html) describes adjustable YXX/LXX multipliers and saving both the matrix and color space. These are workflow inspirations, not evidence that any preset is objectively better or appropriate for bird imagery.

## The User Problem

A researcher, naturalist, photographer, or image analyst can currently calculate and inspect a trustworthy decorrelation stretch, but each exploration is constrained to RGB or CIE Lab D65 and each calculated transform ends with the current image. That creates two gaps:

- RGB and Lab may not separate the particular color variation the user is investigating. The user needs a bounded way to define other three-channel coordinates without installing code, editing the app, or accepting an unexplained effect.
- When one image produces a useful transform, the user cannot replay it exactly after relaunch or apply the same method to related images. Recalculating on every target changes the matrix with each image's color distribution, so the results are not a controlled reuse of the original method.

The user needs to know, at a glance, whether a result was newly calculated or produced by a saved transform; which working-space definition was used; whether the recipe has been modified; and what clipping, gamut, or limited-variation behavior affects interpretation. They should be able to develop and reuse methods locally while keeping the unchanged source visible and without KLT Image implying that a dramatic false-color result proves a scientific finding.

## Success Criteria

- A user can choose RGB, Lab, or a curated custom working-space preset and calculate it with the existing covariance/correlation and whole-image/selected-region controls.
- The initial curated collection is small, technically documented, and useful for distinct exploration goals such as luma/chroma separation, red distinction, and blue/yellow distinction. Every preset exposes its base space, channel equations, coefficient values, channel names, and output behavior; no preset is labeled as inherently best or more accurate.
- A user can create a working space from an existing encoded-sRGB or CIE Lab D65 base by naming three channels and specifying finite affine channel equations. KLT Image derives and validates the inverse rather than accepting executable code.
- Singular, non-finite, numerically ill-conditioned, or unsupported custom definitions are rejected before processing with a specific explanation. The app never silently substitutes RGB, Lab, or a different definition.
- Curated and user-defined spaces run through the same immutable-source, cancellation, stale-result, alpha, region-sampling, numerical-stability, 64-megapixel, comparison, and full-resolution export guarantees as RGB and Lab.
- A user can explicitly save a valid current enhancement as a named reusable transform. Limited-variation identity results cannot masquerade as useful saved methods.
- A saved item captures a complete transform recipe rather than an unlabeled 3×3 array: the working-space definition and version, channel conventions, affine centering values, applied transform, output mapping and clipping policy, originating analysis method, source fingerprint, and exploratory-use notice.
- Applying a saved transform uses those frozen recipe values and does not silently recalculate covariance, correlation, eigenvectors, gains, centering, or output range from the target image.
- Reapplying a saved transform to its original decoded source produces the same enhanced pixels as the result from which it was saved. Applying it to another supported source is deterministic and visibly identified as reuse of that named recipe.
- A potentially clipped or visually poor result on a different source remains an honest application of the saved recipe. KLT Image explains the condition and lets the user return to calculated analysis; it does not silently adapt the recipe and still call it the same transform.
- User-created working spaces and saved transforms survive relaunch in a local library. Users can rename, duplicate, inspect, delete, and explicitly export or import them through a versioned, deterministic KLT Image recipe format.
- Import treats recipes as untrusted data: malformed, oversized, non-finite, singular, unsupported-version, or internally inconsistent files fail safely without changing the current source, result, or library.
- The active method, analysis record, and exported provenance identify whether the result was calculated or replayed and embed the exact custom definition or saved-recipe identity needed to understand it.
- Existing deterministic version-1 analysis JSON remains byte-compatible for existing RGB/Lab results. New protocol data is introduced through an explicitly versioned extension and a distinct transform-recipe document, not by reinterpreting version 1 or importing an analysis record as a recipe.
- RGB + covariance + whole image and all currently shipped RGB/Lab analysis combinations retain their established pixel, performance, accessibility, privacy, and export baselines.

## Scope

- A local method library with separate sections for user-defined working spaces and saved transform recipes.
- A small curated collection of KLT Image presets informed by the luma/chroma and Lab-derived ideas described by DStretch, with KLT-specific names, definitions, fixtures, and guidance.
- A bounded custom-space editor for three named affine channel equations over either the existing encoded-sRGB basis or CIE Lab D65 basis, including inverse and conditioning validation.
- Create, inspect, edit, duplicate, rename, delete, import, and export flows for user-defined working spaces. Editing a definition creates a visibly changed version and cannot retroactively alter a saved transform that captured an earlier definition.
- Explicitly saving the exact current calculated transform as a named recipe, including all affine and output-mapping state required for exact replay.
- Deterministic application of a saved recipe to one open image at a time, with a clear route back to calculated analysis.
- A versioned, canonical local interchange format for custom working spaces and transform recipes, with bounded parsing and atomic writes.
- An application-managed local store only for the user's method library. Images, analysis history, regions, and ordinary results remain transient unless the user explicitly exports them.
- Analysis-record and inspector evolution sufficient to describe custom definitions and distinguish calculated from replayed results while preserving the shipped version-1 contract.
- Clear guidance that color-space choice and transform reuse change exploratory visualization, can amplify noise or compression, and can clip colors; neither establishes a biological or scientific conclusion.
- Accessibility, keyboard operation, stale-result protection, deterministic fixtures, persistence migration tests, import hardening, and regression coverage across the existing workflow.

## Out of Scope

- DStretch preset, matrix-file, name, or pixel-output compatibility; the DStretch material is inspiration only.
- Arbitrary scripts, expressions, plug-ins, shader code, multidimensional LUTs, neural transforms, or more than three working channels.
- ICC profile authoring or import, device calibration, spectral color science, alternate reference whites, or replacing the app's decoded 8-bit sRGB source contract.
- Automatic selection or ranking of a color space, claims that a preset detects a pigment or biological feature, or labels such as “best,” “accurate,” or “scientific.”
- Silently fitting a saved transform's range, mean, gamut, or other parameters to each target while representing it as unchanged. Adaptive reuse can be considered later as a separately named method.
- Batch processing, watched folders, multi-image comparison, aggregation, or automatic application during image import.
- In-app image projects, analysis history, saved regions, undo history across launches, or importing version-1 analysis records as executable transforms.
- Cloud sync, accounts, collaboration, remote preset galleries, telemetry, or automatic sharing of source fingerprints or methods.
- Hue shifting, hue histogram equalization, saturation stretching, hue isolation, background flattening, segmentation, or other DStretch features unrelated to this build.

## Key Decisions

- Treat this as one **method-library** feature with two explicit artifact types, not one generic “preset” concept. Working spaces calculate new transforms; saved transform recipes replay frozen transforms.
- Use DStretch's workflow pattern—alternative spaces, user-created spaces, and saved matrix-plus-space recipes—as inspiration, while designing for KLT Image's bird-imagery audience, transparent methods, deterministic records, and local native workflow.
- Make every curated preset inspectable and express it through the same definition model available to users. Built-in status must not make a preset opaque or scientifically privileged.
- Bound user-defined spaces to reversible affine three-channel mappings over an existing supported base. This is expressive enough for the first luma/chroma- and Lab-derived experiments while remaining explainable, deterministic, testable, and safe to import.
- Save a complete affine transform recipe, not merely the displayed 3×3 matrix. The mean/offset, color-space conversion, channel conventions, output mapping, clipping policy, and version are part of what produced the pixels and therefore part of honest reuse.
- Define reuse as fixed application. The target image does not contribute new analysis statistics. This makes “same transform” testable and prevents image-specific adaptation from being hidden behind a reused name.
- Snapshot the custom working-space definition inside each saved transform. Later edits to the library definition do not change an existing recipe or its output.
- Add narrowly scoped persistence for user-created methods because “saved and reusable” must survive relaunch. Preserve the broader local-only boundary: no image library, analysis-history database, account, or network path.
- Keep portable recipes separate from analysis records. An analysis record documents one result; a recipe is an explicitly executable artifact. Separate versioned schemas avoid turning any historical record into code-like input by accident.
- Preserve the unchanged source, side-by-side comparison, explicit export actions, and exploratory-use warning for every custom or replayed result. More dramatic color separation increases the need for context, not the authority of the enhancement.
- Leave batch processing as the next independent capability. This feature creates a safe reusable method boundary that batch processing can consume later without coupling library semantics to automation now.
