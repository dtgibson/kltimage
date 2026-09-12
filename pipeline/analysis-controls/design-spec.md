# Design Spec — Analysis Controls

## Visual Direction

Analysis Controls extends KLT Image's established visual system without changing its overall look. The workspace remains a precise, quiet, fixed-light scientific instrument: IBM Plex typography, blue-green tinted neutrals, restrained depth, and teal used only for the primary action or an active scientific state.

The photograph remains the focal point. A compact analysis rail adds the three method choices and exact region editing beside the existing synchronized comparison canvas, while dividers—not nested cards—create structure. The active region reads as a sampling instrument over the image, never as a crop, mask, or localized enhancement.

## Screens / Views

### Loaded Image Workspace

The loaded workspace retains the shipped four-part composition: title bar, comparison toolbar, image workspace, and metadata strip. The image workspace becomes an asymmetric split with a fixed-width analysis rail on the left and the larger synchronized image canvas on the right.

- Keep the title bar compact, centered on `KLT Image` and the filename plus source dimensions.
- Keep Open Image as a secondary action and Export Result as the sole filled accent action.
- The comparison toolbar displays the current request in plain language: status plus color space, matrix mode, and sample source. Original / Split / Enhanced remains centered; synchronized zoom stays at the trailing edge.
- The analysis rail should be approximately 258–278 points wide, depending on available window width. It scrolls independently if vertical space is constrained; the image canvas does not shrink below its usable minimum.
- Preserve the current minimum window size of 900 × 620 points or increase it only if the implemented rail cannot remain operable at that size. At narrower supported widths, prioritize the analysis rail and canvas; the interpretation group in the bottom metadata strip may collapse before core controls do.
- The canvas keeps the cool technical grid, flat image panes, one-pixel split divider, subtle image shadow, and direct pane labels.

The approved mockup opens in a realistic in-progress exploration state—Lab, correlation, and a selected region—to demonstrate the feature. The shipped app launch default remains RGB, covariance, and whole image.

### Analysis Rail

The rail is one continuous surface divided into four structural regions: heading, Color space, Matrix mode, and Statistical sample, followed by a compact active-method summary. Do not wrap these sections in cards.

- Heading: `Analysis controls`, with one sentence explaining that the choices determine the variables, matrix, and pixels that establish the transform.
- Color space: a compact two-segment native control for RGB and Lab. Supporting copy changes with the selection. RGB describes display-oriented red, green, and blue channel values; Lab describes lightness plus two chromatic axes using CIE Lab D65.
- Matrix mode: a compact two-segment native control for Covariance and Correlation. Supporting copy explains that covariance preserves the original scale of variation, while correlation normalizes stable variables to unit variance.
- Statistical sample: two vertically stacked radio-style rows for Whole image and Selected region. Each row includes a concise consequence, not just a label.
- The three groups are independent. Changing one must never silently change another.
- Active segments use a raised light surface, accent-colored label, and a narrow teal lower edge. Inactive labels stay strong enough to remain legible in macOS dark system settings because this workspace deliberately renders in the fixed light appearance.
- The bottom summary repeats the full active combination and its stability/local-processing status without exposing matrices or channel statistics.

### Source-Region Editor

Selecting `Selected region` reveals one editor directly below the sample choices.

