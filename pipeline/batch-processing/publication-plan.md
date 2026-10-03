# Publication plan — Batch processing

**Status: both approved channels published and verified.** The commands below preserve the approved execution plan for audit. Do not repeat completed push, tag, release or upload operations. The user selected the final publication option covering both channels and the documented acceptance limits.

## Reviewed bytes and cargo

Source commit: `538dc9cc81604e5b4097896415e6afcca232e209` (`Add batch processing on Mac, iPhone and iPad`). It contains this feature, its tests/evidence and version-only release preparation. No prior unpushed behavior cargo exists. Any later deployment documentation-only commit is record keeping. The source tag remains pinned to this source commit even if documentation is committed later.

- Mac: `releases/KLT-Image-1.4.0-build-10.zip`; SHA-256 `a67fc50bdd60fd2ea8ba4621316a67f51a42cd475d23616ca4d34b69d42206d4`.
- iOS: `.derived-data/batch-release/KLTImageIOS-1.1-3-TestFlight-export/KLT Image.ipa`; SHA-256 `c43064e35815481ffe521b173e764de585edc6ec8873e00d9563d322d4525a4b`.
- Review: https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-batch-review/release-candidate/

## Reconcile immediately before execution

```sh
git fetch origin main
git log --oneline HEAD..origin/main
git log --oneline origin/main..HEAD
git ls-remote --tags origin refs/tags/v1.4.0
python3 .derived-data/batch-release/asc-release.py preflight
shasum -a 256 releases/KLT-Image-1.4.0-build-10.zip '.derived-data/batch-release/KLTImageIOS-1.1-3-TestFlight-export/KLT Image.ipa'
```

The preflight helper uses the established environment credentials and reads App Store Connect only in `preflight` mode. It asserts iOS 1.1 (3) is unused and records the existing group and build state. Stop if upstream moved, unapproved app-behavior cargo appeared, a version collides or either hash differs. Integrate/reverify and refresh approval for any newly introduced behavior; never rebuild and silently replace reviewed bytes.

## Approved Mac publication

```sh
git tag -a v1.4.0 538dc9cc81604e5b4097896415e6afcca232e209 -m 'KLT Image 1.4.0 (10)'
git push --atomic origin main refs/tags/v1.4.0
gh release create v1.4.0 releases/KLT-Image-1.4.0-build-10.zip releases/KLT-Image-1.4.0-build-10.zip.sha256 --repo dtgibson/kltimage --verify-tag --title 'KLT Image 1.4.0 — Batch processing' --notes-file pipeline/batch-processing/release-notes.md --latest
mkdir -p .derived-data/batch-release/github-download
gh release download v1.4.0 --repo dtgibson/kltimage --pattern 'KLT-Image-1.4.0-build-10.zip*' --dir .derived-data/batch-release/github-download
scripts/verify-macos-release.sh .derived-data/batch-release/github-download/KLT-Image-1.4.0-build-10.zip a67fc50bdd60fd2ea8ba4621316a67f51a42cd475d23616ca4d34b69d42206d4
cmp releases/KLT-Image-1.4.0-build-10.zip.sha256 .derived-data/batch-release/github-download/KLT-Image-1.4.0-build-10.zip.sha256
```

Expected release URL: https://github.com/dtgibson/kltimage/releases/tag/v1.4.0

Expected canonical ZIP: https://github.com/dtgibson/kltimage/releases/download/v1.4.0/KLT-Image-1.4.0-build-10.zip

Only after fresh-download verification succeeds, update `pipeline.config.json`, README, HOW_TO_RUN, PR_DESCRIPTION and `releases/index.html` to advertise the new Mac version. Preserve the previous release and its bytes. No production links have been updated during preparation.

## Approved iOS TestFlight delivery

