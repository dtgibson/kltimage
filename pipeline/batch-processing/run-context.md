# Batch processing run context

- User selected New Feature, then batch processing from the roadmap.
- Execution mode: Autopilot. User explicitly added: "but ask me if you have any questions". Ask for consequential missing requirements; do not require routine stage approvals.
- Feature lane, 9 stages. Production release remains a final explicit approval after concrete candidates and verification are ready.
- Current project covers Mac, iPhone, and iPad; platform scope for this batch feature is all three platforms.
- Preserve scientific meaning: image-specific calculation and frozen-transform replay are different operations.
- No physical-device access, inspection, installation, control, or testing under any circumstances. Use this development Mac and local simulators. iOS release through TestFlight.
- Development previews and design reviews must use verified tailnet-only HTTPS Tailscale links, not local filesystem/localhost links.
- Preserve existing untracked prior-run records and unrelated edits.

## Confirmed processing choice

User: "Please build both, and give the user the option to choose." Each batch must offer separate per-image transform calculation or unchanged replay of one saved transform. User then confirmed: "all platforms please". First release covers Mac, iPhone, and iPad.

## Confirmed platform scope

Mac, iPhone, and iPad. User explicitly requested all platforms for the first release.
