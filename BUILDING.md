# Building the corresponding source

This archive is the source for KLT Image iOS 1.1.1 (7), prepared from the exact published 1.1 (6) source archive. Only required version/build metadata and the embedded build/source-tag notice changed; all 42 shipping Swift files and all 52 packaged Swift files remain byte-identical. It is not a claim that the current public GitHub main branch matches the binary. `source-manifest.json` lists every packaged file and hash; `candidate-source-sha256.json` records the 71-entry candidate inventory.

This candidate and its matching source are prepared locally and have not been uploaded, submitted or published. The planned Corresponding Source destination is https://github.com/dtgibson/kltimage/releases/tag/ios-1.1.1-build-7; that destination must be published and verified before delivery of this candidate.

The locally signed distribution IPA has SHA-256 `c60eb3f6c27427c6a4f73553e9acd26880a9fab4ffd455e3a2973b5ca0e333b4`. A simulator build from this source is source-equivalent; it is not byte-identical to that signed distribution IPA.

Use a development Mac with Xcode and an available local iOS simulator. The project uses Swift 6, SwiftUI, Accelerate, Core Graphics, ImageIO, UIKit and PhotosUI from Apple's SDK. There are no third-party source-code package dependencies. IBM Plex font resources and their OFL notices are included. The project targets iOS/iPadOS 18 or later. XcodeGen generates the project from `project.yml`; the generated project and shared schemes are also included.

Build without a physical device:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KLTImage.xcodeproj -scheme KLTImageIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath build build
```

For runtime checks, create or select your own local iOS simulator and use its explicit UUID as the destination. Tests live in `KLTCoreTests`, `KLTImageIOSTests` and `BatchTests`; `KLTImageIOSAdaptiveUI` is a focused native UI scheme that requires importing a fixture first. No image fixture is bundled into the app.

A distribution archive additionally needs the distributor's own Apple signing setup. No private keys, certificates, provisioning credentials, personal contacts or device configuration are part of this source package. Apple SDKs and system libraries are supplied separately by Apple.