- Show integer fields for X, Y, Width, and Height in a two-column grid. Bind the fields to string drafts so empty, partial, signed, overflowed, or invalid input remains visible for correction.
- State each field's valid source range and say: `Origin is the source image's top-left.`
- `Apply bounds` commits one validated rectangle. Return/Enter from any numeric field performs the same action.
- `Clear region` removes the committed region. If selected-region sampling remains active, the workspace enters Awaiting region and does not recalculate.
- Show the committed sample pixel count in IBM Plex Mono.
- A compact feedback area below the fields reports either validity and meaning or the specific corrective error. It uses a success-colored leading rule for a valid region and a warning-colored leading rule plus warm-tinted background for a recoverable problem; it is not a modal alert.
- Numeric committed input is never silently clamped, normalized, expanded, or replaced. Keep the user's attempted values visible.

### Region Overlay and Direct Manipulation

The one axis-aligned region is rendered over the actual displayed image content, derived from canonical oriented source-pixel bounds through the pane's viewport transform.

- Active overlay: 2-point teal outline, very light teal interior, restrained dimming outside the rectangle, a compact `SAMPLE` label with megapixel count, and visible corner handle affordances.
- Split mode mirrors the same source rectangle on both visible panes. The enhanced-side overlay is informational; direct manipulation happens on the source pane so there is one unambiguous editing surface.
- Pointer interaction supports drawing a replacement rectangle, dragging the existing rectangle, and resizing it. Live pointer proposals may stay constrained within the source, but processing begins only when the gesture commits.
- Zoom, pan, fit, and comparison-mode changes update only the viewport transform. They must never rewrite source bounds.
- When Whole image is active, retain an existing region as a subdued dashed outline labeled `SAVED SAMPLE · INACTIVE`. Switching back reuses it if valid.
- The overlay exists only in the presentation layer. It never modifies the source or enhanced buffers and is never included in export.
- The image-pane accessibility value states the image dimensions, zoom level, whether a sample exists, and its exact X, Y, width, and height. Do not ask VoiceOver to infer region meaning from the visual outline.

### Comparison Canvas

Original, Split, and Enhanced presentation remains available for every current completed result. Navigation stays synchronized.

- Original shows the immutable source and its overlay when selected-region sampling is active.
- Split gives equal visual weight to source and result, separated by one crisp divider. Both panes use identical zoom and pan and mirror the canonical region bounds.
- Enhanced shows the full transformed frame. Its pane label includes a compact currency state: `CURRENT`, `PREVIOUS · UPDATING`, or `PREVIOUS · NOT CURRENT`.
- Pane labels sit directly over the image area and use the established raised, translucent treatment. The teal dot belongs only to the active enhanced/result state.
- Comparison controls never trigger analysis and remain separate from the method request key.

### Ready State

Status reads `RESULT READY` with the success dot. The full current method is visible in the toolbar, rail summary, and metadata strip. Export Result is enabled only when the completed result key exactly matches the current source, method, sample source, and committed region.

For selected-region results, visible copy says `Region statistics · full-image transform` so the rectangle cannot be misread as the only enhanced area.

### Updating and Stale-Result State

When a valid method or committed region changes, retain the prior enhanced image for visual continuity but immediately mark it stale.

- Toolbar status reads `UPDATING RESULT` and identifies the requested combination.
- Enhanced pane label reads `PREVIOUS · UPDATING`.
- Present a restrained translucent shade over the enhanced pane with a compact progress plate: `Recalculating full image` plus the requested method.
- Controls, comparison presentation, zoom, and region editing remain responsive. Export Result is disabled.
- Only the enhanced pane changes; the original remains fully visible and unchanged.
- If a superseded job completes late, do not animate or announce it because it must not enter displayed state.

### Awaiting-Region State

Selecting Selected region without a committed region starts no analysis and never falls back to Whole image.

- Toolbar status reads `AWAITING REGION` with the warning dot.
- Keep any prior enhancement visible but label it `PREVIOUS · NOT CURRENT`; disable export.
- Show a warm-tinted, non-modal banner over the bottom of the canvas: `Select a region on the image or enter source-pixel bounds. KLT Image will not substitute whole-image statistics.`
- Keep focus in the region workflow: the user can draw on the source image or reach the X field by keyboard.
- Announce the state and required recovery action once through the existing accessibility announcement path.

### Invalid or Insufficient-Variation State

Invalid geometry and insufficient color variation are recoverable analysis states, not destructive errors.

- Keep the attempted numeric drafts visible and identify the exact issue: missing region, non-positive size, fewer than four pixels, outside-source bounds, or insufficient variation.
- Mark the relevant fields invalid and connect them to the feedback text with accessibility descriptions.
- Keep the source and any prior enhancement visible. Mark the prior result `PREVIOUS · NOT CURRENT` and disable export.
- Never imply that the app enlarged the region, switched matrix mode, switched color space, or substituted whole-image statistics.
- For partial stability in a valid result, use `LIMITED VARIATION` and report the stable component count in method details. Do not turn the entire screen into a warning if a bounded result is still valid.
- A processing failure uses the established enhanced-pane error placement, preserves the source and prior result where available, and supplies a plain-language recovery action.

### Whole-Image State

Whole image is the launch default and compatibility baseline.

- Hide the numeric region editor while whole-image sampling is active.
- If a valid region exists for this source, show it as the subdued inactive outline rather than deleting it.
- Status and method copy explicitly say `whole image`; method details report the full source pixel count.
- RGB + covariance + whole image must visually and behaviorally match the shipped baseline outside the newly added rail.

### Method Details Popover

The information button in the metadata strip opens a compact popover anchored to that trigger.

- Heading combines the current color space and matrix mode, such as `Lab correlation`.
- The first paragraph explains those two choices in plain language.
- Definition rows show Statistics from, Applied to, Stable components, and Processing. Region mode includes the selected pixel count; `Applied to` always states the full source dimensions.
- A warm-tinted guidance note says that the methods are alternative exploratory views, not ranks of accuracy, and names conversion, normalization, gamut clipping, noise, compression, lighting, and region choice as possible influences.
- Escape closes the popover and restores focus to the information button. Focus initially moves to the popover's close button; keyboard navigation remains contained in a sensible order without trapping the user permanently.

### New Source, Empty, and Export States

- Preserve the shipped empty-state treatment and primary Open Image action.
- If an import exceeds 64 megapixels, use the established readable import-failure placement and say: `This image exceeds KLT Image's 64-megapixel processing limit. Try a smaller file.` Do not begin full-frame decoding or leave a prior result labeled current for the rejected source.
- Opening a different source clears region/editor state, switches sampling to Whole image, resets comparison/zoom/pan, retains only the current app session's color-space and matrix choices, and starts a new current request.
- Export uses the standard macOS save panel through AppKit, exports only the exact current completed enhancement at source dimensions, and omits the sample overlay and interface decoration.
- During export, preserve the existing compact status and cancellation behavior. A short confirmation may read `Exported PNG at full resolution`; VoiceOver receives the filename and format through the existing announcement path.

