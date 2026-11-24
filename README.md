# KLT Image

KLT Image makes subtle color differences easier to see. It uses a Karhunen–Loève transform (KLT) to stretch differences between colors that look nearly alike. This technique is called a *decorrelation stretch*.

In a photograph of cave art, for example, faded pigment can be close in color to the surrounding rock. A stretch can help you follow the marks. You can also try it on a color astrophotograph where neighboring parts of a nebula have little color contrast. The enhanced colors show variation captured by the camera. Identifying a pigment or interpreting an astronomical feature requires other evidence.

Open a photo, compare the enhanced image with the original using the slider, and export a separate copy. All processing runs locally on your Mac, iPhone, or iPad.

## Download

- [Download for Mac](https://github.com/dtgibson/kltimage/releases/download/v1.4.1/KLT-Image-1.4.1-build-11.zip). Version 1.4.1 build 11 supports Apple silicon and Intel Macs running macOS 14 or later.
- [Download for iPhone or iPad](https://apps.apple.com/app/id6818412230). Requires iOS or iPadOS 18 or later.

Mac download SHA-256: `8ff62c0f91a60836878db5a3d35c71f55ab493ca92349913cb0b4c52a31fe90a`

## What it does

- Open JPEG, PNG, TIFF, or HEIC images. Compare the original and result side by side or with the slider, with synchronized zoom and pan.
- Calculate a stretch from the whole image or from a rectangular sample. Both methods enhance the full image.
- Use RGB, CIE Lab, or a custom working space. Save a transform to apply the same calculation to another photograph.
- Export full-resolution PNG, TIFF, or JPEG images and an optional JSON record of the method. PNG and TIFF preserve transparency.
- Process up to 100 images in a batch, using a separate calculation for each image or replaying one saved transform across the set.

## Using the app

Open a photograph and processing begins with RGB, Covariance, and Whole image selected. Choose another working space or matrix mode to recalculate from the unchanged source, or choose Selected region and draw a rectangle over the source pane or enter exact source-pixel bounds. Open Methods to inspect the built-in spaces, create a user-defined space, or save and replay an accepted transform. Switch among Original, Side-by-Side, Slider, and Processed to compare the result. Analysis Record shows whether the result was calculated or replayed and exposes its exact source fingerprint, settings, matrices, transform, and output mapping. Export JSON saves the deterministic analysis sidecar; Export Result writes the current full-resolution enhancement without changing the source file.

Open **Batch** to select up to 100 images, choose **Calculate each image** or **Replay saved transform**, and review the format, optional analysis JSON and destination before starting. Each run creates a new folder and preserves earlier output. PNG is the default. Keep the app open in the foreground on iPhone and iPad; interruption stops the run without automatic resume. Matching calculation settings do not establish quantitative color comparability across independently fitted images.

Higher-resolution and lossless sources usually produce cleaner results. The transform can amplify compression blocks, sensor noise, and other small variations along with the color structure you want to study.

## Method

KLT Image calculates a mean and covariance from either every pixel or one rectangular sample in RGB, CIE Lab D65, or a validated reversible affine working space. Covariance preserves the original variable scale, while correlation normalizes numerically stable variables to unit variance. It diagonalizes the resulting symmetric matrix with a deterministic orthonormal eigendecomposition, applies bounded component gains to the full image, and returns the result to displayable sRGB while preserving alpha. A saved transform freezes the accepted working-space revision, center, transform, and output mapping, so replay applies those values unchanged without accumulating target statistics or solving a new transform.

The unchanged decoded source buffer is kept separately from the result. Processing is cancellable and runs away from the main user-interface thread.

Karhunen–Loève transform, principal component analysis, Hotelling transform, and decorrelation stretch refer to closely related ideas in this context. Michael Jon Harman's [DStretch algorithm description](https://www.dstretch.com/AlgorithmDescription.html) provides helpful background and references.

## Scientific limits

KLT Image is designed for visual exploration. When interpreting a result, keep these limits in mind.

- Uses 8-bit sRGB as its decoded source representation; RGB and Lab are alternative exploratory working spaces, not ranks of accuracy
- Lets a rectangle control the statistics, but still applies the resulting transform to the complete image
- Clips finite out-of-gamut values when transformed Lab colors return to displayable sRGB
- Can magnify compression artifacts, noise, color-management effects, and lighting differences
- Treats fully transparent decoded pixels as having no recoverable RGB value while preserving their alpha
- Processes full frames up to 64 megapixels on Mac or 26 million oriented pixels on iPhone and iPad. The mobile encoded-file limit is 256 MiB. Mac batch imports and single-image imports in this source revision accept encoded files up to 1 GiB.

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

## Release information

The Mac download is signed with Developer ID and notarized by Apple. Release notes include verification results for that build. [Mac release notes](https://github.com/dtgibson/kltimage/releases/tag/v1.4.1)

For iPhone and iPad, download the source archive that matches your installed version. Each archive includes build instructions and the notice for the official App Store distribution. [iOS 1.1.2 build 8 source](https://github.com/dtgibson/kltimage/releases/tag/ios-1.1.2-build-8) · [iOS 1.1.1 build 7 source](https://github.com/dtgibson/kltimage/releases/tag/ios-1.1.1-build-7)

## License

KLT Image is licensed under the [GNU Affero General Public License v3.0](LICENSE). The bundled IBM Plex fonts are distributed under the SIL Open Font License. Their license files accompany the font resources.
