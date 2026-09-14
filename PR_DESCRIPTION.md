## Safer image replacement and reliable slider dragging

### What changed

- Dragging the comparison slider handle now changes only the reveal boundary. The registered image remains fixed, while dragging elsewhere on the canvas continues to pan normally.
- Opening a replacement image keeps the current source and result visible until the new decode succeeds. Cancelled, corrupt, overlapping, or stale replacement work cannot discard the current image or publish over a newer operation.
- The comparison canvas no longer force-unwraps the source across SwiftUI update boundaries.
- macOS UI verification now preserves an already-enabled Full Keyboard Access setting, selects its image through the native file panel without timing-dependent Return presses, and keeps optimized test state isolated from the real method library.

### How to test

1. Open an image, choose Slider, and drag the teal divider. The reveal changes without moving the image.
2. Drag the image away from the divider. Both registered views pan together.
3. Open a second image repeatedly, cancel the file panel, and try an invalid image. The current image remains visible and usable until a valid replacement succeeds.
4. Run the complete Debug and optimized ReleaseTests configurations, including all macOS UI workflows.

### Verification

- Debug: 96 passed, 0 failed.
- ReleaseTests: 98 passed, 0 failed, including the 24-megapixel optimized performance checks.
- Both focused fixes passed their regression suites and security reviews with no unresolved findings.
- The distributable remains a universal, sandboxed, hardened macOS app with no new network, persistence, or entitlement surface.

## Deployment

KLT Image 1.3.1 build 7 is the approved patch-release candidate. It will use the existing fail-closed Developer ID signing, Apple notarization, stapling, independent quarantine verification, GitHub Release, and tailnet-only Tailscale mirror flow. KLT Image 1.3.0 build 6 remains the trusted rollback release.

### Release notes

KLT Image 1.3.1 fixes two image-comparison workflows. Dragging the Slider divider no longer pans the underlying image, and replacing an open image no longer risks a crash or losing the current image when selection is cancelled, decoding fails, or newer work supersedes an earlier request.

The release also strengthens the signed macOS UI-test path used to verify these behaviors. No new account, upload, analytics, networking, or data-retention capability is added. KLT Image continues to require macOS 14 or later.
