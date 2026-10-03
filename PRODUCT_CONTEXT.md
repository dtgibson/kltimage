# KLT Image Product Context

## Product

KLT Image is a native Mac, iPhone, and iPad scientific-imaging tool for revealing subtle color structure through Karhunen–Loève decorrelation stretch while keeping the unchanged photograph available for interpretation.

## Current Capabilities

- **Interactive analysis:** Opens JPEG, PNG, TIFF, and HEIC images and combines covariance or correlation analysis with whole-image or single-rectangle statistical sampling.
- **Transparent working spaces:** Calculates in standard RGB and CIE Lab D65 or documented curated and user-defined reversible three-channel spaces over either base.
- **Local method library:** Keeps user working spaces and saved transforms in a narrowly scoped sandboxed library with explicit inspect, rename, duplicate, edit where applicable, delete, export, and strict import workflows.
- **Frozen transform replay:** Saves the complete accepted transform recipe and applies its captured mathematics unchanged without refitting statistics or output mapping to the target image.
- **Calculated/replayed provenance:** Keeps one immutable current record that identifies how the result was produced, preserves its exact source and method snapshot, and exports deterministic versioned JSON.
- **Comparison, replacement, and export:** Presents Original, Side-by-Side, Slider, and Processed views with zoom up to 1000% relative to Fit, keeps slider reveal dragging independent from registered-image panning, preserves the accepted workspace while a replacement decodes or rolls back, atomically installs successful replacements, and exports the current full-resolution result as PNG, TIFF, or JPEG.
- **iPhone and iPad analysis:** Provides a touch-first native workspace for local image import, full-resolution analysis and comparison, source-region selection, saved methods, provenance inspection, and explicit export.
- **Batch processing:** Processes up to 100 selected images on Mac, iPhone, and iPad using independent whole-image calculation or unchanged saved-transform replay, saving full-resolution results and optional analysis JSON to a chosen folder with individual outcomes.

## Scientific Behavior

- Inputs are oriented and converted to 8-bit sRGB before analysis.
- Every calculation starts from the unchanged source; whole-image or rectangular source-pixel statistics establish one deterministic, bounded transform that is applied to the complete image.
- Covariance preserves the variables' original scale, while correlation normalizes stable variables; Lab processing uses CIE 1976 L*a*b* with D65 and clips finite out-of-gamut results when returning to sRGB.
- The source stays unchanged. Enhanced colors are exploratory visual evidence, not a scientific conclusion.
- High-resolution or lossless sources are preferred because the transform can amplify compression artifacts and sensor noise along with subtle color differences.

## Platform and Architecture

- macOS 14 or later and iOS/iPadOS 18 or later, using Swift 6 and SwiftUI with AppKit on Mac and UIKit/PhotosUI on iPhone and iPad.
- Core Graphics and ImageIO handle local image conversion and export.
- The shared, independently testable scientific core owns numerical and image-processing behavior; each platform app owns its native presentation and file workflows.
- There is no backend, database, account system, or product network path; persistence is limited to the local method library and anonymous temporary-file cleanup reservations, with no image history, saved queue, or persistent file access.
- Batches process one full-resolution image at a time, preserve originals and existing destination files, and retain completed outputs when stopped; mobile runs require the foreground and never resume automatically.
- Full-frame processing has a fixed 64-million-pixel ceiling on Mac and a fixed 26-million-oriented-pixel and 256 MiB encoded-source boundary on iOS; larger images require a future tiled or out-of-core pipeline.
- Developer ID-signed, Apple-notarized, stapled, and independently verified KLT Image 1.4.0 build 10 is live on GitHub, the canonical Mac production channel; Build 8 is the trusted rollback release.
- The separate iOS 1.1 (3) build is processed and available to the existing internal TestFlight group with one tester; installation of this build and on-device workflows remain unverified, and no public App Store release has occurred.

## Deferred Scope

- In-app analysis history or projects and built-in multi-record comparison, charting, or aggregation.
- Tiled or out-of-core processing for images above 64 megapixels.
- Durable or background queues, watched folders, pooled batch statistics, and per-image batch regions or method overrides.
