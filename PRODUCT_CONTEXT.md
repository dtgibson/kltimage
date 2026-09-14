# KLT Image Product Context

## Product

KLT Image is a native Mac scientific-imaging tool for revealing subtle color structure through Karhunen–Loève decorrelation stretch while keeping the unchanged photograph available for interpretation.

## Current Capabilities

- **Interactive analysis:** Opens JPEG, PNG, TIFF, and HEIC images and combines covariance or correlation analysis with whole-image or single-rectangle statistical sampling.
- **Transparent working spaces:** Calculates in standard RGB and CIE Lab D65 or documented curated and user-defined reversible three-channel spaces over either base.
- **Local method library:** Keeps user working spaces and saved transforms in a narrowly scoped sandboxed library with explicit inspect, rename, duplicate, edit where applicable, delete, export, and strict import workflows.
- **Frozen transform replay:** Saves the complete accepted transform recipe and applies its captured mathematics unchanged without refitting statistics or output mapping to the target image.
- **Calculated/replayed provenance:** Keeps one immutable current record that identifies how the result was produced, preserves its exact source and method snapshot, and exports deterministic versioned JSON.
- **Comparison and export:** Presents Original, Side-by-Side, Slider, and Processed views and exports the current full-resolution result as PNG, TIFF, or JPEG.

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
- There is no backend, database, account system, or product network path; persistence is limited to a narrowly scoped method-library file in sandboxed Application Support.
- Full-frame processing has a fixed 64-million-pixel ceiling; larger images require a future tiled or out-of-core pipeline.
- Developer ID-signed, Apple-notarized, and stapled KLT Image 1.3.0 build 6 is the current public GitHub and tailnet-only Tailscale release; both channels serve the same independently verified ZIP, with Build 5 retained as the trusted rollback artifact.

## Deferred Scope

- In-app analysis history or projects and built-in multi-record comparison, charting, or aggregation.
- Tiled or out-of-core processing for images above 64 megapixels.
- Batch processing, queues, and watched folders.
- Opening a replacement image while another is loaded remains a separately tracked Fix.
