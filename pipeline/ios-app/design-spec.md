# Design Spec — KLT Image for iPhone and iPad

**Status:** Review direction for Stage 4. The linked HTML is an interactive design study; its processing and color effect are illustrative, not an implementation of KLTCore.

## Visual Direction

The mobile app inherits the established KLT Image scientific instrument feel: precise, quiet, and led by the photograph. IBM Plex, cool blue-green surfaces, navy structure, and one teal primary action carry the Mac identity to touch without copying its window chrome. Original pixels and the execution mode are always easy to find.

The design stays within `pipeline/design-system.md`; no visual-system deviation is proposed. A single continuous image workspace replaces stacked cards. The original and enhanced view share one registered canvas. On iPhone, compact context sits below the image and detail opens in a native sheet. On wide iPad, the method and provenance inspector stays beside the image.

## Screens / Views

### Empty workspace

Show a quiet image glyph, a short explanation of local analysis, and one filled **Open image** action. A native source-choice confirmation offers Photos and Files, each requesting a complete original representation. The method library remains available without a source. Do not imply an image history or automatic cloud sync.

### iPhone workspace

Use a navigation bar with a library entry, centered product and source identification, and image/record actions. Below it, a compact four-way native-style comparison control selects Original, Side by side, Slider, or Processed. The image occupies the main canvas; Fit, Draw sample, and Coordinates float at the canvas edge without permanently covering evidence. A metadata strip below names the working space, matrix, sample, ready/busy state, and exploratory interpretation limit. The bottom area summarizes the active result, opens the analysis sheet, and reserves the filled teal action for **Export result**. Workspace and Library are bottom destinations.

The display example uses an Anna's hummingbird photograph at 4608 × 2592 pixels. The HTML embeds a CC0 Wikimedia Commons preview by CEKeech. The visible enhancement is a CSS approximation solely for reviewing the comparison layout; the shipped app renders KLTCore output. **Pinch with two fingers on the image to zoom** from Fit to 4×, then drag one finger to pan. The canvas shows the current percentage. Visible **−**, **+**, and **Fit** controls provide the same zoom access without a gesture on both devices.

### iPad wide workspace

Use a three-region layout: slim navigation sidebar, large comparison canvas, and persistent 266-point analysis inspector. The inspector shows working space, covariance/correlation, sample source, provenance, and explicit result/record exports. Keep original/result labels close to the image. The source and record context remain visible while the user changes comparison mode. If a Split View or window becomes narrow, collapse the sidebar and then move inspector content into a sheet; preserve all analysis and view state while adapting.

### Analysis sheet and sample editor

The analysis sheet presents working space, matrix mode, and independent whole-image/rectangle sample controls. Native menu/picker rows enumerate RGB, CIE Lab D65, shipped curated spaces, and valid user spaces. A rectangle starts a deliberate edit mode on the unchanged source. Touch can draw, move, and resize its four edges/handles. The separate **Exact source pixels** sheet provides X, Y, width, and height numeric fields for precision and VoiceOver. State the sampling rule in plain language: statistics come from the rectangle; its transform applies to the full image. Invalid or insufficiently varied regions keep the editor open, identify the exact problem, and never silently change to whole-image sampling.

Region bounds are integer source pixels, top-left and half-open. Fit/zoom/pan, device rotation, and comparison mode only change viewport mapping. The sample outline and image labels are view overlays and never appear in exported pixels. One registered viewport transform controls the source, processed image, and sample outline; pinch and pan must never offset one from another. Slider has an independent reveal value and a wide touch target; dragging its divider changes only reveal, including while zoomed. A region handle owns a region-edit gesture until release, so it cannot pan the canvas or move the divider. Two-finger pinch starts on the image outside an active region/divider gesture. The review HTML demonstrates these separate gesture owners on iPhone and iPad.

### Method library

The library is reachable without an image. Group Standard, Curated, User working spaces, and Saved transforms in a native list, with type and version clear in detail. Standard/curated definitions can be inspected and duplicated, not edited. User spaces expose create, edit, duplicate, rename, delete, import, and export. Saved transforms expose inspect, duplicate, rename, delete, import, export, and apply; saving a transform is offered only for a valid calculated result. Destructive actions use system confirmation. Document import errors explain unsupported, corrupt, oversized, or wrong-type files without changing current work. Conflict UI names incoming and local type/version and offers only applicable Replace, Import as Copy, and Cancel. A corrupt/future store shows recovery guidance and disables user-library mutation while retaining standard and curated calculation.

### Calculated and replayed results

**Calculated for this image** and **Replayed saved transform** are distinct prominent labels, with a compact version at the canvas. Replay detail shows recipe name and originating source separately from the current target; no target-derived covariance or eigenvectors are implied. The replay inspector can disclose clipping/range cautions and offers **Calculate for This Image** as a separate explicit action. Changing the effective method request clears prior result/record/export access until matching work completes. A provisional replacement import leaves accepted work in place until success.

### Analysis record and export

The record is a native sheet on iPhone and a detail pane or popover on iPad. It identifies calculated versus replayed execution, target source and dimensions, method snapshot, sample, channel order/units, matrices, output mapping, and, for replay, origin plus frozen values. State that enhanced color is exploratory evidence; lighting, noise, compression, and clipping can influence appearance. Record export uses the exact current result snapshot. The image export sheet offers PNG, TIFF, and JPEG, shows oriented full-resolution dimensions and alpha behavior, then invokes a system Files destination or share sheet. Neither action writes automatically to Photos. Cancellation and provider failure leave the workspace intact.

