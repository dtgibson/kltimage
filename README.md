# KLT Image

KLT Image is a focused, native Mac app for revealing subtle color structure in photographs with a Karhunen-Loeve decorrelation stretch. It keeps the unchanged photograph available throughout the workflow so the enhanced result can be interpreted beside its source.

The first release is intentionally narrow and testable. It performs a whole-image covariance transform in RGB, provides Original, Split, and Enhanced views, and exports the full-resolution result.

## Requirements

- macOS 14 or later
- Apple silicon or Intel Mac

## Download

Download the current build from [GitHub Releases](https://github.com/dtgibson/kltimage/releases/latest).

The downloadable app is ad-hoc signed and sandboxed, but it is not Developer ID-signed or notarized by Apple. macOS may ask you to confirm that you want to open it. If you prefer, build the app from source in Xcode.

## What it does

- Opens JPEG, PNG, TIFF, and HEIC images
- Converts the oriented source to an 8-bit sRGB working image
- Applies a deterministic covariance-based RGB decorrelation stretch
- Preserves the original image for visual comparison
- Synchronizes zoom and pan in Split view
- Exports full-resolution PNG, TIFF, or JPEG results
- Preserves transparency in PNG and TIFF exports
- Processes images locally without accounts, uploads, or network services
- Supports keyboard access, VoiceOver labels and announcements, and reduced motion

## Using the app

Open a photograph and processing begins automatically. Switch among Original, Split, and Enhanced to compare the result. Use the information button beside Whole-image covariance to inspect the method and component-stability result. Export Result writes the enhanced image without changing the source file.

Higher-resolution and lossless sources usually produce cleaner results. The transform can amplify compression blocks, sensor noise, and other small variations along with the color structure you want to study.

## Method

KLT Image computes the RGB mean and sample covariance across all image pixels using an online covariance calculation. It diagonalizes the symmetric covariance matrix with a deterministic orthonormal eigendecomposition. Numerically stable principal components are scaled toward the largest component variance, with gain bounded to avoid uncontrolled noise amplification. The inverse eigenvector basis maps the values back to RGB, then one uniform scale fits the transformed values into the available output range.

The unchanged decoded source buffer is kept separately from the result. Processing is cancellable and runs away from the main user-interface thread.

Karhunen-Loeve transform, principal component analysis, Hotelling transform, and decorrelation stretch refer to closely related ideas in this context. Michael Jon Harman's [DStretch algorithm description](https://www.dstretch.com/AlgorithmDescription.html) provides helpful background and references.

## Scientific limits

This is an exploratory visualization tool, not a measurement or biological conclusion. The current transform:

- Uses whole-image statistics, so a bird's background can influence the result
- Operates on 8-bit sRGB values rather than linear-light RGB or a perceptual Lab space
- Uses covariance only; correlation-matrix processing is not yet available
- Can magnify compression artifacts, noise, color-management effects, and lighting differences
- Treats fully transparent decoded pixels as having no recoverable RGB value while preserving their alpha

Keep the original visible when interpreting an enhancement. Use controlled capture conditions and lossless source files when repeatability matters.

## Build from source

Open `KLTImage.xcodeproj` in Xcode 26 or later, select the `KLTImage` scheme and `My Mac`, then build or run it. The repository includes the generated Xcode project, so XcodeGen is not required for a normal build.

To run the tests from a terminal:

```sh
xcodebuild \
  -project KLTImage.xcodeproj \
  -scheme KLTImage \
  -configuration Debug \
  -destination 'platform=macOS' \
  test
```

`project.yml` is the source of truth for project settings. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) and run `xcodegen generate` after changing it.

The numerical and image-processing code lives in `KLTCore`; the SwiftUI and AppKit application code lives in `KLTImage`.

## Current status

Version 1.0.0 build 2 is the first public release. Planned work includes Lab processing, correlation mode, selectable-region sampling, and export of transform data for reproducible quantitative analysis.

## License

KLT Image is licensed under the [GNU Affero General Public License v3.0](LICENSE). The bundled IBM Plex fonts are distributed under the SIL Open Font License; their license files are included beside the font resources.
