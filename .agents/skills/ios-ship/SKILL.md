---
name: ios-ship
description: >-
  Ship Deuces iOS/iMessage builds: bump version, xcodegen, archive, App Store
  Connect upload, TestFlight Internal, iMessage icon validation, screenshots,
  and ASO listing. Use when the user asks to ship, upload, TestFlight, new iOS
  build, App Store, ASC validation, iMessage icons, screenshots, or ASO.
compatibility: Requires macOS with Xcode, xcodegen, and App Store Connect signing for team U253FJED45.
metadata:
  repo: deuces
  team: U253FJED45
---

# ios-ship

Ship Deuces (host app + Messages extension) to App Store Connect / TestFlight.

## Constants

| Item | Value |
|------|-------|
| Team | Plant Chess Studios (`U253FJED45`) |
| Host bundle | `com.deuces.deuces` |
| Extension | `com.deuces.deuces.imessage` |
| Core | `com.deuces.deuces.core` |
| ASC app | https://appstoreconnect.apple.com/apps/6799698932/testflight/ios |
| Spec | `ios/project.yml` |
| Listing copy | `store/ASO.md` |
| Screenshots | `store/screenshots/` via `make ios-screenshots` |

Read [references/release-invariants.md](references/release-invariants.md) before changing project settings.

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
- [ ] Preflight: versions match + 8 iMessage PNGs in appex
- [ ] Upload (testFlightInternalTestingOnly)
- [ ] Tell user ASC Internal steps
```

### 1. Bump version

Edit `ios/project.yml` → `settings.base.CURRENT_PROJECT_VERSION` (integer +1).  
Keep `MARKETING_VERSION` unless the user asks for a marketing bump.

Both host and extension Info.plist must use:

- `CFBundleShortVersionString`: `$(MARKETING_VERSION)`
- `CFBundleVersion`: `$(CURRENT_PROJECT_VERSION)`

Never hardcode mismatched build numbers.

### 2. Generate project

```bash
cd ios && xcodegen generate
```

Confirm: Messages target type is `app-extension.messages` (not generic `app-extension`).

### 3. Icons (if needed)

```bash
bash ios/scripts/generate_app_icon.sh          # host AppIcon
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

### 5. Preflight (required before upload)

```bash
HOST=/tmp/Deuces.xcarchive/Products/Applications/Deuces.app
APPEX="$HOST/PlugIns/DeucesMessages.appex"

# Versions must match
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$HOST/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APPEX/Info.plist"

# Exactly these 8 loose PNGs must exist (actool --stickers-icon-role extension)
ls "$APPEX"/iMessage\ App\ Icon*.png | wc -l   # expect 8

# Extension must NOT embed DeucesCore.framework
test ! -d "$APPEX/Frameworks/DeucesCore.framework"
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

### 7. After upload — user ASC steps

Tell the user (do not submit Distribution for Internal):

1. Wait until build is **Ready to Test** / **Testing**
2. TestFlight → **Internal** group → add this build only
3. Do **not** add to External; do **not** submit for App Store review
4. Tester must be a Users and Access team member; accept invite email on device

Troubleshoot with [references/testflight-asc.md](references/testflight-asc.md).

## Screenshots

```bash
make ios-screenshots
```

Outputs under `store/screenshots/`. Suggested order per device: `*_frame0` (your turn), `*_frame1` (waiting), `*_frame2` (win). Upload iPhone 6.7" + iPad 12.9" sets in Connect.

## ASO / App Store listing

Copy fields from `store/ASO.md` (name, subtitle, description, keywords, privacy URL, age rating, privacy nutrition, review notes). Privacy: `https://deuces.onrender.com/privacy`.

Only needed for App Store / External TestFlight — not for Internal Testing.

## Production client target

Release builds use `ServerConfig.current == .production` → `https://deuces.onrender.com`. Live e2e tests use `ServerConfig.lan` explicitly; do not flip `current` for shipping.
