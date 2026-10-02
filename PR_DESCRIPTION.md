## RGB fidelity and extended zoom

Existing Mac, iPhone and iPad zoom buttons and pinch now share a 1000% fit-relative ceiling. The source, scientific transforms, interpolation and full-resolution export behavior are preserved. Added regression checks cover dimensions, scalar pixel mapping, orientation, alpha and zoom geometry. Investigation reproduced RGB blocks in a supplied compressed JPEG’s lossless exports, with evidence of amplified source chroma structure; this release does not remove JPEG artifacts.

Mac Debug and optimized core/app suites, local iPhone/iPad zoom controls and the performance requirement passed. Native Mac controls, maximum-zoom registration and gesture ownership, comparison-mode transitions and matched native screen/export detail remain unverified. Publication was explicitly approved with these gaps; no physical-device acceptance is claimed.

Mac 1.3.3 (9) is published at https://github.com/dtgibson/kltimage/releases/tag/v1.3.3. Its fresh download is byte-identical to the approved universal ZIP and independently passes Developer ID signature, notarization, stapling, checksum, quarantine and Gatekeeper verification. Mac 1.3.2 (8) remains the rollback release. iOS 1.0 (2) passed Apple validation, was uploaded and processed as VALID, and is IN_BETA_TESTING in the existing internal group with one unchanged tester. New-build installation remains unverified.
