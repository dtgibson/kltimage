## Analysis controls

### What this does

KLT Image now lets an analyst choose RGB or CIE Lab D65 variables, covariance or correlation analysis, and whole-image or selected-region statistics. All eight combinations enhance the complete source image at full resolution while keeping RGB covariance with whole-image sampling as the pixel-identical default.

A single rectangular sample can be drawn, moved, or resized directly over the image, or entered as exact top-left source-pixel X, Y, width, and height values. The same source-coordinate region remains aligned through fit, zoom, pan, and Split view. Invalid drafts remain available for correction, stop recalculation, disable export, and never fall back to whole-image statistics or an older committed region.

Method changes automatically supersede older work, and only the newest result matching the visible method and sample can be exported. The unchanged source and any prior enhancement remain available for comparison while a request is processing or needs correction, with clear not-current status.

The full-frame pipeline now validates a documented 64-megapixel ceiling from image metadata before requesting full-resolution decoding, then rechecks the decoder output before allocating its RGBA buffer. Oversized images fail with a specific import message instead of entering an unbounded memory-pressure path.

### How to test

1. Open `KLTImage.xcodeproj` in Xcode 26 or later, select the `KLTImage` scheme and `My Mac`, then press Command-R.
2. Open an oriented JPEG, PNG, TIFF, or HEIC image. Confirm RGB, Covariance, and Whole image are selected by default and an enhanced result appears.
3. Switch independently between RGB and Lab, and between Covariance and Correlation. Confirm each change recalculates from the unchanged source and the active method updates in the metadata strip.
4. Choose Selected region. Confirm export becomes unavailable and the app asks for a sample instead of using whole-image statistics.
5. Drag on the source pane to create a rectangle. Move it from its interior and resize it from a corner; in Split view, confirm both panes show the same source-pixel bounds.
6. Enter exact X, Y, Width, and Height values and click Apply bounds. Enter an invalid or smaller-than-four-pixel region and confirm the attempted values remain editable, the problem is explained, and export stays unavailable. Correct the values and apply again.
7. Switch back to Whole image, then return to Selected region. Confirm the valid region is retained and reused. Clear it and confirm the app returns to the awaiting-region state.
8. Open the method details and confirm it explains the active variables, matrix basis, statistical sample, full-image application, stable components, and exploratory limits.
9. Export a current result as PNG, TIFF, or JPEG. Confirm its dimensions match the source and no region outline is included; PNG and TIFF should retain transparency.
10. Open a second image. Confirm its sample resets to Whole image and navigation resets, while the current RGB/Lab and Covariance/Correlation choices remain selected.
11. Open an image whose declared dimensions exceed 64 megapixels and confirm it is rejected with the documented limit before processing begins.
12. Press Command-U to run the numerical, image-pipeline, and interface automation checks.

### Notes for reviewer

- Lab processing converts sRGB values through CIE 1976 L*a*b* with a D65 reference white, transforms all source pixels, converts back to sRGB, and clips finite out-of-gamut channels while preserving alpha.
- Correlation normalizes numerically stable variables to unit variance. Flat or nearly flat variables are excluded from normalization and reported as limited variation rather than silently switching methods.
- A selected region supplies statistics only. Its half-open integer source-pixel bounds do not crop, mask, or localize the full-image enhancement.
- Region sampling supports one axis-aligned rectangle with at least four source pixels. Multiple regions, freehand selection, saved presets, and exported transform data remain out of scope.
- The shipped RGB covariance whole-image path remains byte-identical, including transparent and degenerate inputs.
- The Release performance suite exercises all eight analysis combinations on a 24-megapixel fixture and enforces the five-second target on Apple silicon.
- Full-frame processing is intentionally capped at 64 megapixels. Larger-image support belongs in a future tiled or out-of-core path rather than a hardware-dependent allocation attempt.
- IBM Plex Sans and IBM Plex Mono remain bundled under the SIL Open Font License.

## Convention Flags

- Keep scientific transforms in the independently testable `KLTCore` framework and keep file-panel and presentation state in the main-actor workspace model.
- Normalize imported images to oriented 8-bit sRGB premultiplied RGBA before analysis, and preserve the original decoded buffer unchanged.
- Keep analysis keys and request identity explicit so canceled or superseded work can never become current or exportable.
- Keep all image processing local, cancellable, deterministic, and off the main thread.
