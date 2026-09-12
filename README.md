# KLT Image

KLT Image is a focused, native Mac app for revealing subtle color structure in photographs with a Karhunen-Loeve decorrelation stretch. It keeps the unchanged photograph available throughout the workflow so the enhanced result can be interpreted beside its source.

KLT Image supports RGB or Lab processing, covariance or correlation analysis, and statistics from either the whole image or one rectangular sample. Every method enhances the complete image and keeps the unchanged source available in Original, Split, and Enhanced views.

## Requirements

- macOS 14 or later
- Apple silicon or Intel Mac

## Download

KLT Image 1.1.0 build 4 is available privately to members of the project's tailnet: [Download KLT Image](https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-preview/releases/KLT-Image-1.1.0-build-4.zip).

SHA-256: `4e884df54b06c393dbbb48c77bc96477b915dc4ba79cf26c6a29c7f59f672442`

Build 4 is a universal Apple silicon and Intel app signed with Developer ID, notarized by Apple, and stapled. The affected ad-hoc-signed Build 3 remains hosted only as an unadvertised rollback artifact and should not be used.

## What it does

- Opens JPEG, PNG, TIFF, and HEIC images
- Converts the oriented source to an 8-bit sRGB working image
- Applies deterministic decorrelation stretch in RGB or CIE Lab D65
- Supports covariance or correlation analysis
- Uses either whole-image statistics or one rectangular source-pixel sample
- Applies a region-derived transform to the complete image rather than cropping or masking it
- Preserves the original image for visual comparison
- Synchronizes zoom and pan in Split view
- Exports full-resolution PNG, TIFF, or JPEG results
- Preserves transparency in PNG and TIFF exports
- Processes images locally without accounts, uploads, or network services
- Supports keyboard access, VoiceOver labels and announcements, and reduced motion

## Using the app

Open a photograph and processing begins with RGB, Covariance, and Whole image selected. Choose another color space or matrix mode to recalculate from the unchanged source, or choose Selected region and draw a rectangle over the source pane or enter exact source-pixel bounds. Switch among Original, Split, and Enhanced to compare the result, use the information button to inspect the active method and stability result, and choose Export Result to write the current full-resolution enhancement without changing the source file.

Higher-resolution and lossless sources usually produce cleaner results. The transform can amplify compression blocks, sensor noise, and other small variations along with the color structure you want to study.

## Method

KLT Image calculates a mean and covariance from either every pixel or one rectangular sample in RGB or CIE Lab D65. Covariance preserves the original variable scale, while correlation normalizes numerically stable variables to unit variance. It diagonalizes the resulting symmetric matrix with a deterministic orthonormal eigendecomposition, applies bounded component gains to the full image, and returns the result to displayable sRGB while preserving alpha.

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

Version 1.1.0 build 4 is published on the private tailnet and has passed the repository's fail-closed Developer ID signing, notarization, stapling, checksum, quarantine, Gatekeeper, and launch checks. Broad public distribution remains unapproved until the documented QA evidence gaps are closed. The next planned feature is reproducible analysis with recorded settings and exported transformation data.

## License

KLT Image is licensed under the [GNU Affero General Public License v3.0](LICENSE). The bundled IBM Plex fonts are distributed under the SIL Open Font License; their license files are included beside the font resources.
