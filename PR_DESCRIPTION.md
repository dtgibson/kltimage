## Core RGB enhancement workflow

### What this does

KLT Image is now a native macOS app that opens JPEG, PNG, TIFF, and HEIC images, converts them to an oriented 8-bit sRGB working image, and applies a deterministic covariance-based RGB decorrelation stretch. It keeps the unchanged original beside the enhanced result, synchronizes zoom and pan, explains the method and its exploratory limits, and exports full-resolution PNG, TIFF, or JPEG files.

The numerical core uses Welford covariance, a deterministic symmetric 3 × 3 eigendecomposition, bounded component gains, uniform output-range fitting, and explicit handling for uniform or nearly uniform images. Processing and export run away from the main thread and can be canceled.

### How to test

1. Open `KLTImage.xcodeproj` in Xcode 26 or later.
2. Select the `KLTImage` scheme and the `My Mac` destination.
3. Press Command-R.
4. Open an oriented JPEG, PNG, TIFF, or HEIC image and confirm the original and enhanced panes appear.
5. Switch among Original, Split, and Enhanced, then zoom and drag the image. Both split panes should stay aligned.
6. Open the method details and confirm it reports whole-image RGB covariance in sRGB.
7. Export PNG, TIFF, and JPEG copies. Confirm their pixel dimensions match the source; PNG and TIFF should retain transparency.
8. Open a uniform-color image and confirm it remains viewable with the limited-variation explanation.
9. Run the `KLTImage` scheme's tests with Command-U.

### Notes for reviewer

- This feature intentionally implements RGB covariance with whole-image sampling only. Lab, correlation mode, and selectable-region statistics remain in the next roadmap item.
- JPEG has no alpha channel, so transparent areas are composited over white for JPEG export. PNG and TIFF preserve alpha.
- Fully transparent pixels have no recoverable RGB value after standard premultiplied decoding and therefore enter the analysis as zero RGB; their alpha is still preserved exactly.
- Decorrelation stretch can reveal source compression or low-resolution artifacts along with subtle color differences; lossless or higher-resolution sources provide a cleaner result.
- Build 1.0.0 (2) keeps the native comparison control in the app's fixed light appearance and adds an explicit high-contrast boundary so every unselected mode remains visible under macOS dark mode.
- IBM Plex Sans and IBM Plex Mono are bundled under the SIL Open Font License.
- The Release performance regression test processes a 24-megapixel fixture and enforces the five-second target on Apple Silicon.

## Convention Flags

- Keep scientific transforms in the independently testable `KLTCore` framework and keep file-panel and presentation state in the main-actor workspace model.
- Normalize imported images to oriented 8-bit sRGB premultiplied RGBA before analysis, and preserve the original decoded buffer unchanged.
- Keep all image processing local, cancellable, and off the main thread.
