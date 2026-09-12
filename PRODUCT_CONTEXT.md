# KLT Image Product Context

## Product

KLT Image is a native Mac scientific-imaging tool for revealing subtle color structure through Karhunen–Loève decorrelation stretch while keeping the unchanged photograph available for interpretation.

## Current Capabilities

- **Interactive decorrelation-stretch workflow:** Opens JPEG, PNG, TIFF, and HEIC images; combines RGB or CIE Lab D65 processing with covariance or correlation analysis and whole-image or single-rectangle statistical sampling; compares Original, Split, and Enhanced views; and exports full-resolution PNG, TIFF, or JPEG results.

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
- Developer ID-signed, notarized, and stapled Build 4 is the advertised private-tailnet release; its exact served ZIP passed checksum, quarantine, Gatekeeper, and launch verification. The affected Build 3 package remains hosted only as an unadvertised rollback artifact. Broad public distribution remains unapproved because the existing QA evidence debt is unchanged.

## Deferred Scope

- Exported transform data and reproducible quantitative analysis.
- Tiled or out-of-core processing for images above 64 megapixels.
- Custom color spaces, saved transforms, and batch processing.
