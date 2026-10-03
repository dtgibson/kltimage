# Final independent QA delta commands and provenance

All commands used per-process DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer. No global settings, physical devices, release actions or state changes.

## Memory

`python3 pipeline/batch-processing/qa-evidence/retry-2/run-independent-memory.py > pipeline/batch-processing/qa-evidence/retry-2/independent-memory.log 2>&1`

The checked-in evidence script records the exact signed hosted XCTest environment and filter. Binary/framework/source hashes in independent-provenance.json; source matched implementation-evidence/retry-2/final-source-sha256.json. Result1pass/0fail211.465s. Known testPID17133 finished naturally. One read-only `vmmap -summary 17133` sampled near long-runitem63, saved as independent-memory-vmmap.txt.

## Current Debug affected regression

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KLTImage.xcodeproj -scheme KLTImage -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/klt-batch-qa-mac build-for-testing`

Build succeeded. Direct signed XCTest environment is unchanged from ../commands.md. Core filter: `-XCTest KLTCoreTests.IOSDecodePolicyTests,KLTCoreTests.AnalysisControlsTests,KLTCoreTests.AnalysisRecordTests,KLTCoreTests.MethodFeatureTests` (46pass). Hosted app filter: `-XCTest KLTImageTests.BatchProcessingTests` (12pass). Logs mac-debug-core-affected.log and mac-debug-batch.log. Direct execution does not cover UI XCTest.

## Native

Used existing ../simulator-ui.py AXe wrapper and only explicit local iPadUUID7816C5F3-F485-40BB-A6C6-C86BE97B3287. Added known small repository hummingbird fixture through simctl addmedia;24MPderived fixture already existed. Native Photos imported24MPworkspace, Library saved current transform, Batch selected smallthen24MPPhotos, nativeFiles selected OnMyiPad. No library-wide permission prompt. User/system originals not modified.

Native Home then simctl launch foreground produced interrupted1saved/1canceled. Captures distinguish transient system snapshots from final app state. Replay used native saved-transform menu and JSON toggle, finished2success with one explicit warning. Cancel was exercised while24MPreplay active; exact clock records and captures are saved. Instrumented bounds1.343–1.406seconds include process/query/tap overhead; nativeone-second threshold unverified.

Active termination: before-termination.txt shows Processing2of2 and1successful. `xcrun simctl terminate UUID com.kltimage.ios`, then `xcrun simctl launch UUID com.kltimage.ios`; newPID22594. Fresh Batch showed0/100/defaults/noqueue. The process termination sample had no private debris beforekill; no claim of native crash-debris deletion. Output audit reads only the known selected local-provider run folders, and private housekeeping inside this simulator app container. No other device enumerated or accessed.

All six output folders remain for review; image dimensions read from PNGIHDR, records parsed with JSON, all filesSHA256hashed. Replay frozen fields compared excluding targetOutcome; equal, both calculation:null, version2. Private receipt entries[] afterlaunch. Screenshot review is under existing private /qa-retry-2/ scope; root routes/index unchanged.
