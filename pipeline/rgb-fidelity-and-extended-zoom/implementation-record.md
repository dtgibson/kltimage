# RGB fidelity and extended zoom — implementation record

## Outcome

Both platforms now share a 10× (1000%) fit-relative maximum for existing zoom buttons and pinch. Mac retains its 0.25× minimum; iOS retains its 1× minimum, anchor-aware pinch, pan limits, and Fit behavior. No processing, decoder, interpolation, recipe, or protocol changes were justified by this investigation.

The user's supplied `IMG_0063.JPG` **reproduces pronounced RGB blocks in full-resolution lossless PNG output**, before native preview rendering. The 500×666, 49,010-byte source is 8-bit baseline JPEG with 4:2:0 chroma subsampling. Its chroma discontinuities strongly align to 16-pixel JPEG block boundaries; RGB covariance and correlation amplify them much more visibly than Lab. All four outputs match independent scalar application of the recorded transform exactly and PNG export preserves those pixels. This localizes the supplied sample's artifact to transformed source compression structure, not missing output pixels or a preview-only downsample. No smoothing or algorithm change was made. See `sample-investigation.md` for evidence and limits.

## Changes

- `KLTCore/AnalysisTypes.swift`: `ImageZoom.maximum = 10` and shared clamp.
- `KLTImage/WorkspaceModel.swift`, `KLTImage/ComparisonCanvas.swift`, `KLTImageIOS/IOSWorkspace.swift`, `KLTImageIOS/RegisteredCanvas.swift`: existing button/pinch paths use the shared clamp. Gesture ownership, fit-relative semantics, interpolation and scientific calculation are unchanged.
- Existing core tests extended for 10× sample-coordinate round trips, pinch ceiling/overshoot/zoom-out/floors, every EXIF rotation/reflection with exact pixel positions, independent scalar mapping and alpha checks, fine-detail lossless/compressed decode/process/export comparisons.
- Existing app test suites extended for repeated button presses, ceiling, zoom-out, floor and Fit; iOS viewport coverage now exercises 10× anchored zoom, edge pan clamping and stationary anchors at overshoot.
- `make-fidelity-fixtures.swift` generates deterministic 2053×1537 source PNG/JPEG and eight exported RGB/Lab covariance/correlation references for native visual checks. Outputs currently live at `/tmp/klt-rgb-fidelity-fixtures`.

## Fidelity evidence

The automated fixture is an odd-sized 257×193 image with nondegenerate subtle color variation at every pixel. Tests run TIFF, PNG and JPEG inputs through RGB/Lab covariance/correlation. Lossless sources and PNG/TIFF result exports preserve every opaque pixel exactly; all outputs retain dimensions. JPEG result exports use a mean RGB component error bound of 60/255, explicitly acknowledging the codec's loss. The stronger spatial check compares every pre-export result pixel with a scalar application of the recorded center/matrix/output mapping, allowing at most one byte of rounding difference. The JPEG cases had maximum scalar error **0** on Mac and iPhone Simulator.

The scalar reference does not call `StretchPlan`, render, or replay functions. Lab color conversion uses the public conversion routines, which have separate published color-reference tests; this is independent matrix/range application, not a wholly independent Lab implementation or a new validation of fitted statistics. Existing golden output and numerical tests continue to validate those contracts. Existing all-eight mode/sample combinations now also compare alpha-bearing output to the scalar reference; deterministic bytes, source immutability, frozen replay, canonical analysis protocol and image boundaries passed the complete Mac core suite.

JPEG control (ImageIO JPEG quality 0.94) mean absolute RGB component error (0–255 units), compared with the same lossless source/method:

| Method | Source error | Result error |
| --- | ---: | ---: |
| RGB covariance | 7.230 | 41.374 |
| RGB correlation | 7.230 | 39.625 |
| Lab covariance | 7.230 | 19.656 |
| Lab correlation | 7.230 | 13.315 |

No shrinking, block replication, RGB-specific spatial loss, or faulty export appeared in these controls. This controlled comparison does not establish native screen fidelity or provider behavior on a physical device. The later supplied-image reproduction is documented separately below and in `sample-investigation.md`.

## Verification

All xcodebuild commands used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, project `KLTImage.xcodeproj`, signed test bundles (no `CODE_SIGNING_ALLOWED=NO`) and explicit local Mac/simulator destinations. Logs are preserved in `evidence/`; full xcresults remain at the paths below.

