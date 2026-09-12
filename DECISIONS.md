# KLT Image Decisions

## Ship the narrow RGB covariance foundation first — 2026-09-10

**Decision:** The first shipped build uses deterministic whole-image RGB covariance only. Lab processing, correlation mode, and selectable-region sampling remain the next product step, even though the founding brief describes the broader destination.

**Rationale:** A single mathematically testable path establishes whether decorrelation stretch is visually useful for bird-feather imagery before additional choices complicate interpretation. Whole-image sampling also provides a clear baseline for later region-based comparisons.

**Implications:** Future analysis controls must preserve the existing transform as a reproducible baseline. New modes should identify their color space, matrix basis, and sampling region explicitly, and quantitative export should record those settings.

## Keep results exploratory and local — 2026-09-10

**Decision:** KLT Image keeps image data on the Mac, retains no project history, and presents enhanced colors as exploratory visual evidence rather than biological measurement or proof.

**Rationale:** The technique amplifies variance, including compression artifacts and sensor noise, so the unchanged source and clear method disclosure are essential to responsible interpretation.

**Implications:** New features must preserve side-by-side context, avoid unsupported scientific claims, and require explicit user action for every exported artifact.

## Keep full-frame processing within a fixed 64 MP boundary — 2026-09-11

**Decision:** KLT Image supports full-frame processing up to 64,000,000 pixels with deterministic pre-decode and pre-allocation validation; the limit does not expand from volatile free-memory readings.

**Rationale:** A fixed ceiling gives users repeatable behavior and bounds the multi-buffer working set on the lowest-memory supported Mac class while covering common high-resolution cameras.

**Implications:** Images above 64 megapixels require a separately designed tiled or out-of-core processing path rather than a larger opportunistic allocation.

## Keep the current release private and local — 2026-09-11

**Decision:** The current ad-hoc-signed, unnotarized package is approved only for private/local distribution over the project's tailnet; broad public distribution is not approved.

**Rationale:** Core verification and security review found no open product defect, but 22 QA criteria retain evidence gaps across UI automation, VoiceOver, platform/runtime coverage, cancellation workflows, and dynamic privacy checks.

**Implications:** Public distribution requires closing the accepted evidence debt and producing a Developer ID-signed, notarized artifact without development entitlements, followed by verification of the exact package.
