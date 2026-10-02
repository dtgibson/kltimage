# Supplied-image fidelity investigation

## Finding

The supplied `IMG_0063.JPG` reproduces the reported large color blocks in both RGB covariance and RGB correlation, and those blocks are already present in full-resolution **lossless PNG exports**. Lab retains a less block-dominated appearance. This sample therefore does not require a SwiftUI preview-only explanation.

The input is 49,010 bytes, 500×666 pixels, 8-bit baseline JPEG (SOF0). JPEG component sampling is Y 2×2, Cb/Cr 1×1: 4:2:0 chroma subsampling, with 16×16 luminance-pixel minimum coded units. All outputs remain exactly 500×666. Detail cannot be recovered beyond the pixels supplied by this compressed source.

Every output pixel for all four whole-image RGB/Lab covariance/correlation calculations matches an independent scalar application of the recorded center, matrix and output mapping, with maximum byte error **0**. Each output's PNG decode is byte-exact with its pre-export image. Source pixels remain unchanged. These checks establish faithful application of the fitted transform, not an independent proof that fitting statistics or scientific interpretation is correct; existing numerical/golden/replay suites cover the preserved arithmetic contract.

## JPEG boundary evidence

Approximate Cb/Cr were calculated from the unchanged decoded RGB source using conventional linear YCbCr coefficients in encoded RGB units. Mean adjacent differences near the 16-pixel JPEG grid (pixel-coordinate remainders 15, 0 or 1, allowing for chroma upsampling transitions) were compared with other adjacent differences. Horizontal and vertical means were averaged.

| Signal | Near grid | Interior | Ratio |
| --- | ---: | ---: | ---: |
| Source Cb | 0.3946 | 0.0510 | 7.744 |
| Source Cr | 0.6181 | 0.1420 | 4.353 |
| Source mean RGB step | 7.539 | 6.351 | 1.187 |
| RGB covariance result | 6.262 | 3.486 | 1.796 |
| RGB correlation result | 6.382 | 3.551 | 1.798 |
| Lab covariance result | 8.751 | 6.557 | 1.335 |
| Lab correlation result | 8.398 | 7.013 | 1.197 |

These are diagnostic observations on this sample, not general quality scores or a promise that any mode removes artifacts. The visible blocks, JPEG structure, source chroma grid alignment and exact per-pixel mapping support **amplification of existing JPEG chroma block structure**. No downsampling or newly generated spatial blocking was found in processing/export.

## Private reproducible evidence

The authorized input remains at `/Users/developer/Downloads/IMG_0063.JPG`. It was not committed or uploaded publicly. At the user-authorized private review request, decoded source and derived PNGs were copied only to the temporary tailnet preview root; no sample asset or private page was added to the repository. The following remain temporary and private:

- `/tmp/klt-native-ui-qa/analyze-user-sample.swift`: decode, process all four whole-image modes, independent scalar application, PNG round-trip/source checks.
- `/tmp/klt-native-ui-qa/private-sample-analysis.log`: exact dimensions and comparison results.
- `/tmp/klt-native-ui-qa/private-sample-block-metrics.txt`: boundary measurements.
- `/tmp/klt-native-ui-qa/private-sample/source-decoded.png`: unchanged decoded source.
- `/tmp/klt-native-ui-qa/private-sample/rgb-covariance.png` and `rgb-correlation.png`: strongly block-patterned lossless results.
- `/tmp/klt-native-ui-qa/private-sample/lab-covariance.png` and `lab-correlation.png`: corresponding Lab results.
- Matching `.rgba` files preserve decoded buffer bytes for further private comparison.

The supplied image was added only to the local iPhone simulator's Photos library for possible native follow-up, but no native capture of that image was needed to establish that its RGB export itself contains the blocks. No other user's directory, physical device or production service was accessed.

## Boundaries and product implication

The user's report identifies preview on both Mac and iOS, with export appearance previously unknown. This investigation now establishes the same type of block pattern in exported pixels for their sample. It does not exclude additional native rasterization effects in other images, establish exact screen/export equality, or show that every intermittent report has the same cause.

Preserve the scientific transform and existing interpolation policy. Smoothing, denoising or replacing color mathematics would change the scientific output and are outside the approved improvement. A higher-resolution/lower-compression original could provide more useful input, but the app cannot reconstruct missing source chroma detail. The verified product change remains the shared 1000% zoom ceiling; the fidelity work supplies evidence and regression coverage, not a claim to eliminate JPEG artifacts.

## Verified private comparison

https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-rgb-review/sample.html

The separate page compares unchanged source, RGB and Lab in both covariance and correlation. Its source and image copies live only under `/tmp/klt-rgb-fidelity-fixtures/sample.html` and `private-sample/`. Existing Tailscale Serve is tailnet-only. HTML and RGB image both returned HTTP 200; their served SHA-256 hashes matched the local files (`e999b8eec73c775c7ec79e907625e0842c59d0fe6388151b872ab8b09c928c9d` for HTML; `5b71f1205f6a3b4433e8dbe9e99b5f2115d9f128907e1d41d0931a2b12a8b7e4` for RGB covariance PNG). This is export evidence, not a native preview screenshot.
