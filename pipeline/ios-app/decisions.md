# KLT Image iOS Decisions

## Make pinch zoom explicit on both device sizes — 2026-10-01

**Decision:** The iPhone and iPad image canvas supports two-finger pinch zoom and panning while zoomed, with Fit and accessible zoom controls. The original, enhanced image, and sample rectangle use one viewport transform. Slider and region-edit gestures retain their own ownership.

**Reason:** The user approved the overall design and asked for pinch zoom because the phone and iPad screens provide less room than the Mac display.

**Implication:** Zoom changes only the view. It never changes source pixels, sample coordinates, the analysis record, or exports. The design preview, implementation, and device checks must demonstrate this on both form factors.

## Bound encoded iOS image imports — 2026-10-01

**Decision:** Files and Photos imports on iOS stage at most 256 MiB of encoded source data through a counted copy before decode, in addition to the fixed 26-million-pixel oriented limit. Temporary staging files are removed on error or cancellation and recovered after an interrupted import.

**Reason:** The security review found that copying an unrestricted provider file could exhaust local storage and leave source data in temporary storage. A 26-million-pixel 16-bit RGBA TIFF is about 198 MiB before ordinary metadata, so 256 MiB supports that common upper case while placing a deterministic bound on staging.

**Implication:** An unusually large encoded image under 26 million pixels, such as some 32-bit RGBA TIFF files, is rejected with a clear error. The byte and pixel limits need full-workflow checks on the lowest-memory supported iPhone and iPad before release; lower or revise the fixed limits only with documented device evidence.