```sh
API_PRIVATE_KEYS_DIR="$(dirname "$APPLE_API_KEY_PATH")" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun altool --upload-app --type ios --file '.derived-data/batch-release/KLTImageIOS-1.1-3-TestFlight-export/KLT Image.ipa' --apiKey "$APPLE_API_KEY_ID" --apiIssuer "$APPLE_API_ISSUER_ID" > .derived-data/batch-release/ios-upload.log 2>&1
python3 .derived-data/batch-release/asc-release.py status
```

Wait for the exact 1.1 (3) build to become `VALID`. A successful upload is not processing, internal availability or installation proof. Then, with the same approved TestFlight scope:

```sh
python3 .derived-data/batch-release/asc-release.py attach
python3 .derived-data/batch-release/asc-release.py status
```

`attach` sets `usesNonExemptEncryption=false` if absent and associates only 1.1 (3) with the existing **KLT Image Internal** group (`ac0dc0c0-f8ae-4813-bae7-4af4ac313509`). The security review confirms no new cryptographic/network surface; existing cryptography is local SHA-256 provenance. No tester invitation, deletion or change is required. Readback must show `VALID`, `IN_BETA_TESTING`, association with the existing group and the unchanged one-tester count. The prior run's delivery credential received 403 on metadata mutation; if repeated, use the already configured alternate credential through a process-local environment override. The established loader selects the sole `AuthKey_*.p8` under `~/.appstoreconnect/private_keys` whose basename differs from the active `APPLE_API_KEY_PATH`, asserts exactly one match, sets the subprocess's `APPLE_API_KEY_PATH` to that path and `APPLE_API_KEY_ID` to its `AuthKey_` filename stem, and retains the existing issuer. It never prints or changes credential values or global shell configuration. Do not print credentials, create replacement keys or re-upload an accepted build to fix metadata permissions.

Management URL: https://appstoreconnect.apple.com/apps/6818412230/testflight/ios . Update iOS release metadata only after processing and group association are verified. Physical-device and installation verification remain exclusively the user/testers' work; never enumerate or access devices. No public App Store submission is part of this plan.

## Recovery

Before publication, preparation changed no live release. Previous Mac 1.3.3 (9), SHA-256 `98cd1404efceebcf4282b78b774e1cb9fed30e4f208f5aa7c085eb1a1739ece1`, remains available and is the immediate prior source/behavior baseline. Configured trusted rollback 1.3.2 (8), SHA-256 `3730547ba9ca115544a83f90ffe1a7342a8624af25054d434f74967393a37f1e`, is preserved. If postpublication health fails, stop advertising the candidate and restore the appropriate trusted release under the orchestrator's rollback procedure. Do not delete historical assets or remove quarantine. Retain TestFlight 1.0 (2) and its group association; do not alter existing testers if 1.1 (3) is unsuitable.


## Verified execution

The user approved the final publication option. The coordinator pushed the reviewed source and tag, published Mac 1.4.0 (10) at **2026-10-03T15:02:12Z**, and independently verified the freshly downloaded public ZIP and checksum before advertised links changed. Source tag v1.4.0 remains pinned to `538dc9cc81604e5b4097896415e6afcca232e209`; the artifact hash is unchanged.

The coordinator uploaded the exact iOS 1.1 (3) IPA once at **2026-10-03T15:05:01Z**, delivery/build ID `d415823a-cc95-4129-a7a0-84648411882c`. Fresh readback confirms VALID, non-exempt encryption false, IN_BETA_TESTING and association with the existing **KLT Image Internal** group, still one tester. The initial delivery credential received a metadata-only 403; the established alternate credential applied the declaration and association through a process-local override. No key, tester or global credential setting changed, and no repeat upload occurred.

Evidence is in `deployment-evidence/mac-publication.json`, `macos-public-verifier.log`, `ios-publication.json`, `ios-upload.log` and `ios-testflight-readback.json`. Old releases and TestFlight builds are preserved. Native UI/provider/crash-window/Cancel timing and physical-device/TestFlight installation limits remain unchanged. The commands above are retained execution history, not outstanding work.
