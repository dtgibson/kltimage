# Batch Processing Decisions

## User-confirmed scope

- New Feature, Autopilot, with questions when consequential requirements need user judgment.
- Offer both independent per-image calculation and exact saved-transform replay, selected per batch.
- First release covers Mac, iPhone, and iPad.

## External temporary-file cleanup feasibility

During architecture review, native provider permissions exposed a conflict in the initial cleanup promise: after termination or grant loss, the app cannot clean destination-local staging without renewed user permission, while persistent bookmarks are forbidden. The Planner made a scoped correction to FR-24, FR-27, NFR-05, QA-20, and QA-23.

Private temporary files are cleaned on relaunch. External temporary outputs are cleaned while access is valid or after explicit user reselect of the associated run folder. Minimal private, backup-excluded receipts retain random ownership tokens, random temporary basenames, and byte reservations only, preventing a crash/relaunch from bypassing the temporary-storage bound. Receipts contain no paths, source identities, methods, outputs, queue, or outcome history and confer no access. This feasibility clarification was resolved within Autopilot; no new background access or persistent user workspace was introduced.

## QA correction round 1

Independent QA found undersized/truncated mobile actions and raw provider paths in destination labels. The correction stays within the approved design and requirements. Autopilot permits a focused Engineer revision without a routine approval gate. Add meaningful high-risk coverage while preserving passed scientific/core behavior. QA attempt1 was recorded; server routing returned retry, max3.
