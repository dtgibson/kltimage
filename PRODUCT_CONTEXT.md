# KLT Image Product Context

## Product

KLT Image is a native Mac scientific-imaging tool for revealing subtle color structure through Karhunen–Loève decorrelation stretch while keeping the unchanged photograph available for interpretation.

## Current Capabilities

- **Interactive decorrelation-stretch workflow:** Opens JPEG, PNG, TIFF, and HEIC images; combines RGB or CIE Lab D65 processing with covariance or correlation analysis and whole-image or single-rectangle statistical sampling; compares Original, Split, and Enhanced views; and exports full-resolution PNG, TIFF, or JPEG results.
- **Reproducible analysis:** Keeps an immutable record for the exact current result, exposes its decoded-source fingerprint, request, sampling geometry, statistics, eigensystem, transform, and output mapping, and exports the record as deterministic versioned JSON.

## Scientific Behavior

- Inputs are oriented and converted to 8-bit sRGB before analysis.
- Every calculation starts from the unchanged source; whole-image or rectangular source-pixel statistics establish one deterministic, bounded transform that is applied to the complete image.
- Covariance preserves the variables' original scale, while correlation normalizes stable variables; Lab processing uses CIE 1976 L*a*b* with D65 and clips finite out-of-gamut results when returning to sRGB.
- The source stays unchanged. Enhanced colors are exploratory visual evidence, not a scientific conclusion.
- High-resolution or lossless sources are preferred because the transform can amplify compression artifacts and sensor noise along with subtle color differences.

## Platform and Architecture

- macOS 14 or later, Swift 6, SwiftUI, and AppKit.
- Core Graphics and ImageIO handle local image conversion and export.
- The independently testable `KLTCore` framework owns numerical and image-processing behavior; the app target owns presentation and native file workflows.
- There is no backend, database, account system, persistence layer, or network path.
- Full-frame processing has a fixed 64-million-pixel ceiling; larger images require a future tiled or out-of-core pipeline.
- Developer ID-signed, Apple-notarized, and stapled KLT Image 1.2.0 build 5 is the current release through public GitHub Releases and a tailnet-only Tailscale mirror; both channels serve the same independently verified ZIP, with Build 4 retained as the trusted rollback artifact.

## Deferred Scope

- In-app analysis history or projects, imported or reapplied transforms, and built-in multi-record comparison, charting, or aggregation.
- Tiled or out-of-core processing for images above 64 megapixels.
- Custom color spaces, saved transforms, and batch processing.
- Opening a replacement image while another is loaded remains a separately tracked Fix.
