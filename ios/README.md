# Deuces for iMessage

Serverless turn-based Deuces that syncs entirely through interactive iMessage game-state messages (`MSSession` + `MSMessage.url`).

## Architecture

- `DeucesCore` — port of the existing Node game rules (`server/deuces.js`, `hand.js`, `card.js`), compact state codec, SwiftUI board
- `DeucesMessages` — Messages app extension (`MSMessagesAppViewController`)
- `Deuces` — host app + **Local 2P** simulator (no Messages required)

Transport is abstracted (`GameTransport`), so UI/rules never depend on Messages directly.

## Setup

```bash
cd ios
xcodegen generate
open Deuces.xcodeproj
```

Select your development team under Signing for **Deuces** and **DeucesMessages**, then run the **Deuces** scheme on a device or simulator.

### First launch on a new device (required)

Development-signed apps will **install** but iOS will refuse to run the host app *or* the Messages extension until the developer is trusted. Symptom: Deuces tab in Messages is a blank white popover; host app won't open.

On the device:

1. Open **Settings → General → VPN & Device Management** (on older iPadOS: **Device Management**)
2. Under **Developer App**, tap **Apple Development: plantchessgame@gmail.com** (or your team)
3. Tap **Trust**
4. Open the **Deuces** host app once (confirms launch works)
5. Force-quit **Messages**, reopen, then open the Deuces tab

If launch still fails, device logs show `AnchorTrusted = 0` / `FBSOpenApplicationErrorDomain` code 3 (Security).

## Test what CI/local can cover

```bash
make ios-test
```

This runs unit tests plus `EndToEndTests`, which simulate the iPhone↔iPad Messages flow
(create bubble → dismiss → tap → join → play → live update → reopen) without devices.

Or use the host app **Local 2P** tab for a manual two-player UI smoke test.

## Manual testing required (cannot automate here)

See the root `README.md` section **iMessage manual test checklist**.
