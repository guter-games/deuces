#!/usr/bin/env bash
# Build Deuces for simulator and capture App Store screenshot frames.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS="$ROOT/ios"
OUT="$ROOT/store/screenshots"
mkdir -p "$OUT"

cd "$IOS"
xcodegen generate >/dev/null

DEVICE_IPHONE="${SCREENSHOT_IPHONE:-iPhone 17 Pro Max}"
DEVICE_IPAD="${SCREENSHOT_IPAD:-iPad Pro 13-inch (M5)}"

boot_device() {
  local name="$1"
  local udid
  # Names may contain parentheses (e.g. "iPad Pro 13-inch (M5)"); match UDID hex only.
  udid="$(xcrun simctl list devices available | python3 -c '
import re, sys
name = sys.argv[1]
pat = re.compile(r"^\s*(.+?) \(([0-9A-Fa-f-]{36})\) \((Booted|Shutdown)\)")
for line in sys.stdin:
    m = pat.match(line.rstrip())
    if m and m.group(1) == name:
        print(m.group(2))
        break
' "$name")"
  if [[ -z "$udid" ]]; then
    echo "Simulator not found: $name" >&2
    xcrun simctl list devices available | head -40 >&2
    exit 1
  fi
  xcrun simctl boot "$udid" 2>/dev/null || true
  # bootstatus prints progress to stdout — keep UDID-only on stdout for callers.
  xcrun simctl bootstatus "$udid" -b >/dev/stderr
  printf '%s\n' "$udid"
}

capture_on() {
  local device_name="$1"
  local slug="$2"
  local udid
  udid="$(boot_device "$device_name")"
  echo "Building for $device_name ($udid)"
  xcodebuild build \
    -project "$IOS/Deuces.xcodeproj" \
    -scheme Deuces \
    -destination "id=$udid" \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    >/tmp/deuces-screenshot-build.log

  APP="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/Deuces-*/Build/Products/Debug-iphonesimulator/Deuces.app | head -1)"
  xcrun simctl uninstall "$udid" com.deuces.deuces 2>/dev/null || true
  xcrun simctl install "$udid" "$APP"

  for frame in 0 1 2; do
    xcrun simctl terminate "$udid" com.deuces.deuces 2>/dev/null || true
    xcrun simctl launch "$udid" com.deuces.deuces \
      -UITestingScreenshots \
      -UITestingScreenshotFrame "$frame" >/dev/null
    sleep 1.5
    local file="$OUT/${slug}_frame${frame}.png"
    xcrun simctl io "$udid" screenshot "$file"
    echo "Wrote $file"
  done
}

capture_on "$DEVICE_IPHONE" "iphone"
capture_on "$DEVICE_IPAD" "ipad"
echo "Screenshots in $OUT"
