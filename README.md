# KLT Image

KLT Image is a native app for Mac, iPhone and iPad that reveals subtle color structure in photographs with a Karhunen-Loeve decorrelation stretch. It keeps the unchanged photograph available throughout the workflow so the enhanced result can be interpreted beside its source.

KLT Image supports standard RGB and Lab processing plus documented curated and user-defined reversible three-channel working spaces. It can calculate a transform from whole-image or selected-region statistics, or replay a saved transform without refitting it to the target image. Every method enhances the complete image and keeps the unchanged source available in Original, Side-by-Side, Slider, and Processed views.

## Requirements

- macOS 14 or later
- Apple silicon or Intel Mac
- iOS/iPadOS 18 or later for the separate internal TestFlight app

## Download

Download KLT Image 1.4.0 build 10 from [GitHub Releases](https://github.com/dtgibson/kltimage/releases/download/v1.4.0/KLT-Image-1.4.0-build-10.zip).

SHA-256: `a67fc50bdd60fd2ea8ba4621316a67f51a42cd475d23616ca4d34b69d42206d4`

Build 10 adds batch processing for up to 100 images, with a choice of independent calculation or unchanged saved-transform replay. It is a universal Apple silicon and Intel app signed with Developer ID, notarized by Apple, stapled, and independently verified under quarantine. GitHub is the canonical Mac release channel. Trusted Build 8 remains available as the rollback release.

iOS 1.1 (3) is processed and available through the existing **KLT Image Internal** TestFlight group for iPhone and iPad. It is not a public App Store release; installation of this build remains unverified.

## What it does

- Processes batches of up to 100 selected images with independent whole-image calculation or unchanged saved-transform replay
- Saves each batch into a new folder with per-input outcomes and optional matching analysis JSON
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

Open **Batch** to select up to 100 images, choose **Calculate each image** or **Replay saved transform**, and review the format, optional analysis JSON and destination before starting. Each run creates a new folder and preserves earlier output. PNG is the default. Keep the app open in the foreground on iPhone and iPad; interruption stops the run without automatic resume. Matching calculation settings do not establish quantitative color comparability across independently fitted images.

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
- Processes full frames up to 64 megapixels on Mac or 26 million oriented pixels on iPhone/iPad

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

The numerical and image-processing code lives in `KLTCore`; native app code lives in `KLTImage` and `KLTImageIOS`, and the shared batch workflow lives in `SharedBatch`. Use the `KLTImageIOS` scheme with a local iPhone/iPad Simulator for mobile development. Physical-device verification belongs to the user/testers through TestFlight.

## Current status

Version 1.4.0 build 10 is published on GitHub Releases. A fresh download matches the approved artifact byte-for-byte and passes signature, notarization, stapling, checksum, quarantine and Gatekeeper checks. Batch calculation/replay, output accounting, decoder parity and long-run memory checks passed with the scope documented in the release notes. The independent 100-image, 24-megapixel run reconciled all 200 image/JSON files and finished with no temporary files or cleanup debt.

Native Mac UI, keyboard, VoiceOver and lifecycle coverage remain environment-blocked. Native Cancel acknowledgment within one second is inconclusive; real cloud-provider behavior, every external crash/cleanup window, physical-device behavior and TestFlight installation remain unverified. Earlier maximum-zoom registration, gesture ownership and matched screen/export detail gaps are not superseded by the batch checks. Publication was explicitly approved with these limits. Scientific calculations and analysis JSON are unchanged. Trusted version 1.3.2 build 8 remains the configured rollback release, and 1.3.3 build 9 remains available.

## License

KLT Image is licensed under the [GNU Affero General Public License v3.0](LICENSE). The bundled IBM Plex fonts are distributed under the SIL Open Font License; their license files are included beside the font resources.
