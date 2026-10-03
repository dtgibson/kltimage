# Reproducible QA commands

Run from `/Users/developer/devwork/kltimage`. All Xcode selection is per process. The existing Mac app PID 10436 is unrelated and must be preserved.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KLTImage.xcodeproj -scheme KLTImageIOS -configuration Debug -destination 'platform=iOS Simulator,id=068373BA-E6B6-4640-B923-26B8BDB472DB' -derivedDataPath /tmp/klt-batch-qa-ios -resultBundlePath /tmp/klt-batch-qa-iphone.xcresult -parallel-testing-enabled NO test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KLTImage.xcodeproj -scheme KLTImageIOS -configuration Debug -destination 'platform=iOS Simulator,id=7816C5F3-F485-40BB-A6C6-C86BE97B3287' -derivedDataPath /tmp/klt-batch-qa-ios -resultBundlePath /tmp/klt-batch-qa-ipad.xcresult -parallel-testing-enabled NO test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KLTImage.xcodeproj -scheme KLTImage -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/klt-batch-qa-mac -resultBundlePath /tmp/klt-batch-qa-debug.xcresult -parallel-testing-enabled NO test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KLTImage.xcodeproj -scheme KLTImage -configuration ReleaseTests -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/klt-batch-qa-release -resultBundlePath /tmp/klt-batch-qa-release.xcresult -parallel-testing-enabled NO test
```

Result bundle paths above already exist; use fresh paths when repeating. The Mac full runs built the signed bundles then stalled on testmanagerd; only those exact xcodebuild processes were terminated. Direct core commands:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer DYLD_FRAMEWORK_PATH=/tmp/klt-batch-qa-mac/Build/Products/Debug /Applications/Xcode.app/Contents/Developer/usr/bin/xctest /tmp/klt-batch-qa-mac/Build/Products/Debug/KLTCoreTests.xctest
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer DYLD_FRAMEWORK_PATH=/tmp/klt-batch-qa-release/Build/Products/ReleaseTests /Applications/Xcode.app/Contents/Developer/usr/bin/xctest /tmp/klt-batch-qa-release/Build/Products/ReleaseTests/KLTCoreTests.xctest
```

Direct signed Mac app XCTest runs:

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer DYLD_FRAMEWORK_PATH=/tmp/klt-batch-qa-mac/Build/Products/Debug:/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks DYLD_LIBRARY_PATH=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib DYLD_INSERT_LIBRARIES=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/libXCTestBundleInject.dylib XCInjectBundle='/tmp/klt-batch-qa-mac/Build/Products/Debug/KLT Image.app/Contents/PlugIns/KLTImageTests.xctest' XCInjectBundleInto='/tmp/klt-batch-qa-mac/Build/Products/Debug/KLT Image.app/Contents/MacOS/KLT Image' '/tmp/klt-batch-qa-mac/Build/Products/Debug/KLT Image.app/Contents/MacOS/KLT Image'
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer DYLD_FRAMEWORK_PATH=/tmp/klt-batch-qa-release/Build/Products/ReleaseTests:/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks DYLD_LIBRARY_PATH=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib DYLD_INSERT_LIBRARIES=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/libXCTestBundleInject.dylib XCInjectBundle='/tmp/klt-batch-qa-release/Build/Products/ReleaseTests/KLT Image.app/Contents/PlugIns/KLTImageTests.xctest' XCInjectBundleInto='/tmp/klt-batch-qa-release/Build/Products/ReleaseTests/KLT Image.app/Contents/MacOS/KLT Image' '/tmp/klt-batch-qa-release/Build/Products/ReleaseTests/KLT Image.app/Contents/MacOS/KLT Image'
```

This launches separate test app processes; it does not stop the preexisting app. It does not execute the UI XCTest target.

`simulator-ui.py` wraps the bundled AXe CLI with the explicit Xcode and framework environment; use only the two named local simulator UUIDs. Example:

```sh
python3 pipeline/batch-processing/qa-evidence/simulator-ui.py describe-ui --udid 068373BA-E6B6-4640-B923-26B8BDB472DB
python3 pipeline/batch-processing/qa-evidence/simulator-ui.py tap --id batch-close --udid 068373BA-E6B6-4640-B923-26B8BDB472DB
```

AXe snapshots contain app elements underneath system remote-view pickers, so wait for the rendered picker and inspect screenshots before choosing screenshot coordinates. Do not interpret a stale disabled Start snapshot as the post-dismissal state. Native output lists and hashes are in `native-output-audit.json`. The UI smoke added one copy of the known repository hummingbird fixture to the iPhone simulator Photos library and created two test output run folders in its selected local Files provider; these remain available for inspection.
