## Seeing KLT Image locally

Download the current package from [GitHub Releases](https://github.com/dtgibson/kltimage/releases/latest), unzip it, and double-click **KLT Image**. The universal app runs on Apple silicon and Intel Macs without Xcode.

The downloadable app is ad-hoc signed and sandboxed, but it is not Developer ID-signed or notarized. macOS may ask you to confirm that you want to open it.

To run from source instead, open `KLTImage.xcodeproj` in Xcode 26 or later, select the `KLTImage` scheme and `My Mac`, and press Command-R.

1. Click **Open Image** and choose a JPEG, PNG, TIFF, or HEIC photograph. Processing starts automatically and stays on your Mac.

2. When the result is ready, use **Original**, **Split**, and **Enhanced** to compare it. Drag anywhere on the image to pan, pinch to zoom, use the zoom buttons, or double-click to fit the image again.

3. Click the information button beside **Whole-image covariance** to read the method details and component-stability result.

4. Click **Export Result**, choose PNG, TIFF, or JPEG in the Mac save panel, and save the full-resolution enhanced image. PNG and TIFF preserve transparency; JPEG places transparent areas on white.

5. Press Command-U in Xcode to run the numerical and image-format checks.

What to look for: both panes should stay aligned while navigating, the original must remain unchanged, the exported dimensions must match the source, and the interpretation note should remain visible throughout comparison.
