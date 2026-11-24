# Building the corresponding source

This archive contains the source for KLT Image iOS 1.1.2 (8). It starts from the published 1.1.1 (7) source and includes the reviewed import and method-library hardening. The official signed distribution IPA has SHA-256 `5afe8e8b083602fbe4e6f3d5e0f40132213a56dafe95e2a0ed7cc76701d592a3`.

The file source-manifest.json lists source paths and hashes. The candidate-source-sha256.json file records the 71-entry build inventory. The public source release is https://github.com/dtgibson/kltimage/releases/tag/ios-1.1.2-build-8.

Use a development Mac with Xcode and an available local iOS simulator. The project uses Swift 6, SwiftUI, Accelerate, Core Graphics, ImageIO, UIKit and PhotosUI from Apple's SDK. There are no third-party source-code package dependencies. IBM Plex font resources and their OFL notices are included. The project targets iOS/iPadOS 18 or later. XcodeGen generates the project from `project.yml`; the generated project and shared schemes are also included.

Build without a physical device:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KLTImage.xcodeproj -scheme KLTImageIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath build build
```

For runtime checks, create or select your own local iOS simulator and use its explicit UUID as the destination. Tests live in `KLTCoreTests`, `KLTImageIOSTests` and `BatchTests`; `KLTImageIOSAdaptiveUI` is a focused native UI scheme that requires importing a fixture first. No image fixture is bundled into the app.

A distribution archive additionally needs the distributor's own Apple signing setup. No private keys, certificates, provisioning credentials, personal contacts or device configuration are part of this source package. Apple SDKs and system libraries are supplied separately by Apple.
