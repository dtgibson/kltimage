#!/usr/bin/env python3
"""Export the approved SVG into all ten macOS AppIcon slots.

Requires rsvg-convert (Homebrew: brew install librsvg). Run from any folder.
Use --check to verify committed assets without modifying them. The editable
master and review exporter live in pipeline/professional-app-icon/.
"""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "pipeline/professional-app-icon/icon-master.svg"
CATALOG = ROOT / "KLTImage/Resources/Assets.xcassets"
INFO = {"author": "xcode", "version": 1}


def export(destination):
    iconset = destination / "AppIcon.appiconset"
    iconset.mkdir(parents=True, exist_ok=True)
    images = []
    rendered = {}
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            pixels = points * scale
            filename = f"icon_{points}x{points}{'@2x' if scale == 2 else ''}.png"
            output = iconset / filename
            if pixels in rendered:
                shutil.copyfile(rendered[pixels], output)
            else:
                subprocess.run([
                    "rsvg-convert", "-w", str(pixels), "-h", str(pixels),
                    str(MASTER), "-o", str(output),
                ], check=True)
                rendered[pixels] = output
            images.append({
                "filename": filename, "idiom": "mac",
                "scale": f"{scale}x", "size": f"{points}x{points}",
            })
    (iconset / "Contents.json").write_text(
        json.dumps({"images": images, "info": INFO}, indent=2) + "\n"
    )
    (destination / "Contents.json").write_text(
        json.dumps({"info": INFO}, indent=2) + "\n"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify without writing assets")
    args = parser.parse_args()
    if not shutil.which("rsvg-convert"):
        parser.error("rsvg-convert is required; install with: brew install librsvg")
    if args.check:
        with tempfile.TemporaryDirectory(prefix="klt-app-icon-") as temporary:
            generated = Path(temporary)
            export(generated)
            mismatches = []
            for source in sorted(generated.rglob("*")):
                if source.is_file():
                    relative = source.relative_to(generated)
                    committed = CATALOG / relative
                    if not committed.is_file() or source.read_bytes() != committed.read_bytes():
                        mismatches.append(str(relative))
            if mismatches:
                parser.exit(1, "App icon assets differ: " + ", ".join(mismatches) + "\n")
        print("All ten macOS icon slots and catalog metadata match the approved SVG export.")
    else:
        export(CATALOG)
        print(f"Exported ten macOS icon slots to {CATALOG}")


if __name__ == "__main__":
    main()
