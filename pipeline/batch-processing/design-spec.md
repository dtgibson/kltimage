# Design Spec — Batch Processing

## Visual Direction

Extend the established KLT Image design system: a quiet scientific workspace, IBM Plex typography, tinted neutral surfaces, and a single teal primary action. Use a continuous numbered file list beside a focused setup form; do not add image thumbnails, galleries, dashboards, or new method-editing surfaces. This specification follows the approved brief, PRD, and architecture under Autopilot; no user design-approval wait was required.

The native implementation is SwiftUI with existing AppKit/UIKit/PhotosUI integrations. `design.html` is an interactive design-review model, not application code. Its outer layout/scenario controls, example source names, simulated picker dialogs, and timer are review tools only.

## Screens / Views

### Entry and presentation

Add a secondary **Batch…** action beside the existing Methods/Open Image actions on Mac. On compact mobile, put **Batch processing** in the existing workspace action menu, reachable with an empty or populated workspace. Do not promote it above the current workspace's primary action. The current source/result, method, region, comparison, zoom, and pan remain unchanged.

Present one dedicated, resizable Mac batch sheet/surface, an iPad sheet that can grow to the available width, and an iPhone full-screen sheet with native navigation/header and safe-area footer. Use the shared exclusion lease before setup becomes usable. If an interactive operation is already running, show **Waiting for the current operation…** and **Close**; the existing operation's cancellation route remains available. Do not silently cancel it. All interactive execution routes remain guarded while Batch owns the lease.

The preview's close action represents native dismissal. Setup/outcome dismissal releases temporary access and discards the batch's transient list and outcomes. Reopening starts empty with the specified defaults.

### Setup

At about 900 points of usable width and above, split the surface into a 38–42% source pane and remaining setup pane. Below that width, stack source review above settings; at accessibility text sizes use the stacked layout even on a wide device. Avoid fixed heights. The footer stays reachable via `safeAreaInset`, can grow vertically, and never covers scrolling content.

The source pane shows **Images**, the selection count out of 100, **Up to 100 images per batch**, **Add files…**, and **Clear**. Mobile also has **Add from Photos…**. Number every entry with three digits. Show source display names, separate repeated selections, and any known selection errors. Remove controls have explicit accessible names, including ordinal and filename. Before acquisition, status is **Not checked**; no invented dimensions, file availability, or success checkmarks.

Compact layouts initially show two entries and **Show all N images**. Expansion retains access to every row and remove action. Desktop shows the complete list in a scrollable pane. `List`/lazy stacks can virtualize rows; no thumbnails or decoded previews are needed. Removing entries before Start renumbers the setup list; Start freezes the accepted ordinals. Selection order and repeats follow native picker results.

Empty copy: **Choose your photographs** / **Add JPEG, PNG, TIFF, or HEIC files. Your original images stay unchanged.** The existing list is preserved if a picker is canceled or an over-capacity addition is rejected. Over-limit copy: **That selection exceeds 100 images. No images were added.** During selection callbacks, show **Adding selected images…** and disable Start; never start source acquisition just to display rows.

Use a native two-option radio-style group or equivalent selectable rows, not an ambiguous “method” picker:

| Choice | Always-visible explanation | Controls below |
| --- | --- | --- |
| **Calculate each image** (default) | Fit a new transform from each image's own whole-image statistics. | Existing working-space picker, default RGB; covariance/correlation, default covariance. |
| **Replay saved transform** | Apply one saved transform unchanged. No target statistics are fitted. | Existing local saved-transform picker; no automatic selection, matrix override, or region controls. |

Calculation shows **Whole-image statistics** and **Each fit is independent. Matching settings do not establish quantitative color comparability.** Use the existing standard/curated/user working-space catalog and labels. The HTML's custom entry is explicitly example data, not a new built-in space. Do not inherit the interactive selection or region.

Replay shows the captured recipe name, source origin, working space, matrix, and original sample type. For a region-derived recipe, show **The saved region describes the original fit. It is not applied to these images.** A native disclosure exposes captured origin dimensions/region and method details using existing method disclosure patterns. An empty library shows **No saved transforms yet** and **Create a transform from a result, or import a transform in Methods. Close Batch to use that workflow. Analysis JSON cannot be replayed.** Missing, invalid, deleted, or unsupported recipes block Start with the actual reason. Never switch silently to calculation.

**Save results** follows method settings. One native format picker offers PNG (default), TIFF, JPEG. Show **Full source resolution** and, for PNG/TIFF, **Transparency preserved**. JPEG adds **JPEG is lossy and does not preserve transparency** and quality 94%, matching the existing exporter. **Include analysis JSON** is off by default and explains **One record beside each image, tied to its exact result.**

