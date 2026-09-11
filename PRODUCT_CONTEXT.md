# KLT Image Product Context

## Product

KLT Image is a native Mac scientific-imaging tool for revealing subtle color structure through Karhunen–Loève decorrelation stretch while keeping the unchanged photograph available for interpretation.

## Current Capabilities

- **Core RGB enhancement workflow:** Opens JPEG, PNG, TIFF, and HEIC images; applies deterministic whole-image RGB covariance decorrelation stretch; compares Original, Split, and Enhanced views; and exports full-resolution PNG, TIFF, or JPEG results.

## Scientific Behavior

- Inputs are oriented and converted to 8-bit sRGB before analysis.
- RGB covariance uses every image pixel, diagonalizes the matrix through a deterministic orthonormal eigendecomposition, equalizes numerically stable components with bounded gain, applies the inverse basis, and fits the result with one uniform output scale.
- The source stays unchanged. Enhanced colors are exploratory visual evidence, not a scientific conclusion.
- High-resolution or lossless sources are preferred because the transform can amplify compression artifacts and sensor noise along with subtle color differences.

## Platform and Architecture

- macOS 14 or later, Swift 6, SwiftUI, and AppKit.
- Core Graphics and ImageIO handle local image conversion and export.
- The independently testable `KLTCore` framework owns numerical and image-processing behavior; the app target owns presentation and native file workflows.
- There is no backend, database, account system, persistence layer, or network path.

## Deferred Scope

- Lab processing, correlation-matrix mode, and selectable-region sampling.
- Exported transform data and reproducible quantitative analysis.
- Custom color spaces, saved transforms, and batch processing.
