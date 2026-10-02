# Scoping Evidence — RGB Fidelity and Extended Zoom

## Confirmed from current source
- `KLTImageIOS/IOSWorkspace.swift:327` clamps button zoom to 4; `KLTImageIOS/RegisteredCanvas.swift:352` independently clamps pinch to 4. Mac equivalents clamp to 8 in `KLTImage/WorkspaceModel.swift:641` and `KLTImage/ComparisonCanvas.swift:160`.
- `KLTImageIOS/RegisteredCanvas.swift:13` computes a fit size before multiplying by zoom. Thus 100% means fit, and the requested 1000% is 10 times fit; it is not a new promise of ten display pixels per source pixel. Keep this established meaning.
- `KLTCore/ImagePipeline.swift:216` requests ImageIO orientation through a thumbnail API with `CreateThumbnailFromImageAlways` and maximum dimension equal to the original longest edge. This is intended as full-size decode, not an embedded-preview request. Actual decoded dimensions are bounded afterward but are not explicitly checked against expected oriented metadata dimensions.
- Baseline RGB (`ImagePipeline.swift:296`) and configured RGB (`:991`) visit every source pixel, allocate `source.pixelCount * 4`, and construct the result with original width/height. Lab (`:1051`) has the same per-pixel spatial extent. Tagged standard requests route to those shipped paths (`:535`). No RGB-only resizing or block averaging was found.
- Both platforms render original/result CGImages through the same resizable image treatment with high interpolation (`KLTImage/ComparisonCanvas.swift:396`, `KLTImageIOS/RegisteredCanvas.swift:239`). They frame the image to the zoomed viewport rather than intentionally creating a small result bitmap. Runtime SwiftUI rendering fidelity still needs inspection.
- Mobile Photos requests `.current` representation and `loadFileRepresentation`, not a UIImage preview (`KLTImageIOS/PhotosSourcePicker.swift:12,55`). Mobile exports the accepted result CGImage (`KLTImageIOS/IOSWorkspace.swift:371`). These establish intent, not proof of all provider behavior on devices.

## Working hypotheses and limits
RGB computes one transform, expands stable color differences, globally maps transformed channel extrema, and rounds to 8-bit output (`ImagePipeline.swift:991–1048`; `DecorrelationStretch.swift:206–277`). Lab uses a different coordinate/mapping path. Amplified JPEG/HEIC chroma blocks or quantization can therefore look different between modes without reduced pixel dimensions. This is a plausible explanation, not a reproduced root cause.
Other candidates are runtime display rasterization and unexpected decoded source size. Do not dismiss those using dimension checks alone, and do not rewrite the RGB transform merely because Lab looks smoother.
No affected user image, reliable steps, or preview-versus-export localization was available during this evaluation. No app execution, benchmark, or visual reproduction was performed here; findings are static source evidence. Existing tests were inspected, not rerun.

## Engineering/QA evidence to obtain
- Create a deterministic high-frequency/fine-detail lossless fixture with nondegenerate color variation; test RGB covariance/correlation and Lab over the same decoded bytes. Inspect and compare pixel results against an independent scalar/reference application of the recorded transform, including points across detail boundaries. RGB and Lab colors need not match each other.
- Encode a compressed version of that controlled source, then compare each mode's output to its lossless counterpart to isolate amplified codec artifacts from algorithmic spatial loss. Keep the source codec and numerical method in evidence.
- Verify decoded metadata orientation, decoded buffer, processed CGImage, and PNG/TIFF/JPEG export dimensions. Assert actual output detail and selected pixels for lossless paths, alpha preservation, source immutability, deterministic output, and replay compatibility; use codec-appropriate tolerances for JPEG.
- Check original and result presentation against exported/reference crops at matched positions and zoom in each existing comparison mode on the development Mac and local iPhone/iPad simulators. Zoom alone is not evidence that full-resolution source detail reached the screen.
- Exercise common 10x clamp with repeated button presses, repeated pinches, overshoot, zoom-out, fit reset, pan limits/anchor behavior, sample placement, and slider drag ownership. Existing viewport tests cover only modest zoom, so extend the relevant behavior coverage.
- Preserve existing baseline/golden-output tests (`KLTCoreTests/AnalysisControlsTests.swift:136`), method replay tests, decode policy, exports, and cancellation/currency tests. The current tiny dimension fixtures (`KLTCoreTests/KLTCoreTests.swift:451–484`) do not by themselves reproduce the complaint.

## Delivery boundaries
This remains an improvement to existing analysis and zoom; there is no new surface, schema, or persisted data. A shared zoom constant/helper may live in a supporting core file; regenerate the project only if project settings require it. Final reports must distinguish verified corrections from an unresolved user symptom. Any user-facing preview must be verified HTTPS Tailscale and tailnet-only; use local simulators only, with physical-device testing reserved entirely for the user and testers through TestFlight.

## User clarification during QA
The user observes blockiness in the preview on both Mac and iOS. Whether exports are affected is unknown. Prioritize processed preview versus exported/reference detail; compression amplification remains a hypothesis, not a confirmed cause.