Destination is required. Show the selected parent folder's user-facing location and **Choose folder…** or **Change…**. A proposed run-folder disclosure must expose its full name, including the complete ownership UUID, without truncating the accessible value. The compact summary may truncate visually; details wrap anywhere. Start creates a fresh `KLT Batch <date-time> <UUID>` under that parent. The preview's date/UUID is illustrative; production must generate the actual fresh name. State **A new folder is created at Start. Existing files are never replaced.**

Setup also states **Temporary output files can appear in the selected run folder while saving. Cloud syncing is managed by your provider.** Source disclosure states **Each source is read when its turn begins, not when selected**, and exposes the platform's actual pixel/source/encoded-output/JSON/temporary-storage limits from the shared policy. Do not present estimated free space as reserved or verified when unavailable.

The footer summarizes selected count, format, JSON choice, and the primary **Start batch · N** action. On iPhone/iPad it visibly says **Keep KLT Image open in the foreground** before Start. Disabled Start always has nearby corrective text: add an eligible image, choose a valid method, choose a folder, wait for selection, or resolve insufficient temporary quota. Known failed entries can remain when at least one apparently eligible entry exists.

### Preparing, progress, and cancellation

Start freezes the ordered inputs, method snapshot and names, format, JSON setting, and destination. Setup controls are replaced with read-only context. During destination preparation show **Preparing output folder…**, zero settled, all entries queued, and Cancel. A start failure shows the destination error and every entry **Not processed**. No source has yet been acquired.

The progress view uses one dominant heading: **Acquiring / Processing / Saving image X of N**, the current filename, and a determinate bar for *settled items only*. Beneath it show **S of N settled**, successful/partial/failed counts, frozen mode/method, requested artifacts, selected parent, and actual run folder. No invented percentage for a provider, calculation, or encoder operation. Label each row's status in text.

**Cancel batch** is reachable throughout all phases. Acknowledge immediately as **Stopping…**, disable repeat stop actions, and explain **Waiting for the active operation and temporary-file cleanup. No more images will start.** Retain the surface while in-flight work and cleanup drain. A save already underway can finish. The settled outcome comes from actual committed artifacts, never from the UI's previous phase.

Closing an active surface offers **Keep processing** / **Stop and close**, explaining that committed output remains and the transient review will clear after stopping. The native window close/quit route uses the same drainage contract where the OS permits. Mac focus changes do not stop work. Mobile background initiates interruption; transient inactive states such as pickers do not. Neither platform offers pause/resume.

### Outcomes

Keep the frozen method, actual destination, format/JSON request, total input count, and six summary values: total, successful, partial, failed, canceled, not processed. Every input appears exactly once. Warning successes count as successful; partial rows do not. During an active run, pending entries are queued, so settled categories do not yet sum to total.

| Row state | Required content |
| --- | --- |
| Queued / Acquiring / Processing / Saving | Current state, ordinal, source name. No committed filename until it exists. |
| Saved | Actual image filename and actual JSON filename if requested and committed. |
| Saved with warning | Same filenames plus the existing core's exact warning; limited variation is not a failed image. |
| Partially saved | **Image saved; analysis JSON missing**, actual image filename, and the cancellation/write reason. Retain the complete image. |
| Failed | Specific actionable reason and **No output saved** when true. |
| Canceled | Active image had no committed artifact when cancellation settled. |
| Not processed | Untouched entry plus the run's stop reason. |

Headings are **Batch complete** only when every requested artifact for every input saved (including warning successes); **Finished with errors** for all-attempted mixed failures; **Batch canceled**; **Batch interrupted**; or **Stopped: [destination/storage/cleanup reason]**. Do not use a success-colored hero for mixed/partial/stopped runs.

An image-specific decode/validation/encoding failure continues to later entries. A shared destination error stops later work. The partial-JSON preview deliberately shows two successful pairs, one complete image with missing JSON, and three not-processed entries. Output rows display actual paired names after any collision renaming; never guess names from sources when showing receipts. Do not add output-opening, sharing, bulk retry, or filtering capabilities.

**Return to setup** is the one filled primary action after settlement. It retains current selections/choices, clears prior outcome data, and visibly says **Starting again processes all listed images into a new folder. Remove already handled entries before starting.** It saves nothing. A new explicit Start revalidates everything and creates a fresh run. A batch that left mobile foreground does not automatically continue.

### Temporary-output cleanup

Show a utility section above setup/outcomes only when unresolved external temporary reservations exist: **Temporary output needs cleanup**, reserved bytes and platform limit, **Select run folder…**, and **Select the associated KLT Batch folder to remove only KLT Image's unfinished temporary files. Saved images and other files stay in place.** This is housekeeping, not a recovered batch or history screen.

