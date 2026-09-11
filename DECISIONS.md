# KLT Image Decisions

## Ship the narrow RGB covariance foundation first — 2026-09-10

**Decision:** The first shipped build uses deterministic whole-image RGB covariance only. Lab processing, correlation mode, and selectable-region sampling remain the next product step, even though the founding brief describes the broader destination.

**Rationale:** A single mathematically testable path establishes whether decorrelation stretch is visually useful for bird-feather imagery before additional choices complicate interpretation. Whole-image sampling also provides a clear baseline for later region-based comparisons.

**Implications:** Future analysis controls must preserve the existing transform as a reproducible baseline. New modes should identify their color space, matrix basis, and sampling region explicitly, and quantitative export should record those settings.

## Keep results exploratory and local — 2026-09-10

**Decision:** KLT Image keeps image data on the Mac, retains no project history, and presents enhanced colors as exploratory visual evidence rather than biological measurement or proof.

**Rationale:** The technique amplifies variance, including compression artifacts and sensor noise, so the unchanged source and clear method disclosure are essential to responsible interpretation.

**Implications:** New features must preserve side-by-side context, avoid unsupported scientific claims, and require explicit user action for every exported artifact.
