## Batch processing

### What this does
Adds native foreground batch processing on Mac, iPhone, and iPad. Users select up to 100 images, calculate each independently or replay one saved transform unchanged, then save full-resolution images and optional compatible analysis JSON into a fresh explicitly selected folder. Sequential bounded acquisition and exclusive publication preserve original files and accurately report partial, canceled, failed, and successful outcomes.

### How to test
Open Batch from the Mac header or mobile workspace action menu. Select images and a destination; verify defaults and both mode choices, then run with and without JSON. Exercise duplicate names, corrupt inputs, cancel during acquisition/saving, return to setup, background interruption on local simulators, and cleanup-folder reselect. Confirm the interactive workspace remains unchanged. Run the shared BatchProcessingTests in both app targets and the existing required regression suites.

### Notes for reviewer
KLTCore mathematics and JSON schemas/goldens are unchanged. Review the bounded ImageIO sink, descriptor-relative exclusive publisher, receipt-before-stage storage policy, commit/cancel ordering, lazy Photos callback lifetime, and guarded workspace setters. Current native acceptance and full regression requirements remain with independent QA; see implementation-record.md for exact passing checks and the current-head Mac test-host startup limitation. No release was published.
