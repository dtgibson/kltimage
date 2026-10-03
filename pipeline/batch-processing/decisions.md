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

## Preserve exact pixels while correcting full-frame memory retention

QA's full-resolution run exposed growing dirty raster-buffer retention. The accepted correction gives decoded and rendered buffers explicit checked ownership while preserving the existing thumbnail decoder, orientation/color conversion, alpha and numerical operations. A proposed direct-decoder replacement was rejected because it changed exact pixels. The final 384-case decode comparison and independent 3+100-image, 24 MP run passed. Framework virtual reservations remain; neither a universal peak-memory bound nor a generic framework root cause is claimed.

## Approved publication and retained limits

The user selected the final publication option for both reviewed channels with the disclosed verification limits. Mac 1.4.0 (10) is published at https://github.com/dtgibson/kltimage/releases/tag/v1.4.0 ; its source tag remains `538dc9cc81604e5b4097896415e6afcca232e209`, and the fresh public download passed the independent release verifier. iOS 1.1 (3), exact build `d415823a-cc95-4129-a7a0-84648411882c`, is VALID with `usesNonExemptEncryption=false` and IN_BETA_TESTING in the existing KLT Image Internal group, still one tester. Prior builds remain available; installation of build 3 is unverified.

Scoped QA passed and no security vulnerability was identified. Mac native UI/keyboard/VoiceOver/lifecycle automation remains environment-blocked; native <=1-second Cancel acknowledgment is inconclusive; real cloud providers, all external crash/cleanup windows and physical-device behavior remain unverified. Delivery does not close these gaps. Exact publication evidence and existing-credential recovery are retained in `publication-plan.md` and `deployment-evidence/`; no repeat upload or new key was needed.