## Component Usage

- Build the application shell and all controls in native SwiftUI; introduce no third-party component or motion dependency.
- Continue using the existing `PrimaryActionButtonStyle` and `SecondaryActionButtonStyle`. Export Result is the only filled-accent action in a loaded workspace.
- Use native segmented `Picker` controls for RGB / Lab, Covariance / Correlation, and Original / Split / Enhanced, with explicit fixed-light appearance, customized surface, border, tint, and focus treatment matching the existing comparison picker.
- Use a custom radio-row `Button` or an accessibility-equivalent native `Picker` presentation for Whole image / Selected region. The entire row is a hit target and exposes selected state to VoiceOver.
- Use four SwiftUI `TextField`s bound to draft strings, not integers. Apply monospaced digits, source-range labels, invalid-state borders, `accessibilityValue`, `accessibilityHint`, and an accessibility description that names the validation problem.
- Implement the image/overlay composition with `GeometryReader` plus a pure `ImageViewportTransform`. Render the selection with SwiftUI shapes above each `Image`; use `DragGesture` variants for create, move, and resize. Keep coordinate conversion out of the view body and out of AppKit.
- Reuse the existing synchronized viewport composition for comparison panes. Apply the same canonical region to each pane's independently calculated fit transform.
- Use native `ProgressView` inside the enhanced-pane updating plate. Do not build a pulsing or decorative custom loader.
- Use a native SwiftUI `popover` anchored to the metadata information button. Customize its internal spacing, typography, warning note, and width; retain platform dismissal behavior.
- Continue using AppKit `NSOpenPanel`, `NSSavePanel`, replacement confirmation, and `NSAccessibility.post` at the existing file and announcement boundaries.
- Derive every status/method string from the current `AnalysisInput`, current `AnalysisRequestStatus`, and accepted `AnalysisDescriptor`. Do not duplicate scientific state in view-local booleans.
- Keep `KLTCore` free of SwiftUI/AppKit. SwiftUI receives validated region/status/descriptor data but never calculates statistics, edits buffers, or decides result currency.

## Design Tokens Applied