### Busy, error, and resource states

Place processing progress on or near the result canvas, keep the unchanged source accessible, and provide **Cancel**. A rejected source over 26,000,000 oriented pixels says the limit and asks for a smaller original while retaining the previous accepted workspace. Import/decode failures present Retry or Choose Another Image. Calculation, replay, and export failures state the failed action and the available recovery. Warnings use amber only for recoverable caution, with explicit text and no color-only meaning.

## Component Usage

- Native SwiftUI `NavigationStack`, `NavigationSplitView`, toolbar items, list rows, `Menu`, `Picker`, `.sheet`, `.confirmationDialog`, `ShareLink`/platform export adapters, `ProgressView`, and accessible `Button` controls.
- Custom comparison canvas and one-rectangle overlay are SwiftUI views backed by shared source-space geometry. They are not cards or another design library.
- PhotosUI/system document pickers handle explicit source and method selection; UIKit integration is limited to required system acquisition/export and gestures.
- Segmented comparison and matrix controls are customized with the project's radius, color, and cool borders. Maintain at least 44 × 44-point effective touch regions, even where the visible glyph is smaller.

## Design Tokens Applied

Use the exact `pipeline/design-system.md` colors: `inkStrong #142A36`, `ink #304854`, `inkMuted #667B84`, `navy #193A4A`, `accent #007F92`, `accentPressed #006C7D`, `accentSoft #D9F0F3`, `surface #F7F9F9`, `surfaceRaised #FFFFFF`, `surfaceTint #EDF3F4`, `canvas #DBE3E5`, `divider #9FB1B8`, `success #18745F`, and `warning #A35F15`. Tinted atmospheric canvas gradients and a low-contrast 24-point grid add depth behind, never on, the image. Use 4/8/12/16/24/32-point spacing, 8-point compact corners, and 12-point sheets/popovers.

Bundle IBM Plex Sans Regular/Semibold/Bold for display and body and IBM Plex Mono for dimensions, matrix values, and compact status. The mockup uses 32-point review display outside the app, 18–20-point app headings, 12–15-point body, and 10–11-point technical labels; the shipped SwiftUI text styles should scale with Dynamic Type while retaining three clear roles.

## Interaction Notes

- The four comparison modes change presentation only. No mode change recalculates, changes the current record, or changes exported pixels.
- Source/result/sample registration uses one viewport transform. A two-finger pinch zooms around the pinch midpoint; once zoomed, a one-finger drag pans the registered content and Fit returns to the full image. Keep zoom and pan when switching comparison modes or changing device layout. The slider changes only reveal fraction. Provide visible −, +, and Fit buttons, a spoken zoom percentage, accessibility actions for slider increments, and exact region entry.
- Analysis control changes create a new effective request. The previous result and record disappear immediately for that request, except during a provisional source import.
- A sheet never permanently covers the iPhone image; dismiss by Close or system gesture. On iPad, anchor method, record, and export detail near the invoking control when space allows.
- Every action has a VoiceOver label and result status. Contrast remains readable in light/dark system settings; the intentionally light scientific workspace uses explicit foreground and border tokens. Support Dynamic Type reflow and Reduce Motion.
- The review HTML simulates methods, processing, import, and export. Its system destination buttons are illustrative; the native app must use real system pickers and the accepted result snapshot.

## Motion Spec

- Analysis/source/record sheet entry: ease-out, 220 ms, bottom edge on iPhone and trigger-side top corner on iPad, near-instant opacity under Reduce Motion, native SwiftUI sheet transition.
- Segmented comparison change: ease-out, 180 ms, selected segment, near-instant without spatial movement under Reduce Motion, SwiftUI animation.
- Slider reveal: direct gesture tracking with no delayed spring; release settles in 150 ms only if needed, divider position, no extra animation under Reduce Motion, SwiftUI gesture/animation.
- Pinch zoom and pan: direct touch tracking with no spring or delayed interpolation; transform origin follows the pinch midpoint, Reduce Motion changes nothing because the content directly follows touch, SwiftUI magnification and drag gestures sharing one viewport transform.
- Region creation and handle editing: direct gesture tracking; valid-outline transition ease-out 150 ms from the touched handle, no scale under Reduce Motion, SwiftUI gesture/animation.
- Busy/result replacement: ease-out opacity 180 ms on the result area only, no static-content entrance, near-instant opacity under Reduce Motion, SwiftUI animation.
- Control hover/press in the browser mockup: ease-out 160–180 ms, the control, no transform under Reduce Motion, CSS. Native controls use platform press feedback.

## Content Notes

Use concise scientific language. Name execution as **Calculated** or **Replayed** rather than a generic success state. Refer to the source as unchanged and to the chosen sample as the source of statistics. Never claim that enhancement proves a biological feature. In a saved-transform replay, origin values stay labeled as origin values. Use real format names and pixel dimensions, and present the 26-million-pixel iOS limit before attempting expensive decode.

## Review Source

The embedded mockup photograph is “20131103 male anna's hummingbird DSCN5041.jpg” by CEKeech, CC0, from Wikimedia Commons. Its original is 4608 × 2592 pixels. The project copy is `specimen-anna-hummingbird.jpg` for design reference only; the app must not ship it as a sample analysis or suggest the illustrative CSS effect is a computed result.
