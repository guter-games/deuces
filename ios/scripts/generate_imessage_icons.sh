#!/usr/bin/env bash
# Generate required iMessage App Icon PNGs from the 1024 host App Icon.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/ios/Deuces/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
OUT="$ROOT/ios/DeucesMessages/Assets.xcassets/iMessage App Icon.stickersiconset"
mkdir -p "$OUT"

python3 - <<PY
from pathlib import Path
try:
    from PIL import Image, ImageOps
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "pillow"])
    from PIL import Image, ImageOps

src = Image.open("$SRC").convert("RGBA")
out = Path("$OUT")

# (filename, width, height)
sizes = [
    ("icon-27x20@2x.png", 54, 40),
    ("icon-27x20@3x.png", 81, 60),
    ("icon-32x24@2x.png", 64, 48),
    ("icon-32x24@3x.png", 96, 72),
    ("icon-29x29@2x.png", 58, 58),
    ("icon-29x29@3x.png", 87, 87),
    ("icon-ipad-29x29@2x.png", 58, 58),
    ("icon-60x45@2x.png", 120, 90),
    ("icon-60x45@3x.png", 180, 135),
    ("icon-ipad-67x50@2x.png", 134, 100),
    ("icon-ipad-74x55@2x.png", 148, 110),
    ("icon-1024x768.png", 1024, 768),
]

def fit(img, w, h):
    # Cover-fit into target size (center crop).
    return ImageOps.fit(img, (w, h), method=Image.Resampling.LANCZOS)

for name, w, h in sizes:
    fit(src, w, h).convert("RGB").save(out / name, "PNG")
    print(name, w, h)

# Slots match Apple's Messages Extension stickersiconset template.
contents = {
  "images": [
    {"filename": "icon-29x29@2x.png", "idiom": "iphone", "scale": "2x", "size": "29x29"},
    {"filename": "icon-29x29@3x.png", "idiom": "iphone", "scale": "3x", "size": "29x29"},
    {"filename": "icon-60x45@2x.png", "idiom": "iphone", "scale": "2x", "size": "60x45"},
    {"filename": "icon-60x45@3x.png", "idiom": "iphone", "scale": "3x", "size": "60x45"},
    {"filename": "icon-ipad-29x29@2x.png", "idiom": "ipad", "scale": "2x", "size": "29x29"},
    {"filename": "icon-ipad-67x50@2x.png", "idiom": "ipad", "scale": "2x", "size": "67x50"},
    {"filename": "icon-ipad-74x55@2x.png", "idiom": "ipad", "scale": "2x", "size": "74x55"},
    {"filename": "icon-27x20@2x.png", "idiom": "universal", "platform": "ios", "scale": "2x", "size": "27x20"},
    {"filename": "icon-27x20@3x.png", "idiom": "universal", "platform": "ios", "scale": "3x", "size": "27x20"},
    {"filename": "icon-32x24@2x.png", "idiom": "universal", "platform": "ios", "scale": "2x", "size": "32x24"},
    {"filename": "icon-32x24@3x.png", "idiom": "universal", "platform": "ios", "scale": "3x", "size": "32x24"},
    {"filename": "icon-1024x768.png", "idiom": "ios-marketing", "platform": "ios", "scale": "1x", "size": "1024x768"},
  ],
  "info": {"author": "xcode", "version": 1},
}
import json
(out / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
print("Wrote", out / "Contents.json")
PY
