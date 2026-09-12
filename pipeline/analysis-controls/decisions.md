# Analysis Controls Decisions

## Accept residual verification risk for a private, local-only release — 2026-09-11

**Decision:** Proceed from The Tester to The Auditor with the QA result recorded as accepted with residual risk, not as a full pass.

**Rationale:** No known product defect remains. The immutable shipped baseline, Debug and Release core suites, all eight 24-megapixel performance cases, universal builds, Release analysis, and the repaired accessibility and region workflows have positive evidence. The remaining Partial criteria require broader automated matrices or environments unavailable in this bounded run, including a reliable UI worker, an actual VoiceOver-operated pass, Intel hardware, macOS 14 runtime testing, and dynamic privacy checks.

**Implications:** The release remains appropriate only for private, local use. The QA report's 22 Partial criteria remain open evidence debt and must not be represented as fully verified. Close those items before broad public distribution; The Auditor and The Deployer must carry the limitations forward.

## Replace the 2 GB allocation ceiling with a 64 MP pre-decode policy — 2026-09-11

**Decision:** Keep the interactive full-frame pipeline and support images up to 64,000,000 pixels. Validate declared dimensions before requesting a full-resolution ImageIO decode, then validate the decoder's actual dimensions again before allocating the app-owned RGBA buffer. Do not expand the limit from live free-memory readings.

**Rationale:** The former 2,000,000,000-byte single-buffer guard allowed about 500 megapixels, was applied only after full decoding began, and had no documented hardware or product basis. At 64 megapixels, one RGBA frame is 256 MB; a conservative allowance for five frame-sized source, result, decoder, flattening, and encoding allocations is about 1.28 GB. This covers common cameras through approximately 61 megapixels, gives 2.7 times the verified 24-megapixel product target, and retains headroom on the lowest-memory supported Mac class.

**Implications:** Inputs above 64 megapixels now fail with a specific, readable import error before full-frame decoding. Supporting larger panoramas or scientific imagery requires a separately designed tiled or out-of-core processing path. The Engineer must add the policy and boundary tests; The Tester must rerun affected verification; The Auditor must confirm the finding is resolved before deployment.

## Publish a private tailnet-only package — 2026-09-11 23:33 PDT (2026-09-12 06:33 UTC)

**Decision:** Deploy KLT Image 1.1.0 build 3 as a private, tailnet-only ZIP at `https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-preview/releases/KLT-Image-1.1.0-build-3.zip`. The published file is 1,573,020 bytes with SHA-256 `011ad363f46f9b9d81a6be3aeb936de1f692ed19fcc63e2ad0ba0207c353db7a`.

**Verification:** Local and tailnet download checks returned HTTP 200 with the expected ZIP type and size; the tailnet download matched the published checksum and passed ZIP integrity and strict nested signature validation. The app and embedded framework are universal `x86_64 arm64`, the app reports version 1.1.0 build 3 with a macOS 14 minimum, and its entitlements contain only App Sandbox and user-selected read/write file access, with no `get-task-allow`.

**Implications:** Availability depends on the existing local Python server on `127.0.0.1:8786`, the existing Tailscale Serve route, and the host remaining connected. Deployment made no commit, push, tag, GitHub release, server restart, or Tailscale configuration change. The ad-hoc, unnotarized package and the 22 accepted QA Partial criteria remain approved only for private/local use, not broad public distribution.

**Rollback:** Remove only `/Users/developer/devwork/kltimage/releases/KLT-Image-1.1.0-build-3.zip` from the served project; previously downloaded copies cannot be recalled.
