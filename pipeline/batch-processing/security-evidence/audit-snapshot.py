#!/usr/bin/env python3
"""Read-only code/binary checks. Writes only security review evidence beside this script."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess

out = Path(__file__).resolve().parent
root = out.parents[2]
base = "383756798707e651e5363a5babfdd20c5ecabdbb"
env = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer")

def command(args):
    result = subprocess.run(args, cwd=root, env=env, text=True, capture_output=True, check=False)
    return {"command": args, "exit": result.returncode, "stdout": result.stdout, "stderr": result.stderr}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

scope = Path.home() / ".weft/bin/weft-scope"
classify = command([str(scope), "classify"])
scan = command([str(scope), "scan"])
(out / "scope.txt").write_text(classify["stdout"] + classify["stderr"])
(out / "scan.txt").write_text(scan["stdout"] + scan["stderr"])
sources = [line.split(" ", 2)[2] for line in classify["stdout"].splitlines() if line.startswith("FILE ")]
snapshot = {"base": base, "scopeExit": classify["exit"], "scanExit": scan["exit"],
            "sources": {name: sha(root / name) for name in sources}, "releaseBinaries": {}}
tokens = ["BatchTestFaults", "testFaults", "BATCH_QA_MEMORY", "testQAFullResolutionShortAndHundredItemMemory",
          "KLT_UI_TEST_METHOD_LIBRARY_PATH", "KLT_UI_TEST_LARGER_TEXT"]
binaries = {
    "mac": Path("/tmp/klt-batch-retry-release-mac/Build/Products/Release/KLT Image.app/Contents/MacOS/KLT Image"),
    "iosSimulator": Path("/tmp/klt-batch-retry-release-ios/Build/Products/Release-iphonesimulator/KLT Image.app/KLT Image"),
}
for platform, binary in binaries.items():
    data = binary.read_bytes()
    symbols = command(["/usr/bin/xcrun", "nm", str(binary)])
    matches = [line for line in symbols["stdout"].splitlines() if any(token in line for token in tokens)]
    snapshot["releaseBinaries"][platform] = {
        "path": str(binary), "sha256": hashlib.sha256(data).hexdigest(), "nmExit": symbols["exit"],
        "nmError": symbols["stderr"], "matchingSymbols": matches,
        "matchingBytes": [token for token in tokens if token.encode() in data],
    }
prior = json.loads((root / "pipeline/batch-processing/qa-evidence/retry-2/independent-provenance.json").read_text())
snapshot["matchesIndependentQASourceHashes"] = {
    name: snapshot["sources"][name] == item["sha256"] for name, item in prior.items() if name in snapshot["sources"]
}
snapshot["whitespace"] = command(["git", "diff", "--check", base])
(out / "audit-snapshot.json").write_text(json.dumps(snapshot, indent=2) + "\n")
print(json.dumps({"sourceCount": len(sources), "scopeExit": classify["exit"], "scanExit": scan["exit"],
                  "qaHashMatch": all(snapshot["matchesIndependentQASourceHashes"].values()),
                  "releaseBinaries": snapshot["releaseBinaries"],
                  "whitespaceExit": snapshot["whitespace"]["exit"]}, indent=2))
