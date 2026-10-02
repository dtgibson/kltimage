# Focused native iPhone QA follow-up

## Result

Signed focused XCTest run **passed**: one test, 35.242 seconds, on local iPhone 17 Pro Simulator (iOS 26.4 runtime), explicit simulator ID `068373BA-E6B6-4640-B923-26B8BDB472DB`. No shipping code, global Xcode selection, physical device or shared pipeline state was changed for this errand.

The temporary harness demonstrated actual Photos import of the controlled fixture, repeated Zoom in taps reaching 1,000%, zoom-out to 800%, Fit to 100%, repeated native two-touch pinch reaching 1,000%, overshoot staying clamped, and final Fit to 100%.

## Harness correction

The observed iOS 26 picker uses `ScrollView` identifier `photosView_content_scroll_view` and images with identifier `PXGGridLayout-Info`, not CollectionView/cells. The controlled fixture label was `Photo, October 02, 09:26`. XCTest's `.tap()` failed its automatic scroll-to-visible path despite the valid visible frame; using that observed element's frame-center coordinate successfully imported it. A subsequent assertion was corrected for the actual localized label `Zoom 1,000 percent` (comma). These were harness errors, not product failures.

## Evidence

- Harness and detailed notes: `/tmp/klt-native-ui-qa/Tests/NativeZoomQA.swift`, `/tmp/klt-native-ui-qa/harness-repair-notes.md`.
- Passing result: `/tmp/klt-native-ui-qa/native-final.xcresult`.
- Log: `/tmp/klt-native-ui-qa/native-final.log`.
- Six screenshot attachments and manifest: `/tmp/klt-native-ui-qa/native-final-attachments/`.
- Button ceiling capture: `04122C39-8AF9-43B2-9BCB-536F25DD86D8.png`.
- Pinch/overshoot capture: `8E082650-F90D-4D7B-AA0A-0E8411B81FAF.png`.
- Fit-restored capture: `D73C4C9C-8D17-492C-B6B7-DBAF08B3F07E.png`.

Run command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project /tmp/klt-native-ui-qa/KLTImage.xcodeproj -scheme NativeZoomQA -configuration Debug -destination 'platform=iOS Simulator,id=068373BA-E6B6-4640-B923-26B8BDB472DB' -derivedDataPath /tmp/klt-native-ui-qa/build -resultBundlePath /tmp/klt-native-ui-qa/native-final.xcresult -only-testing:NativeZoomQA/NativeZoomQA/testNativeButtonsPinchAndFit
```

## Limits

The harness attempted Processed/Original button taps but did not assert selection changed. Inspection of its Processed-named screenshot still showed Side by side; filenames alone do not establish mode-switch proof. Do not count those captures as separate comparison modes or screen-to-export equality. Mac/iPad actual pinch, maximum-zoom pan/sample/slider interaction and matched crop proof remain outside this narrow successful errand. Existing geometry and interaction-state unit tests remain the automated evidence for those invariants.
