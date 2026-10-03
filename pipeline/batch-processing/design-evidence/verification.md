# Batch design verification

Verified 2026-10-03T07:01:44.382736+00:00.

## Review URL

https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-batch-review/

HTTPS returned **200**, `text/html`, using normal certificate validation. Served bytes exactly match `design.html`; SHA-256 `7bb1d8b4fc6f6bf1d52ca1efe6e0df5647d0b9ba084771ee01ee6c2c41df4f48`. Chromium loaded the actual HTTPS URL, not a local substitute.

## Checks and visual review

`weft-design-lint check pipeline/batch-processing/design.html`: clean, zero findings. The doctrine self-audit passes: embedded Plex display/body/label roles, existing tinted color tokens, one primary action, restrained background depth, continuous source/form layout, meaningful empty/error/working states, native-control direction, short local ease-out motion, anchored dialog origin, and Reduce Motion fallback. Selected-mode tint is the established active-scientific-state use of teal. No design-system deviations.

One browser pass checked defaults, empty/replay/destination start guards, recipe origin copy, JPEG notice, JSON toggle, all three responsive widths without horizontal overflow, selection, simulated start/cancel and stopping acknowledgment, actual canceled ordinal, return-to-setup notice, wrong-folder reservation retention, matching-folder cleanup, and reduced-motion transition removal. No page errors. Exact check list: `browser-checks.json`; verification source: `verify-preview.cjs`. The script uses an existing local Playwright installation as verification tooling only, with no application dependency added.

Visually reviewed `mac-setup.png`, `ipad-replay.png`, and `iphone-partial.png`. Text, controls, file names, counts, and partial-record explanation are legible and contained. The Mac view has a two-pane layout; iPad portrait stacks the form; phone outcomes stack status below names and preserve full filenames. Images were rendered from the live tailnet URL. This is browser design evidence; native SwiftUI, VoiceOver, Dynamic Type, actual provider writes, and lifecycle behavior require implementation QA. No physical device was inspected or used.

The in-app browser could not be opened because that browser surface was unavailable; the rendered screenshots and live URL remain the review delivery. No user approval wait is required under Autopilot.

## Persistent preview service

- Dedicated private asset root: `~/Library/Application Support/KLTImageReview/batch-processing` (0700 directory; 0600 files).
- Published files: self-contained `index.html` copied from `design.html`, plus the existing IBM Plex OFL license texts. No repository directory is served.
- User LaunchAgent: `~/Library/LaunchAgents/com.kltimage.batch-review.plist`; label `com.kltimage.batch-review`; RunAtLoad and KeepAlive; verified running with `launchctl print`.
- Command: `/opt/homebrew/bin/python3 -m http.server 18787 --bind 127.0.0.1 --directory <private asset root>`.
- Logs: `~/Library/Logs/kltimage-batch-review.log` and `kltimage-batch-review-error.log`.
- Local Tailscale Serve handler `/kltimage-batch-review` on HTTPS 443 proxies to loopback port 18787. Tailnet-only; no Funnel enabled.
- All preexisting Serve handlers were compared before/after and preserved, including `/kltimage-preview` and `/kltimage-rgb-review`. No peer/device enumeration was performed.
- Preview persists while the Mac, user service, and Tailscale are available. Its artifacts do not expire automatically. To update, replace only this private index with the scoped design HTML; no service restart is needed for file updates. Retiring this preview must affect only its handler, LaunchAgent, and private asset root.

Production source, project configuration, state transitions, telemetry, releases, and unrelated prior-run records were not changed.
