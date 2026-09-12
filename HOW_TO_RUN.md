## Using KLT Image locally

If you have access to the project's tailnet, download the private [KLT Image 1.1.0 build 3 package](https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-preview/releases/KLT-Image-1.1.0-build-3.zip), unzip it, and double-click **KLT Image**. The universal app runs on Apple silicon and Intel Macs without Xcode.

The package is approved for private/local use only. It is ad-hoc signed and sandboxed, but it is not Developer ID-signed or notarized. macOS may ask you to confirm that you want to open it.

To run from source, open `KLTImage.xcodeproj` in Xcode 26 or later, select the `KLTImage` scheme and `My Mac`, and press Command-R.

1. Click **Open Image** and choose a JPEG, PNG, TIFF, or HEIC photograph up to 64 megapixels. Processing starts with RGB, Covariance, and Whole image selected, and stays on your Mac. Larger images are rejected before full-resolution decoding with a readable size-limit message.

2. Use **Color space** to compare RGB with CIE Lab D65, and **Matrix mode** to compare covariance with correlation. Each committed choice recalculates the full-resolution result from the unchanged source.

3. Under **Statistical sample**, keep **Whole image** or choose **Selected region**. Draw a rectangle over the source pane, then drag inside it to move it or drag a corner to resize it. You can also enter exact top-left source-pixel X, Y, Width, and Height values and click **Apply bounds**.

4. In region mode, the rectangle supplies the statistics used to derive the transform; the complete image is still enhanced. Invalid bounds remain editable for correction, do not fall back to another sample, and keep export unavailable until a matching result is ready.

5. Use **Original**, **Split**, and **Enhanced** to compare results. Drag the image background to pan, pinch to zoom, use the zoom buttons, or double-click to fit. Split panes share navigation and display the same active region.

6. Click the information button beside the active method to review its variables, matrix basis, statistical sample, stable-component count, and exploratory-use cautions.

7. Click **Export Result**, choose PNG, TIFF, or JPEG in the Mac save panel, and save the current full-resolution enhancement. The selection outline is not exported. PNG and TIFF preserve transparency; JPEG places transparent areas on white.

8. Press Command-U in Xcode to run the numerical, image-format, analysis-control, and interface automation checks.

What to look for: method and sample labels should always describe the displayed result; invalid or superseded requests must keep export disabled; both Split panes should stay aligned; the original must remain unchanged; and exported dimensions must match the source.
