# Batch processing implementation

The native batch workflow is implemented on Mac, iPhone, and iPad. Independent whole-image calculation and unchanged saved-transform replay use the existing KLTCore functions and unchanged analysis-record codecs. Native acceptance and the full required regression/security checks remain with the independent Tester and Auditor.

## Application changes

- `SharedBatch/BatchTypes.swift`, `BatchModel.swift`, and `BatchRunner.swift`: one process-wide batch surface/execution lease, immutable run/method/input snapshots, sequential lazy acquisition, item/source/fingerprint/request/job acceptance, settled-row progress, cancellation/interruption drainage, accurate committed-artifact outcomes, and explicit fresh attempts.
- `SharedBatch/BatchStorage.swift`: regular-file/no-follow counted acquisition, before/after descriptor and path identity checks, byte/pixel resource policy, private temporary reservations, launch cleanup, minimal anonymous durable external cleanup receipts, explicit matching-run-folder cleanup, and transient security-scoped folder ownership.
- `SharedBatch/BatchPublisher.swift`: exclusively created fresh run folders, actual no-overwrite capability probe, bounded destination-local temporary files, coordinated descriptor-relative exclusive renames, paired collision suffixes, retained image-only partial saves, immediate commit receipts, verified temporary-file identities, conservative capacity checks, and owned cleanup.
- `KLTCore/ImagePipeline.swift`: additive bounded ImageIO consumer encoder. It shares orientation/format/JPEG preparation with the existing API, refuses excess bytes before retention/write, and preserves the original sink error. Scientific arithmetic and golden JSON files are unchanged.
- `SharedBatch/BatchView.swift`: adaptive native source/setup and outcome views, two explicit scientific modes, defaults, method origin disclosure, output/folder review, limits, temporary-debt recovery, accessible status text, and reduced-motion transitions. iPhone uses a full-screen presentation; iPad and Mac use sheets.
- `KLTImageIOS/BatchSources.swift`: native ordered Photos selection retains providers without acquisition; complete-file acquisition and staging happen only for the active entry and within the callback's URL lifetime. Files and folder pickers use open-in-place access. No library-wide Photos authorization, thumbnails, bookmarks, or output sharing fallback.
- `KLTImage/BatchMacLifecycle.swift`: active-window close drains the controller; application quit requests stop and delays termination while possible. iOS background stops with an interrupted outcome; foreground inactivity does not.
- Both workspace models guard processing/import/export and presentation/region changes under the shared lease. A lock-protected interactive task count outlives cancellation acknowledgment, preventing batch acquisition before old native work actually drains. The accepted interactive result remains in place.
- `project.yml` includes shared app sources and shared batch tests in both platform targets; `KLTImage.xcodeproj` was regenerated with XcodeGen.

## Verification performed

All commands used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; no global Xcode selection, accessibility setting, release signing state, or preview service was changed.

| Check | Actual result |
| --- | --- |
| Latest Mac Debug app build, arm64 destination | **BUILD SUCCEEDED**; `implementation-evidence/mac-final-build.log`. |
| Initial signed Mac Debug batch suite | **7/7 passed**. Saved XCTest summary: `implementation-evidence/mac-initial-batch-summary.json`; result bundle `/tmp/klt-batch-mac/Logs/Test/Test-KLTImage-2026.10.03_00-25-08--0700.xcresult`. This preceded the eighth test and later exclusion/coordination hardening. |
| Updated Mac Debug batch run and one retry | Both built but stalled before any test case started. Terminated their exact xcodebuild processes after the startup stall. **Current-head Mac test execution is unverified**, not a pass. Retry transcript: `implementation-evidence/mac-test-startup-retry.log`. |
| Latest signed iPhone 17 Pro Simulator, iOS 26.4.1, batch suite | **8/8 passed**, including final surface-lease, cancellation-coordinator, and guarded-setter changes. `implementation-evidence/iphone-final-batch-tests.log`. |
| Signed iPad Pro 13-inch (M5) Simulator, iOS 26.4.1, app suite | **18/18 passed**: eight batch tests and ten existing app regressions. `implementation-evidence/ipad-app-tests.log`. This preceded the final coordinator/surface lifecycle hardening; final shared changes were checked on iPhone. |
| `git diff --check` | Passed. |
| Design lint | Installed tool rejected the Swift directory (`no such file or directory: SharedBatch`); no native lint acceptance claimed. |
| Approved HTTPS design review | Returned HTTP 200 with normal certificate validation: https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-batch-review/ . Existing tailnet-only route preserved. It remains a design reference, not native acceptance. |

