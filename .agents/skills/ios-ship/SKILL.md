---
name: ios-ship
description: >-
  Ship Deuces With Friends (standalone iMessage app): bump version, xcodegen,
  archive, App Store Connect upload, TestFlight Internal, iMessage icon
  validation, screenshots, and ASO listing. Use when the user asks to ship,
  upload, TestFlight, new iOS build, App Store, ASC validation, iMessage icons,
  screenshots, or ASO.
compatibility: Requires macOS with Xcode, xcodegen, and App Store Connect signing for team U253FJED45.
metadata:
  repo: deuces
  team: U253FJED45
  product: standalone-imessage
---

# ios-ship

Ship **Deuces With Friends** — a **standalone iMessage app** (`application.messages` + `app-extension.messages`) — to App Store Connect / TestFlight.

There is **no Home Screen companion**. After install: Messages → Apps → Deuces With Friends.

## Constants

| Item | Value |
|------|-------|
| Team | Plant Chess Studios (`U253FJED45`) |
| Display name | Deuces With Friends |
| Container bundle | `com.deuces.deuces.imessage` (`application.messages`) |
| Extension | `com.deuces.deuces.imessage.extension` |
| Core | `com.deuces.deuces.imessage.core` |
| Screenshot harness | `com.deuces.deuces.imessage.screenshot` (local only; not shipped) |
| ASC app | SKU `deuces-imessage-2` — see `store/ASO.md` |
| Spec | `ios/project.yml` |
| Listing copy | `store/ASO.md` |
| Screenshots | `store/screenshots/` via `make ios-screenshots` |

Read [references/release-invariants.md](references/release-invariants.md) before changing project settings.  
Packaging pitfalls: [references/standalone-packaging.md](references/standalone-packaging.md).

## Architecture (do not regress)

| Target | XcodeGen type | Ships? | Role |
|--------|---------------|--------|------|
| `Deuces` | `application.messages` | Yes | Assets-only container (AppIcon). **No Swift / no Home Screen UI.** |
| `DeucesMessages` | `app-extension.messages` | Yes | All gameplay UI |
| `DeucesCore` | `framework` | Embedded in container | Shared engine/client |
| `DeucesScreenshot` | `application` | **No** | Local harness for `make ios-screenshots` |

- Container embeds Core + Messages appex; Messages **links** Core only (`embed: false`).
- Standalone ↔ containing-app extension cannot share one ASC record (would need a new app).
- Do **not** change `Deuces` back to `application` or put SwiftUI host screens in the container.

## Modes

Ask which destination if unclear:

1. **TestFlight Internal** (default) — no App Review; do **not** submit Distribution
2. **App Store submit** — full listing + review; use ASO/screenshots sections
3. **Validate only** — archive + icon/version checks, no upload
4. **Screenshots / ASO** — capture assets or fill Connect from `store/ASO.md`

## Ship a new build (TestFlight Internal)

Copy and track:

```
- [ ] Bump CURRENT_PROJECT_VERSION in ios/project.yml
- [ ] xcodegen generate
- [ ] Regenerate iMessage icons if icon source changed
- [ ] Archive
- [ ] Preflight: versions, APPL package type, 8 iMessage PNGs, no nested Core
- [ ] Upload (testFlightInternalTestingOnly)
- [ ] Tell user ASC Internal steps + Messages install path
```

### 1. Bump version

Edit `ios/project.yml` → `settings.base.CURRENT_PROJECT_VERSION` (integer +1).  
Keep `MARKETING_VERSION` unless the user asks for a marketing bump.

Container and extension Info.plist must use:

- `CFBundleShortVersionString`: `$(MARKETING_VERSION)`
- `CFBundleVersion`: `$(CURRENT_PROJECT_VERSION)`

Never hardcode mismatched build numbers.

### 2. Generate project

```bash
cd ios && xcodegen generate
```

Confirm in `project.pbxproj`:

- `Deuces` → `com.apple.product-type.application.messages`
- `DeucesMessages` → `com.apple.product-type.app-extension.messages`

Not generic `application` / `app-extension`.

### 3. Icons (if needed)

```bash
bash ios/scripts/generate_app_icon.sh          # container AppIcon
bash ios/scripts/generate_imessage_icons.sh    # stickersiconset
```

