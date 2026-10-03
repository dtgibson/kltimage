# KLT Image 1.4.0 — Batch processing

Process up to 100 photographs in one foreground run. Choose **Calculate each image** for fresh whole-image statistics, or **Replay saved transform** to apply the same captured mathematics unchanged to every image.

- Review your inputs, method, destination and output choices before starting.
- Save full-resolution PNG, TIFF or JPEG files into a new run folder. PNG is the default; matching analysis JSON is optional and off by default.
- See a separate outcome for every input, including failed, canceled and partially saved items. Existing files and source photographs are preserved.
- Process one full-resolution image at a time. This release also corrects growing raster-buffer retention while preserving the existing image decoding, scientific calculations and analysis JSON formats.

The same batch workflow is available for iPhone and iPad in iOS 1.1 (3) through the existing KLT Image Internal TestFlight group. Apple has processed the build and confirmed internal availability; installation remains unverified. No public App Store release occurred. This Mac download requires macOS 14 or later and supports Apple silicon and Intel Macs. The mobile build requires iOS/iPadOS 18 or later.

Batch processing is an active-app workflow. Keep the app in the foreground on iPhone and iPad; an interrupted run does not resume automatically. Independently calculated images do not establish quantitative color comparability. A cloud destination's synchronization remains controlled by its provider.

## Verification limits

Controlled regression, numerical parity and long-run resource checks passed. Mac native UI automation, keyboard, VoiceOver and close/quit lifecycle checks remain blocked by the development environment. Native acknowledgment of Cancel within one second is inconclusive. Real cloud-provider behavior, every external crash/cleanup window, physical-device behavior and installation of this TestFlight build remain unverified. Simulator and packaging results do not establish those checks.

The Mac ZIP is universal, Developer ID signed, hardened, notarized, stapled and independently verified with quarantine and Gatekeeper. SHA-256: `a67fc50bdd60fd2ea8ba4621316a67f51a42cd475d23616ca4d34b69d42206d4`.
