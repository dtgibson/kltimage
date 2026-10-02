## KLT Image for iPhone and iPad

### What this does

Adds a native iOS/iPadOS 18+ KLT Image app beside the Mac app. It brings full-resolution local image import, the shared scientific methods and method library, registered touch comparison and sampling, analysis provenance, and explicit image and JSON exports to iPhone and iPad.

### How to test

1. Run the `KLTImageIOS` scheme on an iPhone and iPad Simulator. Open a JPEG, PNG, TIFF, or HEIC from Files or Photos and confirm the oriented original dimensions and unchanged source.
2. Compare Original, Side by side, Slider, and Processed. Pinch, pan, Fit, and zoom; draw, move, and resize a sample, then enter its exact pixel bounds. Confirm the sample remains registered across views and exports contain no overlays.
3. Change working space, matrix, and sample source; inspect the calculated record. Save and replay a transform, inspect target versus origin, and explicitly export PNG, TIFF, JPEG, and JSON.
4. In Methods, create/edit/duplicate/rename/delete a user working space and import/export both method document types. Check invalid imports and library recovery without losing current work.
5. Run signed Debug iOS XCTest with `xcodebuild test -project KLTImage.xcodeproj -scheme KLTImageIOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4'`. Run the Mac `KLTImage` Debug and ReleaseTests suites separately.

### Notes for reviewer

- `project.yml` owns the generated Xcode project. `KLTCoreIOS` compiles the shared core for iOS; the Mac target retains its own framework and 64-million-pixel ceiling.
- iOS rejects a source above 26,000,000 oriented pixels before full decode and never substitutes a downsample. Verify maximum-size workflow memory on the lowest-memory supported devices before release.
- iOS Debug core/app tests passed (62 + 4); the final handle edit rebuilt and passed the 4 app tests. Mac Debug core/app tests passed (62 + 30). Mac UI automation could not start, and the Mac ReleaseTests app host stalled before its tests; 64 ReleaseTests core tests passed.
- The [private HTTPS review](https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-preview/app/) contains native empty-state captures and the approved interactive design study. It is not a live iOS app. TestFlight signing and physical-device verification are still pending.
