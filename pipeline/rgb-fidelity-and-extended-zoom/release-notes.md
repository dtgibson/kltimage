# KLT Image 1.3.3 (9) / iOS 1.0 (2) — candidate notes

The existing zoom buttons and pinch gestures now share a 1000% maximum on Mac, iPhone and iPad. Fit-relative zoom, image dimensions, scientific transforms, interpolation, and export behavior are preserved.

Fidelity regression checks verify full image dimensions and per-pixel transform mapping. Investigation of a supplied JPEG reproduced its RGB color blocks in full-resolution lossless exports and found evidence consistent with amplification of existing JPEG chroma block structure. This release does not remove JPEG artifacts or change the scientific calculation.

## Verification limits requiring sign-off

Mac Debug and optimized core/app suites pass, as do the local iPhone/iPad native zoom controls and the performance requirement. QA remains **NEEDS VERIFICATION**: native Mac button/pinch/out/Fit behavior; maximum-zoom pan, image registration, sample and slider gesture ownership; verified comparison-mode transitions; and matched native screen-versus-export detail remain open. No physical-device or TestFlight installation acceptance is claimed.

These are prepared, unpublished candidates. Publication requires explicit approval acknowledging the outstanding checks. Mac delivery is a signed, notarized universal ZIP through GitHub Releases; iOS delivery is a separate internal TestFlight upload.
