# iMessage icon packaging

## Symptom

ASC / upload validation: missing iMessage app icons at 54×40, 81×60, 64×48, 96×72, 120×90, 180×135, 134×100, 148×110.

## Root cause

Messages target was not `app-extension.messages`, so actool never received `--stickers-icon-role extension`. Only the 1024×768 marketing image ends up in `Assets.car`; ASC needs the **loose PNGs** in the appex.

## Fix

1. Ensure `ios/project.yml` → `DeucesMessages.type: app-extension.messages`
2. Regenerate: `bash ios/scripts/generate_imessage_icons.sh`
3. `xcodegen generate` + re-archive
4. Confirm appex contains:

```
iMessage App Icon27x20@2x.png   # 54×40
iMessage App Icon27x20@3x.png   # 81×60
iMessage App Icon32x24@2x.png   # 64×48
iMessage App Icon32x24@3x.png   # 96×72
iMessage App Icon60x45@2x.png   # 120×90
iMessage App Icon60x45@3x.png   # 180×135
iMessage App Icon67x50@2x.png   # 134×100
iMessage App Icon74x55@2x.png   # 148×110
```

plus `Assets.car` (marketing 1024×768).

## Do not

- Put a stray 1024×1024 PNG in the stickersiconset (actool “unassigned child”)
- Set Messages product type back to generic `app-extension`
- Embed DeucesCore inside the appex
