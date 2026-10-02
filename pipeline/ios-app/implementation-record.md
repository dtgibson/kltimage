# KLT Image for iPhone and iPad — implementation record

## Built

- Added an iOS 18+ app, an iOS build of the shared `KLTCore` framework, iOS core and app test targets, and a shared Xcode scheme. `project.yml` remains the project source; the generated Xcode project was updated with it.
- Added full-resolution JPEG, PNG, TIFF, and HEIC import from Files and Photos. ImageIO rejects sources above 26,000,000 oriented pixels before full decode. The Mac default remains 64,000,000 pixels. Replacement decoding keeps the accepted workspace until the latest valid source commits.
- Both iOS pickers now stream the selected encoded representation into one app-owned staging file, count actual bytes, and reject files above 256 MiB before ImageIO sees them. The stage rejects a provider file that changes during the copy, removes partial files on error or cancellation, and removes completed files after decode. App launch sweeps UUID-named staging files left by an interrupted prior run, including the former `klt-photo-*` format.
- Added an adaptive SwiftUI workspace. The iPhone has a compact workspace and method-library destination; a wide iPad keeps analysis context beside the canvas. Comparison modes share a registered source-pixel viewport. Pinch, pan, Fit, accessible zoom controls, Slider reveal, touch sample creation/movement/four-corner resize, and exact pixel entry are separate interactions.
- Reused the existing RGB, Lab, curated/user working-space, covariance/correlation, frozen-replay, analysis-record, method-document, and image-export contracts. The iOS library persists only method documents locally; result/image exports go through explicit system destinations.
- Added cancellation and source/request/job identity checks for asynchronous work. Source and result remain separate; stale calculation or export bytes cannot become the current result.
- Bundled the project typography and design tokens in the native app. Added empty, working, error, provenance, and export states.

## Verification completed on 1 October 2026

- iPhone 17 Pro Simulator, iOS 26.4, signed Debug XCTest run: 62 iOS core tests and 4 iOS app tests passed before the final sample-handle drawing edit. A second signed Debug run after that edit rebuilt the app and passed all 4 iOS app tests, including registered viewport coordinates and workspace/result identity.
- macOS Debug: 62 core tests and 30 app tests passed. The UI test runner failed before executing UI tests because Xcode timed out enabling automation mode.
- macOS ReleaseTests: 64 core tests passed. The app test host stalled before it ran tests; the run was stopped. There is no ReleaseTests app-suite pass from this session.
- The iOS Simulator app built successfully; native empty-workspace captures from iPhone and wide iPad are in `review/`. The private HTTPS review page returned HTTP 200 and serves those captures plus the approved interactive design study: https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-preview/app/
- `git diff --check` passed. The design lint utility did not accept the Swift source directory, so native visual review used Simulator captures against the approved design.

## Verification still required before release

- The Tester should run native interaction checks for Files/Photos imports, sample gesture ownership, VoiceOver, Dynamic Type, record and image exports, and iPad window resizing. The browser review page is a design and capture review, not an executable iOS build.
- The fixed 26-million-pixel limit requires memory and full-workflow checks on the lowest-memory supported iPhone and iPad, plus current devices. If it fails there, lower the fixed cap and document the new limit before release.
- The 256 MiB encoded-file ceiling covers roughly 198 MiB of 16-bit RGBA data at 26 million pixels with room for ordinary TIFF metadata. It bounds disk staging but does not prove decode memory safety; test maximum-size JPEG, PNG, TIFF, and HEIC provider representations on the lowest-memory supported physical iPhone and iPad before release. Exceptionally large encoded files within 26 MP are rejected with a clear limit message.
- The Mac ReleaseTests app-host stall and macOS UI automation startup error need fresh host-level verification. A signed TestFlight archive, provisioning, App Store Connect upload, and device installation belong to the later release stage; no iOS build has been distributed.

## Convention flags

- Keep the iOS app layer responsible for Photos, Files, touch gestures, and system export; keep scientific calculations and versioned document codecs shared in `KLTCore`.
- Apply the iOS oriented-pixel limit before ImageIO allocates the full decoded image, while preserving the Mac's separate 64-million-pixel default.
- Count encoded bytes while staging every iOS provider image, and remove only app-owned UUID-named staging files during launch recovery.

## Security correction verification — 1 October 2026

- A signed iPad Pro Simulator Debug run passed 9 of 9 focused app tests. New tests cover a static over-limit file, a provider that grows during streaming, injected mid-copy failure, cancellation after a partial write, selective launch recovery, a validated Photos-style staged import with cleanup, and preservation of the accepted workspace after an oversized Files source is rejected.
- The new staging file is included through `project.yml`; XcodeGen regenerated the project. A separate iOS Debug app build succeeded after the correction.
