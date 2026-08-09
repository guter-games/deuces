#!/usr/bin/env bash
# Render a 1024 App Store icon from the repo's 2♠ card art (the namesake "deuce").
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SVG="$ROOT/web/public/cards/2S.svg"
OUT_DIR="$ROOT/ios/Deuces/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Felt-green canvas + centered card.
CARD="$TMP/card.png"
CANVAS="$TMP/canvas.png"
rsvg-convert -w 720 -h 1008 "$SVG" -o "$CARD"
# Solid felt background
sips -s format png --setProperty formatOptions default /System/Library/CoreServices/DefaultDesktop.heic >/dev/null 2>&1 || true
python3 - <<PY
from pathlib import Path
try:
    from PIL import Image
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "pillow"])
    from PIL import Image

felt = (18, 71, 46, 255)  # matches in-app felt
canvas = Image.new("RGBA", (1024, 1024), felt)
card = Image.open("$CARD").convert("RGBA")
# Slight shadow
shadow = Image.new("RGBA", card.size, (0, 0, 0, 0))
from PIL import ImageDraw, ImageFilter
d = ImageDraw.Draw(shadow)
d.rounded_rectangle([8, 12, card.width - 1, card.height - 1], radius=28, fill=(0, 0, 0, 90))
shadow = shadow.filter(ImageFilter.GaussianBlur(12))
x = (1024 - card.width) // 2
y = (1024 - card.height) // 2 + 10
canvas.alpha_composite(shadow, (x, y))
canvas.alpha_composite(card, (x, y))
out = Path("$OUT_DIR/AppIcon.png")
canvas.convert("RGB").save(out, "PNG")
print(f"Wrote {out}")
PY
