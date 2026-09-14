# Deployment Readiness — Custom Color Spaces and Reusable Transforms

**Prepared:** 2026-09-13

**Status:** READY FOR THE DESTRUCTIVE PRODUCTION GATE — nothing published

**Release:** KLT Image 1.3.0 build 6

**Feature commit:** `11e41f3a4a2ff5634a8b792f9f069f0f24f2e74c`

**Candidate/release commit:** `b4389bbbe6abfd61cbbeae1c20ef2f62137d6724`

## Candidate Identity

- ZIP: `/var/folders/qn/fzq2ymy1219bnchgrdvmcrdc0000gp/T/kltimage-release.3NIn82/KLT-Image-1.3.0-build-6.zip`
- Checksum: `/var/folders/qn/fzq2ymy1219bnchgrdvmcrdc0000gp/T/kltimage-release.3NIn82/KLT-Image-1.3.0-build-6.zip.sha256`
- SHA-256: `dbac952c70e1d05f38ec10af099577c4e082f089653eb6d37c33e05c4299c4f3`
- Size: 3,716,584 bytes
- Apple notarization submission: `95181528-af7d-4f68-bb00-10fb11ed09bf` — Accepted

The repository's mandatory `scripts/release-macos.sh` path built the candidate from release commit `b4389bbb`. It created only pending archive/checksum names until `scripts/verify-macos-release.sh` accepted the pending archive, then atomically promoted both to the final local names above as allowed by the existing release policy. A separate verifier rerun on the final ZIP accepted the same SHA-256.

## Pre-Deploy Reconciliation

- `origin/main` was fetched repeatedly and remained `2d18804d69ec00fcd7ca7c367ec975eb7e35eaf7`, with no remote-only commit or conflict. The prepared local line is ahead only by the scoped feature, release-preparation, and readiness-record commits.
- The previously dirty tracked and untracked source matched the active feature recorded in `pipeline/session-state.json` and the approved strategic brief/PRD. No unrelated user edit was found or overwritten.
- `.derived-data/`, `.build-*`, `.qa-*`, XCTest result bundles, notarization transport files, and ignored QA/security working reports were excluded from the commits. `.derived-data/` is now explicitly ignored to keep generated test evidence out of source history.
- There is no staging environment and no GitHub Actions workflow. The configured CI/CD equivalent is the manual signed/notarized release path plus independent verification.
- The existing tailnet-only Tailscale Serve route is unchanged: `/kltimage-preview` still proxies to `127.0.0.1:8786`. The public GitHub and tailnet Build 5 objects remain the current advertised production release.

## Verification Evidence

- Tester: **PASSED — 37 Pass, 1 Partial, 0 Fail**. The sole partial is unavailable native Intel-hardware execution; universal x86_64 compilation and Rosetta/x86_64 non-UI execution passed. The authoritative final UI run passed 6/6.
- Auditor: **PASSED — 0 Critical, 0 High, 0 Medium, 0 Low, 0 Informational findings**.
- Fresh Deployer non-UI Debug rerun: 60/60 `KLTCoreTests` and 18/18 `KLTImageTests` passed before the redundant full-scheme/UI run was intentionally stopped at the Orchestrator's direction.
- Fresh Deployer optimized `ReleaseTests`: 80/80 passed. All measured 24 MP paths remained below five seconds; the 64 MP replay memory guard and 500-item library-load guard passed.
- Fresh universal Release `xcodebuild analyze`: succeeded for arm64 and x86_64 with no analyzer failure.
- `xcodegen` regeneration, release build settings, `git diff --check`, script syntax, entitlement plist validation, targeted secret scan, and the release promotion self-test passed. The Deployer host lacked `weft-design-lint`; the authoritative QA run already records the design artifact at 0 findings.
- `scripts/release-macos.sh` verified exactly arm64+x86_64 app/framework binaries; 1.3.0/6 bundle versions; pinned Developer ID identity and Team ID; secure timestamps; hardened runtime; framework-first signing; exactly sandbox plus user-selected read/write app entitlements; no framework entitlement and no `get-task-allow`; Apple acceptance; stapling; checksum; quarantine; and Gatekeeper `source=Notarized Developer ID`.
- `scripts/verify-macos-release.sh` independently accepted the pending archive inside the release script and accepted the final archive again in a separate invocation.

## Production Gate Scope

Explicit production confirmation authorizes all and only these publication actions:

1. Push the prepared feature, release, and readiness commits on `main`; create and push annotated tag `v1.3.0` at candidate commit `b4389bbbe6abfd61cbbeae1c20ef2f62137d6724`.
2. Create the public GitHub Release `v1.3.0` targeting that tag, using the 1.3.0 release notes in `PR_DESCRIPTION.md`, and upload the exact verified ZIP plus its matching checksum file.
3. Copy the same two verified files through pending names into the existing tailnet-only mirror under `/kltimage-preview/releases/`, atomically promote them to `KLT-Image-1.3.0-build-6.zip` and `.zip.sha256`, and do not alter the Tailscale route.
4. Fresh-download both served ZIPs, require SHA-256 `dbac952c70e1d05f38ec10af099577c4e082f089653eb6d37c33e05c4299c4f3`, and independently verify both. Only after both channels pass, update `README.md`, `HOW_TO_RUN.md`, `PR_DESCRIPTION.md`, `releases/index.html`, `pipeline.config.json`, and the deployment record to advertise 1.3.0 build 6; commit and push that deployment metadata.

No local tag, push, GitHub Release, hosted Build 6 file, advertised URL, or Tailscale configuration change is authorized before that confirmation.

## Exact Rollback

Trusted KLT Image 1.2.0 build 5 remains the rollback release at SHA-256 `66883ef34f22043bbf74b51e76648ad62527ac47be6fb9c28f33fee2e89ae3aa`.

If Build 6 fails production verification or a critical defect is found:

1. Stop advertising Build 6 and restore every download/current-release reference to the existing Build 5 GitHub and tailnet URLs and checksum.
2. Delete only the GitHub Release `v1.3.0` and its Build 6 assets; delete the remote/local `v1.3.0` tag if the release is being retracted.
3. Remove only `releases/KLT-Image-1.3.0-build-6.zip` and its checksum from the tailnet mirror. Leave Build 5 bytes, the local server, and the Tailscale Serve route unchanged.
4. Fresh-download Build 5 from both channels, require its recorded SHA-256, run the independent verifier, and confirm Gatekeeper acceptance before declaring rollback complete.
5. Record and push a rollback metadata commit. Revert the feature/release source commits only if the defect also requires `main` source rollback; use new revert commits rather than rewriting published history.

Already-downloaded Build 6 copies cannot be recalled.