After relaunch the receipt cannot supply source names, output names, prior location, or run outcomes. Show only its permitted ownership identifier(s), wrapping the full UUID, under **Identify the folder**. Do not infer a date or parent from a receipt. A wrong folder yields **This is not the associated run folder. Nothing was removed. [N] remains reserved.** Canceling the picker retains debt with no cleanup. Verified cleanup/absence clears only its corresponding reservation and reports the released bytes. No “ignore,” reset-debt, delete-saved-output, recursive scan, or restore-batch action.

When debt still leaves sufficient quota, setup remains possible with that reservation counted. When the remaining quota cannot admit the next operation, block Start or stop the run with **Temporary storage limit reached. Clean up unfinished temporary output before starting again.** Corrupt/unreadable housekeeping state fails closed with an actionable error; never silently clear it. If matching identification was removed from a folder, explain that it cannot be verified and leave debt in place.

## Component Usage

Use existing `KLTColor`, `.plexSans`, `.plexMono`, primary/secondary button styles, native `Picker`, `Toggle`, `DisclosureGroup`, `List`/`LazyVStack`, `ProgressView`, alerts, and sheets. Use native system file/folder/Photos pickers as specified by the architecture. No third-party UI or motion library. The web preview approximates these controls using accessible native HTML and inline CSS/JS, with the existing bundled OFL font bytes embedded for offline rendering.

## Design Tokens Applied

Reuse `inkStrong #142A36`, `ink #304854`, `inkMuted #667B84`, `navy #193A4A`, `accent #007F92`, `accentPressed #006C7D`, `accentSoft #D9F0F3`, `surface #F7F9F9`, `surfaceRaised #FFFFFF`, `surfaceTint #EDF3F4`, `canvas #DBE3E5`, `divider #9FB1B8`, existing app `line #C9D4D8`, `success #18745F`, and `warning #A35F15`. The last two are accompanied by status text; warning is never used alone to encode failure.

Plex Sans: 20 pt bold view heading, 16 pt semibold section headings, 14–15 pt body on mobile / 12–14 pt on Mac, 10–11 pt tracked semibold compact labels. Plex Mono: 10–12 pt ordinals, filenames, dimensions, and identifiers. Scale with Dynamic Type; do not shrink essential copy to fit. Use 4/8/12/16/24/32-point spacing, 8-point controls, 12-point overlays, and cool one-pixel dividers. Fixed light toolbar/sheet appearance remains explicit, matching the shipped app's contrast policy.

## Interaction Notes

VoiceOver reads heading → source selection/list → mode and dependent controls → save choices/destination → Start. Progress announcements report phase/current item and settlement meaningfully without announcing every numerical tick. On transition to results, move accessibility focus to the outcome heading; Return to setup focuses the setup notice. Only controls in the chosen mode participate in reading/tab order. Native radio/picker semantics expose selection without color.

Mac keyboard users can select/add/remove sources, operate pickers/disclosures, start, cancel, and inspect all outcomes; Escape follows native close/stop confirmation, not silent loss. Mobile targets are at least 44 points. Full names/reasons wrap rather than requiring horizontal scrolling. At large accessibility sizes stack mode details, field pairs, summary counts, and footer buttons. Do not animate list renumbering into an ambiguous order. The preview is browser-tested evidence only; native VoiceOver, Dynamic Type, and lifecycle testing remain implementation QA.

## Motion Spec

- Mode-dependent form changes: ease-out, 180 ms opacity, local form origin, no spatial movement under Reduce Motion; SwiftUI `.easeOut`, CSS in preview.
- Progress settled-count update: ease-out, 180 ms bar-width change from leading edge; instant under Reduce Motion; native ProgressView/SwiftUI, CSS in preview. No per-operation animation implies progress.
- Native disclosure/popover: ease-out, 150–220 ms from its trigger; near-instant opacity under Reduce Motion; existing native presentation. Preview example-picker dialog uses 180 ms ease-out with a 4-pixel vertical change and top-trailing origin.
- Stopping/outcome replacement: ease-out, 180 ms local opacity only; near-instant under Reduce Motion; SwiftUI. Static initial layout has no entrance animation, pulse, bounce, or decorative stagger.

## Content Notes

Keep calculation and replay language explicit in setup, progress, and final outcome. Never call independent fits calibrated/color-matched; never call a replayed target region-sampled. “Successful” includes all requested artifacts, not just a rendered result. Cloud-provider write success does not mean synchronization completed. Only permanent outputs are named as saved; temporary reservations are labeled separately.

No design-system deviation, new scientific behavior, production-app edits, new export artifact, or persistent history is introduced.

## Design Verification

See `design-evidence/verification.md` for the verified tailnet-only HTTPS URL, browser checks, lint, and preview service ownership. The spec is complete under the authorized hands-off workflow; the HTML remains a starting point that can accommodate later feedback without implying native implementation validation.
