#!/usr/bin/env python3
"""Independent retained-package checks; never changes source or release packages."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import plistlib
import subprocess
import tempfile

out = Path(__file__).resolve().parent
root = out.parents[2]
env = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer")
base = "383756798707e651e5363a5babfdd20c5ecabdbb"
team = "8QKC3L2FKP"  # Existing release scripts and prior iOS deployment record.

def run(args):
    return subprocess.run(args, cwd=root, env=env, capture_output=True, check=False)

def ok(args):
    result = run(args)
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {args[0:2]}: {result.stderr.decode(errors='replace')}")
    return result

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

result = {"base": base, "scriptChanges": {}, "packages": {}, "ios": {}}
for name in ["scripts/release-macos.sh", "scripts/verify-macos-release.sh"]:
    prior = ok(["git", "show", f"{base}:{name}"]).stdout.decode()
    expected = prior.replace('readonly EXPECTED_VERSION="1.3.3"', 'readonly EXPECTED_VERSION="1.4.0"')
    expected = expected.replace('readonly EXPECTED_BUILD="9"', 'readonly EXPECTED_BUILD="10"')
    expected = expected.replace("KLT-Image-1.3.3-build-9.zip", "KLT-Image-1.4.0-build-10.zip")
    assert (root / name).read_text() == expected, "Unexpected release trust logic change"
    result["scriptChanges"][name] = {"onlyVersionBuildAndUsageFilenameChanged": True, "sha256": sha(root / name)}

mac = root / "releases/KLT-Image-1.4.0-build-10.zip"
ipa = root / ".derived-data/batch-release/KLTImageIOS-1.1-3-TestFlight-export/KLT Image.ipa"
for name, path, expected in [
    ("mac", mac, "a67fc50bdd60fd2ea8ba4621316a67f51a42cd475d23616ca4d34b69d42206d4"),
    ("ios", ipa, "c43064e35815481ffe521b173e764de585edc6ec8873e00d9563d322d4525a4b"),
]:
    actual = sha(path)
    assert actual == expected, f"Package hash mismatch: {name}"
    result["packages"][name] = {"path": str(path), "sha256": actual, "bytes": path.stat().st_size}
assert mac.with_suffix(".zip.sha256").read_text().split()[0] == result["packages"]["mac"]["sha256"]
verification = run([str(root / "scripts/verify-macos-release.sh"), str(mac), result["packages"]["mac"]["sha256"]])
(out / "distribution-mac-verifier.log").write_bytes(verification.stdout + verification.stderr)
result["macVerifierExit"] = verification.returncode
assert verification.returncode == 0, "Mac independent verifier rejected retained ZIP; see log"

export_options = plistlib.loads((ipa.parent / "ExportOptions.plist").read_bytes())
assert export_options["method"] == "app-store-connect"
assert export_options["signingCertificate"] == "Apple Distribution" and export_options["teamID"] == team
tokens = ["BatchTestFaults", "testFaults", "BATCH_QA_MEMORY", "testQAFullResolutionShortAndHundredItemMemory", "KLT_UI_TEST"]
with tempfile.TemporaryDirectory(prefix="klt-batch-independent-ipa-") as temporary:
    extracted = Path(temporary)
    ok(["/usr/bin/ditto", "-x", "-k", str(ipa), str(extracted)])
    app = extracted / "Payload/KLT Image.app"
    framework = app / "Frameworks/KLTCore.framework"
    info = plistlib.loads((app / "Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == "com.kltimage.ios"
    assert info["CFBundleShortVersionString"] == "1.1" and info["CFBundleVersion"] == "3"
    assert info["MinimumOSVersion"] == "18.0" and info["UIDeviceFamily"] == [1, 2]
    result["ios"]["appInfo"] = {key: info[key] for key in ["CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion", "UIDeviceFamily"]}
    for name, bundle, identifier, executable in [
        ("app", app, "com.kltimage.ios", app / info["CFBundleExecutable"]),
        ("framework", framework, "com.kltimage.ios.core", framework / "KLTCore"),
    ]:
        checked = ok(["/usr/bin/codesign", "--verify", "--strict", "--verbose=2", str(bundle)])
        metadata = ok(["/usr/bin/codesign", "-dvvv", str(bundle)]).stderr.decode()
        fields = [line for line in metadata.splitlines() if line.startswith(("Identifier=", "Authority=", "TeamIdentifier="))]
        assert f"Identifier={identifier}" in fields and f"TeamIdentifier={team}" in fields
        assert any(line.startswith("Authority=Apple Distribution:") and line.endswith(f"({team})") for line in fields)
        architectures = ok(["/usr/bin/lipo", "-archs", str(executable)]).stdout.decode().strip()
        assert architectures == "arm64"
        ent = ok(["/usr/bin/codesign", "-d", "--entitlements", ":-", str(bundle)]).stdout
        entitlements = plistlib.loads(ent) if ent.strip() else {}
        assert entitlements.get("get-task-allow", False) is False
        data = executable.read_bytes()
        marker_matches = [token for token in tokens if token.encode() in data]
        assert not marker_matches
        result["ios"][name] = {"strictSignatureValid": True, "signing": fields, "architectures": architectures,
                                "binarySHA256": hashlib.sha256(data).hexdigest(), "entitlementKeys": sorted(entitlements),
                                "getTaskAllow": entitlements.get("get-task-allow"), "debugMarkerMatches": marker_matches}
        if name == "app":
            assert entitlements["get-task-allow"] is False
            assert entitlements["application-identifier"] == f"{team}.com.kltimage.ios"
            assert entitlements["com.apple.developer.team-identifier"] == team
            assert entitlements["beta-reports-active"] is True
            result["ios"]["app"]["applicationIdentifier"] = entitlements["application-identifier"]
        else:
            assert not entitlements
            framework_info = plistlib.loads((framework / "Info.plist").read_bytes())
            assert framework_info["CFBundleShortVersionString"] == "1.1"
            result["ios"]["framework"]["version"] = framework_info["CFBundleShortVersionString"]
    ok(["/usr/bin/codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app)])
    # Decode only in memory; never store or print certificates/profile payloads.
    profile = plistlib.loads(ok(["/usr/bin/security", "cms", "-D", "-i", str(app / "embedded.mobileprovision")]).stdout)
    pe = profile["Entitlements"]
    assert profile["TeamIdentifier"] == [team]
    assert pe["application-identifier"] == f"{team}.com.kltimage.ios"
    assert pe["get-task-allow"] is False and pe["beta-reports-active"] is True
    assert "ProvisionedDevices" not in profile and not profile.get("ProvisionsAllDevices", False)
    assert profile["ExpirationDate"] > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
    result["ios"]["profile"] = {"team": profile["TeamIdentifier"], "applicationIdentifier": pe["application-identifier"],
        "getTaskAllow": pe["get-task-allow"], "betaReportsActive": pe["beta-reports-active"],
        "deviceListAbsent": True, "allDevicesAbsentOrFalse": True, "expiry": profile["ExpirationDate"].isoformat(),
        "type": "App Store distribution; consistent with app-store-connect export"}

archive_info = plistlib.loads((root / ".derived-data/batch-release/KLTImageIOS-1.1-3.xcarchive/Info.plist").read_bytes())["ApplicationProperties"]
assert archive_info["CFBundleIdentifier"] == "com.kltimage.ios"
assert archive_info["CFBundleShortVersionString"] == "1.1" and archive_info["CFBundleVersion"] == "3"
result["ios"]["archiveMetadataMatches"] = True
assert sha(mac) == result["packages"]["mac"]["sha256"] and sha(ipa) == result["packages"]["ios"]["sha256"]
result["packagesUnchangedAfterChecks"] = True
result["uploadedOrPublished"] = False
(out / "distribution-audit.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