- `inkStrong`: `#142A36` for primary text and icons.
- `ink`: `#304854` for body text and unselected high-value controls.
- `inkMuted`: `#667B84` for supporting copy, ranges, metadata, and inactive labels.
- `navy`: `#193A4A` for dominant structural tone and restrained shadow color.
- `accent`: `#007F92` for Export Result, active method indicators, active region outline/handles, and updating status only.
- `accentPressed`: `#006C7D` for pressed/hover accent state and high-contrast active labels.
- `accentSoft`: `#D9F0F3` for selected sample-row and informational emphasis.
- `surface`: `#F7F9F9` for the window and analysis rail.
- `surfaceRaised`: `#FFFFFF` for selected segments, fields, popovers, and raised utility controls.
- `surfaceTint`: `#EDF3F4` for toolbars and grouped control wells.
- `canvas`: `#DBE3E5` for the technical image workspace.
- `divider`: `#9FB1B8` for pane division, strong field borders, and inactive region outlines.
- `line`: `#C9D4D8` for one-point structural dividers.
- `success`: `#18745F` for current/ready status and valid-region feedback.
- `warning`: `#A35F15` for awaiting, invalid, insufficient-variation, and recoverable failure states only.
- Display and body: bundled IBM Plex Sans. Use 20-point bold/tight tracking for `Analysis controls`, 12–15-point regular/semibold for body and controls, and the existing 15-point application title.
- Technical labels and values: bundled IBM Plex Mono at 9–11 points with increased tracking for uppercase status labels and tabular/monospaced digits for coordinates and counts.
- Spacing scale: 4, 8, 12, 16, 24, and 32 points. Rail section padding is 13–16 points; related compact controls use 4–8-point internal gaps.
- Control radius: 8 points. Compact field/segment interiors: 6 points. Popovers and raised utility overlays: 12 points. Image frame: 4 points.
- Borders: one point for structure; two points for the active selection outline. Avoid decorative borders and nested elevation.
- Depth: restrained navy-tinted shadows only on the application window, displayed image, popover, and transient status plate. Keep the rail and panes otherwise flat.

## Interaction Notes

- Launch with RGB + Covariance + Whole image. Do not persist method choices or geometry after app termination.
- Keep color space, matrix mode, and sample source independently selectable. A valid committed change requests exactly one recalculation from the unchanged decoded source.
- Track numeric drafts separately from committed `SourcePixelRegion`. Editing a draft does not recalculate. Apply bounds or Return validates and commits; an invalid commit retains all drafts and starts no job.
- Direct creation, move, and resize update a live proposal, then commit once on gesture end. Creation replaces the prior rectangle; exactly one region exists.
- Use upper-left oriented source coordinates and half-open integer bounds. Apply `floor` to lesser live edges and `ceil` to greater live edges. Numeric input is never silently clamped; pointer proposals may be constrained before commit.
- Give overlay handles comfortable pointer hit areas larger than their visible 12-point marks. Change the pointer cursor through an AppKit-backed hover/cursor modifier where appropriate: crosshair for drawing, open/closed hand for moving, and diagonal resize for the corner handle.
- Maintain visible keyboard focus on every segment, sample row, numeric field, Apply bounds, Clear region, method-details trigger, comparison control, zoom action, Open, Cancel, and Export.
- Provide full keyboard region editing through the numeric fields. Field labels and accessibility values identify X, Y, width, or height, the current draft, valid range, and upper-left origin. Return applies; Escape cancels an uncommitted draft only if that behavior is implemented consistently and announced.
- Expose the overlay as one accessibility element per visible pane, not separate decorative outline/handle elements. The source-pane element describes the sample and instructs pointer users to drag; VoiceOver users are directed to the numeric fields.
- Announce awaiting, invalid, processing, limited-variation, completion, failure, cancellation, and export outcomes through `statusAnnouncement`. Coalesce rapid superseded changes so VoiceOver is not flooded with obsolete completion messages.
- Every visible request change immediately makes a mismatched completed result stale. The old image may remain visible, but its own descriptor identity must not be relabeled with the new method.
- Disable export whenever the current request is awaiting, invalid, processing, failed, or unmatched. Enable only when `completedEnhancement.key == currentRequestKey` and status is ready.
- Keep method and region controls operable during recalculation so a user can supersede work. Cancel older tasks opportunistically and reject late callbacks by both job ID and request key.
- Comparison mode, zoom, pan, and method-popover state are presentation-only. They do not create a new analysis request.
- New-image import invalidates prior work before callbacks can mutate the workspace, clears region state, chooses Whole image, resets navigation, and retains color/matrix choices only for the current app session.
- Fixed-light control styling must be tested under macOS light and dark system settings. Do not allow native dark appearance to produce low-contrast unselected segment labels.