The shared tests exercise bounded encoder byte parity for PNG/TIFF/JPEG and cap/cancel errors; static/growing/changed/link source rejection; unchanged whole-image RGB/Lab/curated covariance/correlation results and region-origin frozen replay; identity acceptance; conflicts inserted between image and JSON commits; cancellation before image, after image, and after both commits; conservative cleanup debt across reinitialization and wrong-folder rejection; mixed valid/corrupt/valid continuation; and 100 sequential repeated inputs with one active acquisition, distinct outputs, no prior-item temporary files at the next acquisition, plus a delayed canceled acquisition that drains without starting the next entry.

The first iPhone run exposed recursive assignment inside an Observation-generated property observer while testing workspace exclusion. Replaced that approach with guarded computed setters over observed backing values for method, matrix, region, sample, comparison, reveal, zoom, and pan. The fixed iPhone batch tests and iPad existing workspace/export tests passed. Tester should specifically review these setter changes and workspace preservation.

## Exact verification commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KLTImage.xcodeproj -scheme KLTImage -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/klt-batch-mac build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KLTImage.xcodeproj -scheme KLTImage -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/klt-batch-mac test -parallel-testing-enabled NO -only-testing:KLTImageTests/BatchProcessingTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KLTImage.xcodeproj -scheme KLTImageIOS -configuration Debug -destination 'platform=iOS Simulator,id=068373BA-E6B6-4640-B923-26B8BDB472DB' -derivedDataPath /tmp/klt-batch-ios test -only-testing:KLTImageIOSTests/BatchProcessingTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KLTImage.xcodeproj -scheme KLTImageIOS -configuration Debug -destination 'platform=iOS Simulator,id=7816C5F3-F485-40BB-A6C6-C86BE97B3287' -derivedDataPath /tmp/klt-batch-ios test -only-testing:KLTImageIOSTests
```

Final iPhone result bundle: see the path near the end of its preserved transcript. DerivedData/result bundles are local development artifacts, not preview handoffs or distributable builds.

## Remaining independent acceptance

- Tester owns full Mac Debug/ReleaseTests suites, the Release 24 MP benchmark, full iOS core/golden regression, native Files/Photos flows, keyboard/VoiceOver/Dynamic Type, visible cancel timing, actual foreground/background/window/quit transitions, and full-resolution memory profiling. No claim that unit tests establish these UI/provider behaviors.
- Native screen automation through XcodeBuildMCP was attempted using only the explicit local simulator UUID. It could not resolve its accessibility backend because machine-wide `xcode-select` points at CommandLineTools. Shell builds/tests work with explicit `DEVELOPER_DIR`. No global preference was changed, and no native screenshot acceptance is claimed.
- Actual third-party/cloud-provider semantics, physical-device memory/lifecycle behavior, and TestFlight installation remain unverified. Unsupported exclusive publication fails closed at runtime. No physical device was enumerated, accessed, or used by this implementation work.
- No release artifact, public preview, TestFlight upload, GitHub publication, pipeline lifecycle transition, or handoff-state mutation was performed.

## Convention flags

- Batch outcome success is derived from commit receipts captured inside exclusive rename operations, not cancellation state or the absence of a thrown error.
- Keep transient execution state separate from minimal anonymous housekeeping debt; cleanup receipts confer no access and contain no workspace/output history.
- Observation-backed properties that must reject a mutation use guarded computed setters and separate observed values; assigning the property back inside its generated observer can recurse.

## QA retry 1 — 2026-10-03

Corrected mobile Batch hit geometry/text wrapping and destination presentation; closed four Mac region lease gaps and added focused state/fault coverage. Mac/iPhone/iPad batch suites each pass 12 tests. Both true shipping Release configurations compile without DEBUG or test-fault symbols. See [the scoped retry record](implementation-retry-1.md) for native evidence and remaining independent QA acceptance.

## QA retry 2 — 2026-10-03

Corrected full-frame buffer ownership while retaining the existing thumbnail decoder and every scientific pixel calculation. Optimized Mac core passes 67 tests; all 384 exact decode comparisons and the 24 MP benchmark pass. The final 3+100-image run passes with 374,032,040-byte short maximum, 378,129,408-byte first-ten maximum, and 258,428,192-byte final/last-ten maximum; all 43 Mac app tests pass. Large virtual framework mappings remain, but early/late vmmap shows only 512 KiB resident/dirty in the formerly multi-gigabyte dirty purgeable zone. Final iPhone core/batch (65+12), iPad decode/batch (3+12), canonical Mac batch (11), and both shipping Release checks pass. See [the scoped retry record](implementation-retry-2.md) for exact evidence, diagnostic configuration distinctions, rejected decoder changes, and remaining independent QA acceptance.
