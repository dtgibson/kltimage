# Design Spec — Core RGB Enhancement Workflow

## Visual Direction

KLT Image should feel like a precise scientific instrument that happens to be approachable, not a generic photo editor. The image content dominates the workspace, while cool blue-gray neutrals, clear measurement-style labels, and a restrained teal accent communicate confidence without competing with the specimen.

The interface stays clean and quiet. It reveals method details when asked, keeps interpretation guidance present but secondary, and uses motion only to explain changes in view or state.

## Screens / Views

### Loaded Image Workspace

The primary window uses a compact native title bar, a slim comparison toolbar, a large two-pane image canvas, and a single metadata strip along the bottom.

- The title bar centers the app and source filename, with Open Image and Export Result at the right.
- Export Result is the sole accent-filled action.
- The toolbar shows processing status and method, an Original / Split / Enhanced segmented control, and synchronized zoom controls.
- The canvas gives equal visual weight to the original and enhanced images in Split mode, separated by a crisp one-pixel divider.
- Original and Enhanced labels float directly over their corresponding panes.
- Both images maintain synchronized zoom and pan positions.
- The metadata strip names the source, current method, color conversion, numerical stability state, and exploratory-use limitation.
- Method details appear in a compact popover anchored to the information button.

### Empty State

The image canvas becomes a quiet drop target with one clear Open Image action, supported-format copy, and a short local-processing privacy note. It does not introduce extra cards, illustration, or onboarding steps.

### Processing State

The source remains visible while the enhanced pane shows a restrained progress treatment and the message “Calculating color components.” Controls that would invalidate the active calculation are temporarily unavailable, while cancellation remains available.

### Error State

Errors appear in the enhanced pane where the result would have appeared. The message says what went wrong in plain language and keeps Open Image immediately available.

### Export Confirmation

The standard Mac save panel handles the destination and overwrite confirmation. After selection, a compact status message confirms the export without obscuring the images.

## Component Usage

- SwiftUI window and toolbar composition for the native Mac shell.
- Native Button styles customized with the project tokens for secondary and primary actions.
- Native segmented Picker for Original / Split / Enhanced view selection.
- A custom synchronized image viewport for the two comparison panes.
- Native file importer and file exporter presentation.
- Native Popover for method details, anchored to its trigger.
- ProgressView presented inside the enhanced pane during calculation and export.
- Accessible status text using live announcements for processing, completion, and errors.

## Design Tokens Applied

- Ink strong: `#142A36`
- Ink: `#304854`
- Ink muted: `#667B84`
- Dominant navy: `#193A4A`
- Action accent: `#007F92`
- Accent hover/pressed: `#006C7D`
- Accent soft: `#D9F0F3`
- Surface: `#F7F9F9`
- Raised surface: `#FFFFFF`
- Surface tint: `#EDF3F4`
- Canvas: `#DBE3E5`
- Divider: `#9FB1B8`
- Success: `#18745F`
- Warning: `#A35F15`
- Display and body face: IBM Plex Sans, bundled with the app under its open license.
- Technical labels and numeric values: IBM Plex Mono.
- Type roles: 18–20 pt display, 12–15 pt body, 10–11 pt uppercase or monospaced labels.
- Spacing scale: 4, 8, 12, 16, 24, 32 points.
- Control radius: 8 points; popover radius: 12 points; window content radius: 16 points where applicable.

## Interaction Notes

- Opening a supported image begins processing automatically and preserves the source unchanged.
- Original, Split, and Enhanced modes change only presentation; they never recalculate the image.
- Zoom and pan changes apply to both comparison panes and persist when switching modes.
- The method popover reports whole-image sampling, sRGB, covariance 3×3, component stability, and local-only processing.
- Export Result opens the native save workflow and preserves full pixel dimensions.
- Escape closes the method popover and returns focus to its trigger.
- VoiceOver labels distinguish original and enhanced image panes and describe processing state without attempting to interpret image content.

## Motion Spec

- View-mode change: ease-out, 180 ms, center, near-instant opacity change under Reduce Motion, SwiftUI.
- Synchronized zoom: ease-out, 180 ms, image center or pointer focal point, immediate update under Reduce Motion, SwiftUI.
- Method popover: ease-out, 170 ms, information-button anchor, no scale under Reduce Motion, native SwiftUI popover transition.
- Export confirmation: ease-out, 220 ms, bottom-center status origin, immediate appearance and removal under Reduce Motion, SwiftUI.
- Processing completion: ease-out, 180 ms crossfade in the enhanced pane, pane center, direct replacement under Reduce Motion, SwiftUI.

## Content Notes

Copy is concise, factual, and calm. Use “RGB covariance” and “whole image” consistently. Avoid claims that the process discovers or proves biological structure.

The persistent interpretation note reads: “Color differences are amplified for inspection. The result is not, by itself, a scientific measurement.”

Errors name the user-visible problem and recovery action, such as: “This image could not be read. Try a JPEG, PNG, TIFF, or HEIC file.”