## Motion Spec

- Analysis segment selection: ease-out, 150 ms, selected segment center, near-instant color/border replacement under Reduce Motion, native SwiftUI animation.
- Sample-source row selection: ease-out, 150 ms, selected row center, immediate selected-state replacement under Reduce Motion, native SwiftUI animation.
- Region editor reveal/hide: ease-out, 180 ms, sample-row/top-leading origin, opacity-only near-instant replacement under Reduce Motion, native SwiftUI transition.
- Region activation/inactivation: ease-out, 150 ms, rectangle center, immediate outline/fill replacement under Reduce Motion, native SwiftUI animation.
- Region direct manipulation: no interpolation during drag or resize; follow the pointer immediately, no change under Reduce Motion, native SwiftUI gesture updates.
- Region commit or numeric apply: ease-out, 150 ms, committed rectangle bounds, immediate geometry replacement under Reduce Motion, native SwiftUI animation.
- Comparison mode change: ease-out, 180 ms, canvas center, near-instant opacity replacement under Reduce Motion, native SwiftUI transition.
- Synchronized zoom: ease-out, 180 ms, image center or pointer focal point, immediate scale update under Reduce Motion, native SwiftUI animation.
- Pan: no decorative easing while dragging; track the pointer directly, no change under Reduce Motion, native SwiftUI gesture updates.
- Updating plate and stale label: ease-out, 180 ms, enhanced-pane center, near-instant opacity-only replacement under Reduce Motion, native SwiftUI transition plus native `ProgressView`.
- Accepted-result replacement: ease-out, 180 ms, enhanced-pane center, direct image replacement under Reduce Motion, native SwiftUI opacity transition.
- Awaiting/validation feedback: ease-out, 150 ms, feedback area's top-leading edge, immediate text/color replacement under Reduce Motion, native SwiftUI transition.
- Method-details popover: ease-out, 170 ms, information-button anchor, native no-scale/near-instant presentation under Reduce Motion, native SwiftUI popover.
- Export confirmation: ease-out, 220 ms, bottom-center status origin, immediate appearance/removal under Reduce Motion, native SwiftUI transition.

Do not add bounce, overshoot, blur entrances, pulsing indicators, staggered launch animation, hover scaling, or animation to unchanged static content.

## Content Notes

Copy is concise, factual, calm, and technically honest. It should help a researcher understand the active basis without implying that Lab or correlation is more accurate, or that a selected region proves a biological feature.

- Use the exact option labels `RGB`, `Lab`, `Covariance`, `Correlation`, `Whole image`, and `Selected region` consistently.
- Describe RGB as display-oriented red, green, and blue variables. Describe Lab as CIE 1976 L*a*b* with D65, separating lightness from chromatic axes.
- Describe covariance as preserving the original variable scale and correlation as normalizing stable variables to unit variance. Avoid `better`, `more precise`, or `correct` comparisons.
- Region guidance must repeatedly reinforce: `The selected region supplies statistics; the full image receives the transform.`
- Awaiting-region guidance must explicitly say no whole-image fallback will be used.
- Use `CURRENT`, `PREVIOUS · UPDATING`, and `PREVIOUS · NOT CURRENT` for result currency. Never label a stale prior result with the new requested method.
- Keep the persistent interpretation note: `Color differences are amplified for inspection. The result is not, by itself, a scientific measurement.`
- Method guidance must name Lab conversion, correlation normalization, output-gamut clipping, noise, compression, lighting, and region choice as influences on the exploratory view.
- Show stable-component counts or `Limited variation`, but do not display matrices, eigenvectors, per-channel statistics, numerical reports, manifests, or reproducibility data.
- Errors name the exact problem and recovery action. Prefer `These bounds extend outside the 6048 × 4024 source. Values are kept for correction.` over generic invalid-input language.
- Privacy copy remains `Your images stay on this Mac.` Processing status may add `local only` where space permits.
