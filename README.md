# KLT Image

KLT Image is a focused, native Mac app for revealing subtle color structure in photographs with a Karhunen-Loeve decorrelation stretch. It keeps the unchanged photograph available throughout the workflow so the enhanced result can be interpreted beside its source.

KLT Image supports standard RGB and Lab processing plus documented curated and user-defined reversible three-channel working spaces. It can calculate a transform from whole-image or selected-region statistics, or replay a saved transform without refitting it to the target image. Every method enhances the complete image and keeps the unchanged source available in Original, Side-by-Side, Slider, and Processed views.

## Requirements

- macOS 14 or later
- Apple silicon or Intel Mac

## Download

Download KLT Image 1.3.1 build 7 from [GitHub Releases](https://github.com/dtgibson/kltimage/releases/download/v1.3.1/KLT-Image-1.3.1-build-7.zip).

SHA-256: `620044cc2191ee15c229d0abbdb0839eae703852081b1a179782e7942f10a0a1`

Build 7 is a universal Apple silicon and Intel app signed with Developer ID, notarized by Apple, stapled, and independently verified under quarantine. GitHub is the canonical release channel. Trusted Build 6 remains available as the rollback release.

## What it does

- Opens JPEG, PNG, TIFF, and HEIC images
- Converts the oriented source to an 8-bit sRGB working image
- Applies deterministic decorrelation stretch in standard RGB, CIE Lab D65, or curated and user-defined reversible three-channel working spaces
- Supports covariance or correlation analysis
- Uses either whole-image statistics or one rectangular source-pixel sample
- Applies a region-derived transform to the complete image rather than cropping or masking it
- Maintains a local method library whose working spaces and saved transforms can be inspected, renamed, duplicated, deleted, exported, and strictly imported as inert JSON
- Saves an accepted calculation as an immutable transform that can be replayed without refitting target statistics
- Creates a versioned analysis record that distinguishes calculated from replayed results and captures the exact source, settings, and transform provenance
- Exports deterministic, versioned analysis JSON for archiving and external comparison
- Preserves the original image for visual comparison
- Synchronizes zoom and pan in Side-by-Side and Slider views
- Exports full-resolution PNG, TIFF, or JPEG results
- Preserves transparency in PNG and TIFF exports
- Processes images locally without accounts, uploads, or network services
- Supports keyboard access, VoiceOver labels and announcements, and reduced motion

## Using the app

Open a photograph and processing begins with RGB, Covariance, and Whole image selected. Choose another working space or matrix mode to recalculate from the unchanged source, or choose Selected region and draw a rectangle over the source pane or enter exact source-pixel bounds. Open Methods to inspect the built-in spaces, create a user-defined space, or save and replay an accepted transform. Switch among Original, Side-by-Side, Slider, and Processed to compare the result. Analysis Record shows whether the result was calculated or replayed and exposes its exact source fingerprint, settings, matrices, transform, and output mapping. Export JSON saves the deterministic analysis sidecar; Export Result writes the current full-resolution enhancement without changing the source file.

Higher-resolution and lossless sources usually produce cleaner results. The transform can amplify compression blocks, sensor noise, and other small variations along with the color structure you want to study.

## Method

KLT Image calculates a mean and covariance from either every pixel or one rectangular sample in RGB, CIE Lab D65, or a validated reversible affine working space. Covariance preserves the original variable scale, while correlation normalizes numerically stable variables to unit variance. It diagonalizes the resulting symmetric matrix with a deterministic orthonormal eigendecomposition, applies bounded component gains to the full image, and returns the result to displayable sRGB while preserving alpha. A saved transform freezes the accepted working-space revision, center, transform, and output mapping, so replay applies those values unchanged without accumulating target statistics or solving a new transform.

The unchanged decoded source buffer is kept separately from the result. Processing is cancellable and runs away from the main user-interface thread.

Karhunen-Loeve transform, principal component analysis, Hotelling transform, and decorrelation stretch refer to closely related ideas in this context. Michael Jon Harman's [DStretch algorithm description](https://www.dstretch.com/AlgorithmDescription.html) provides helpful background and references.

## Scientific limits

This is an exploratory visualization tool, not a measurement or biological conclusion. The current workflow:

- Uses 8-bit sRGB as its decoded source representation; RGB and Lab are alternative exploratory working spaces, not ranks of accuracy
- Lets a rectangle control the statistics, but still applies the resulting transform to the complete image
- Clips finite out-of-gamut values when transformed Lab colors return to displayable sRGB
- Can magnify compression artifacts, noise, color-management effects, and lighting differences
- Treats fully transparent decoded pixels as having no recoverable RGB value while preserving their alpha
- Processes full frames up to a fixed limit of 64 megapixels

Keep the original visible when interpreting an enhancement. Use controlled capture conditions and lossless source files when repeatability matters.

## Build from source

Open `KLTImage.xcodeproj` in Xcode 26 or later, select the `KLTImage` scheme and `My Mac`, then build or run it. The repository includes the generated Xcode project, so XcodeGen is not required for a normal build.

To run the tests from a terminal:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project KLTImage.xcodeproj \
  -scheme KLTImage \
  -configuration Debug \
  -destination 'platform=macOS' \
  test
```

`project.yml` is the source of truth for project settings. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) and run `xcodegen generate` after changing it.

The numerical and image-processing code lives in `KLTCore`; the SwiftUI and AppKit application code lives in `KLTImage`.

## Current status

Version 1.3.1 build 7 is published on GitHub Releases. A fresh GitHub download matches the approved artifact byte-for-byte and passes the repository's fail-closed Developer ID signing, notarization, stapling, checksum, quarantine, and Gatekeeper checks. The complete Debug suite passed 96/96 and the optimized ReleaseTests suite passed 98/98; both shipped fixes passed security review with no findings. GitHub is the sole current production channel, and trusted version 1.3.0 build 6 is the rollback release.

## License

KLT Image is licensed under the [GNU Affero General Public License v3.0](LICENSE). The bundled IBM Plex fonts are distributed under the SIL Open Font License; their license files are included beside the font resources.
