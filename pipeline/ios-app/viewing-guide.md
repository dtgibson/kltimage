## Seeing KLT Image for iPhone and iPad

### Review from your browser

1. Open the [private KLT Image iOS review](https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-preview/app/) while connected to the tailnet.
2. View the native iPhone and iPad Simulator captures. Open the linked interactive design study to explore the intended loaded comparison, analysis, sample, method, and export controls. Its enhanced colors are illustrative; the native app calculates the image with KLTCore.

### Use the native app on the development Mac

1. In Xcode, open `KLTImage.xcodeproj`, choose the `KLTImageIOS` scheme, choose an iPhone or iPad Simulator with iOS 18 or later, then press Run.
2. In the app, tap **Open image** and choose one original from **Photos** or **Files**. The app calculates locally and keeps the source unchanged.
3. Use **Original**, **Side by side**, **Slider**, and **Processed** above the image. Pinch to zoom, drag to pan, or use **−**, **+**, and **Fit**. The result and source stay aligned.
4. Tap **Draw sample** to select a rectangle on the source. Drag its interior to move it or a corner handle to resize it. Use **Coordinates** for exact source-pixel values.
5. Tap **Analysis** to change the working space, covariance/correlation, and sample source. Tap **Export result**, choose PNG, TIFF, or JPEG, and choose a system destination. Use the record button in the top bar to inspect and export JSON.
6. Open **Library** on iPhone or **Methods** on iPad to inspect methods, save a calculated transform, apply a saved transform, and exchange method documents through Files.

The browser link is available remotely now. A native app installation for remote testers will require the separately planned signed TestFlight build.