See [references/imessage-icons.md](references/imessage-icons.md) if ASC reports missing iMessage icons.

### 4. Archive

```bash
rm -rf /tmp/Deuces.xcarchive /tmp/DeucesExport
cd ios && xcodebuild archive \
  -project Deuces.xcodeproj \
  -scheme Deuces \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/Deuces.xcarchive \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=U253FJED45
```

Automatic Signing usually creates `com.deuces.deuces.imessage.extension` on first archive if missing.

### 5. Preflight (required before upload)

```bash
APP=/tmp/Deuces.xcarchive/Products/Applications/Deuces.app
APPEX="$APP/PlugIns/DeucesMessages.appex"

# Bundle IDs
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist"
# expect: com.deuces.deuces.imessage
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APPEX/Info.plist"
# expect: com.deuces.deuces.imessage.extension

# Versions must match
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APPEX/Info.plist"

# ASC rejects missing package type on standalone containers
/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' "$APP/Info.plist"
# expect: APPL
# PkgInfo should start with APPL (not ????????)
cat "$APP/PkgInfo"; echo

# Exactly these 8 loose PNGs must exist (actool --stickers-icon-role extension)
ls "$APPEX"/iMessage\ App\ Icon*.png | wc -l   # expect 8

# Extension must NOT embed DeucesCore.framework
test ! -d "$APPEX/Frameworks/DeucesCore.framework"

# Standalone: launch prohibited on Home Screen (injected by product type)
/usr/libexec/PlistBuddy -c 'Print :LSApplicationLaunchProhibited' "$APP/Info.plist"
# expect: true
```

Pixel sizes ASC requires: 54×40, 81×60, 64×48, 96×72, 120×90, 180×135, 134×100, 148×110.

### 6. Upload

Use [assets/ExportOptions-testflight.plist](assets/ExportOptions-testflight.plist):

```bash
xcodebuild -exportArchive \
  -archivePath /tmp/Deuces.xcarchive \
  -exportOptionsPlist .agents/skills/ios-ship/assets/ExportOptions-testflight.plist \
  -exportPath /tmp/DeucesExport \
  -allowProvisioningUpdates
```

For a local IPA only, change `destination` to `export` in a copy of that plist.

**Expected harmless warnings** on upload (do not “fix” by removing standalone mode):

- Vision Pro / Mac Apple silicon: `LSApplicationLaunchProhibited` isn’t supported there — normal for Messages-only apps.

**Known fatal validation** (must fix before retry):

- `Invalid Bundle OS Type code` → container missing `CFBundlePackageType=APPL` (see [standalone-packaging.md](references/standalone-packaging.md)).

### 7. After upload — user ASC steps

Tell the user (do not submit Distribution for Internal):

1. Wait until build is **Ready to Test** / **Testing**
2. TestFlight → **Internal** group → add this build only
3. Do **not** add to External; do **not** submit for App Store review
4. Tester must be a Users and Access team member; accept invite email on device
5. Install via TestFlight, then open **Messages → Apps → Deuces With Friends** (nothing on Home Screen)

Troubleshoot with [references/testflight-asc.md](references/testflight-asc.md).

## Screenshots

Standalone container has no launchable UI. Capture via the local harness:

```bash
make ios-screenshots
```

Uses scheme `DeucesScreenshot` / bundle `com.deuces.deuces.imessage.screenshot` (see `ios/scripts/capture_screenshots.sh`).  
Outputs under `store/screenshots/`. Suggested order per device: `*_frame0` (your turn), `*_frame1` (waiting), `*_frame2` (win). Upload iPhone + iPad sets in Connect (App + iMessage wells — see `store/ASO.md`).

## ASO / App Store listing

Copy fields from `store/ASO.md` (name **Deuces With Friends**, subtitle, description, keywords, privacy URL, age rating, privacy nutrition, review notes). Privacy: `https://deuces.onrender.com/privacy`.

Review notes must say it is a **standalone iMessage app** with no Home Screen icon.

Only needed for App Store / External TestFlight — not for Internal Testing.

## Production client target

Release builds use `ServerConfig.current == .production` → `https://deuces.onrender.com`. Live e2e tests use `ServerConfig.lan` explicitly; do not flip `current` for shipping.