| Run | Configuration and selection | Result | xcresult |
| --- | --- | --- | --- |
| Mac | `KLTImage`, Debug, `platform=macOS`, `-only-testing:KLTCoreTests -only-testing:KLTImageTests` | 64 core +31 app passed | `/tmp/klt-rgb-zoom-debug/Logs/Test/Test-KLTImage-2026.10.02_09-26-08--0700.xcresult` |
| Mac optimized | `KLTImage`, ReleaseTests, same selection | 66 core +31 app passed | `/tmp/klt-rgb-zoom-release/Logs/Test/Test-KLTImage-2026.10.02_09-24-34--0700.xcresult` |
| Mac optimized orientation follow-up | ReleaseTests, `-only-testing:KLTCoreTests/ImagePipelineTests/testDecodeRespectsOrientationAndConvertsToSRGB` | 1 passed after expanding all eight orientations | `/tmp/klt-rgb-zoom-release/Logs/Test/Test-KLTImage-2026.10.02_09-28-52--0700.xcresult` |
| iPhone 17 Pro, iOS 26.4 | `KLTImageIOS`, Debug, destination id `068373BA-E6B6-4640-B923-26B8BDB472DB`; `-only-testing:KLTCoreIOSTests/AnalysisControlsTests -only-testing:KLTCoreIOSTests/ImagePipelineTests/testDecodeRespectsOrientationAndConvertsToSRGB -only-testing:KLTImageIOSTests` | 17 core +10 app passed | `/tmp/klt-rgb-zoom-ios/Logs/Test/Test-KLTImageIOS-2026.10.02_09-26-09--0700.xcresult` |
| iPad Pro 13-inch (M5), iOS 26.4 | `KLTImageIOS`, Debug, destination id `7816C5F3-F485-40BB-A6C6-C86BE97B3287`; `-only-testing:KLTImageIOSTests` | 10 app passed | `/tmp/klt-rgb-zoom-ios/Logs/Test/Test-KLTImageIOS-2026.10.02_09-27-26--0700.xcresult` |

24 MP optimized benchmark passed: complete RGB/Lab matrix maximum **2.676 s**, median **1.833 s** including source fingerprint and record overhead; affine calculation **2.714 s**, frozen replay **1.014 s**. No shipping per-pixel validation overhead was added. The optimized full suite preceded only the orientation-test expansion; the targeted follow-up passed, and shipping code did not change afterward.

`git diff --check` passed. Design lint returned no findings for `reference-review.html`. Its directory scanner excludes Swift files and reports a misleading missing-path error for a Swift-only directory; native UI changes were self-reviewed as clamp substitutions with no visual or motion changes.

## Visual review and remaining QA

Verified tailnet-only HTTPS reference page: https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-rgb-review/

This page displays exported controlled images, **not native app screenshots**. HTTP 200 and SHA-256 equality of both served HTML and an RGB reference image were verified. Existing tailnet routes were preserved. Local origin is `127.0.0.1:8787`, served from `/tmp/klt-rgb-fidelity-fixtures` by the current Python server; it must remain running for this preview. Source page is `reference-review.html`.

The later focused signed iPhone UI run passed actual repeated button/pinch operations through 1000%, overshoot, zoom-out to 800% and Fit to 100% (`native-qa-followup.md`). QA should consume that evidence and the passing suites above, then focus on remaining native proof: iPad/Mac actual gestures, pan, sample selection and slider ownership; Original/Processed/Side-by-Side/Slider registration; matched-position screen-versus-export crops on Mac, iPhone and iPad. Automated model tests do not establish UIKit/SwiftUI gesture delivery or rasterization. The user subsequently supplied an affected image; it was analyzed privately, with results documented in `sample-investigation.md` and a separately verified, user-authorized tailnet comparison at `/kltimage-rgb-review/sample.html`. No physical device was accessed; no release, TestFlight upload, push, or production publication occurred.

## Recreate review fixtures

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc pipeline/rgb-fidelity-and-extended-zoom/make-fidelity-fixtures.swift -F /tmp/klt-rgb-zoom-release/Build/Products/ReleaseTests -framework KLTCore -Xlinker -rpath -Xlinker /tmp/klt-rgb-zoom-release/Build/Products/ReleaseTests -o /tmp/klt-make-fidelity-fixtures
/tmp/klt-make-fidelity-fixtures /tmp/klt-rgb-fidelity-fixtures
```
