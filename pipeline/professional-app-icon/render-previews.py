"""Deterministically export original vector artwork and a review sheet.

Requires rsvg-convert and Pillow. Run from any working directory.
Only writes review artifacts beside this script; no production asset changes.
"""
from pathlib import Path
import base64
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FONT = ROOT.parent.parent / "KLTImage/Resources/Fonts"
for size in (16, 32, 64, 128, 256, 512, 1024):
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), str(ROOT / "icon-master.svg"), "-o", str(ROOT / f"icon-{size}.png")], check=True)

svg = (ROOT / "icon-master.svg").read_text()
body = svg[svg.index(">") + 1:svg.rindex("</svg>")]
symbol = '<svg class="hidden" aria-hidden="true"><symbol id="icon" viewBox="0 0 1024 1024">' + body + '</symbol></svg>'
html = (ROOT / "design-template.html").read_text().replace("__SYMBOL__", symbol)
for token, filename in (("__REGULAR__", "IBMPlexSans-Regular.ttf"), ("__SEMIBOLD__", "IBMPlexSans-SemiBold.ttf")):
    html = html.replace(token, base64.b64encode((FONT / filename).read_bytes()).decode())
html = html.replace("__SIZES__", "".join(f'<figure><img src="data:image/png;base64,{base64.b64encode((ROOT / f"icon-{size}.png").read_bytes()).decode()}" width="{size}" height="{size}" alt="KLT Image icon at {size} pixels"><figcaption>{size} px</figcaption></figure>' for size in (16, 32, 64, 128)))
(ROOT / "design.html").write_text(html)

sheet = Image.new("RGB", (1200, 900), "#F7F9F9")
d = ImageDraw.Draw(sheet)
def text(at, value, size=18, color="#304854", bold=False):
    d.text(at, value, font=ImageFont.truetype(str(FONT / ("IBMPlexSans-SemiBold.ttf" if bold else "IBMPlexSans-Regular.ttf")), size), fill=color)
text((56, 40), "KLT IMAGE", 15, bold=True)
text((875, 40), "APPROVED DIRECTION", 15, bold=True)
text((56, 84), "Registered color.", 44, "#142A36", True)
text((56, 148), "One image, two views. A precise seam joins the navy and teal fields.", 21)
d.rectangle((56, 208, 600, 642), fill="#DBE3E5")
d.rectangle((600, 208, 1144, 642), fill="#193A4A")
master = Image.open(ROOT / "icon-1024.png").convert("RGBA")
large = master.resize((352, 352), Image.Resampling.LANCZOS)
sheet.paste(large, (152, 232), large)
sheet.paste(large, (696, 232), large)
text((300, 602), "LIGHT", 14, bold=True)
text((842, 602), "DARK", 14, "#EDF3F4", True)
text((56, 682), "ACTUAL PIXEL SIZES", 14, bold=True)
for size, x in ((16, 80), (32, 176), (64, 288), (128, 440)):
    icon = Image.open(ROOT / f"icon-{size}.png").convert("RGBA")
    sheet.paste(icon, (x, 842-size), icon)
    text((x, 854), f"{size} px", 14)
text((680, 750), "Original vector artwork.", 22, "#142A36", True)
text((680, 786), "Cool-white tile. One continuous image form.", 17)
text((680, 815), "Approved for the macOS application icon.", 17)
sheet.save(ROOT / "icon-presentation.png")
print("Exported self-contained design.html, seven PNG sizes, and icon-presentation.png")
