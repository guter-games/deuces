# deuces

Big Two / Deuces card game.

## Web + server (original)

```bash
make start
```

See **Makefile** for more commands.

## iMessage app (serverless)

The `ios/` project is a Messages app extension that syncs game state through interactive iMessage updates — no backend required.

```bash
cd ios
xcodegen generate
open Deuces.xcodeproj
```

- Shared rules live in `ios/DeucesCore` (Swift port of `server/deuces.js`, `hand.js`, `card.js`)
- Composer picks **1–4 players** up front, then sends an `MSSession` game bubble (no lobby phase)
- Host app includes a **Local 2P** simulator for offline end-to-end testing

### Automated tests

```bash
cd ios
xcodegen generate
xcodebuild test \
  -project Deuces.xcodeproj \
  -scheme DeucesCore \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### iMessage manual test checklist

These require a real Messages conversation (two Apple IDs / devices or device + Messages on Mac):

1. **Install / discovery** — install the app on device A; confirm Deuces appears in the Messages app drawer
2. **Create bubble** — create a 2-player game; confirm an interactive message is inserted into the thread
3. **Recipient without app** — on device B without the app, tap the bubble and note the App Store / install UX
4. **Join** — install on device B, open the bubble, set a name, join; both sides should show `playing`
5. **Live update** — keep the extension open on A; play a card on B; confirm A’s UI advances via `didReceive`
6. **Reopen recovery** — kill Messages, reopen the latest bubble; confirm latest revision/state loads
7. **Turn enforcement** — try acting out of turn; confirm it is rejected locally and no bad update is sent
8. **Last active** — after each move, confirm the acting player shows “active just now” and others age over time
9. **Pass / free turn** — pass when a run exists (draws from pool); confirm you cannot pass on a free turn
10. **URL size** — in a 4-player mid-game, confirm messages still send (state fits in `MSMessage.url`)
11. **Out-of-order / stale** — if possible, act from an older bubble; newer revision should win and stale moves should not clobber
12. **Identity persistence** — force-quit, reopen same game; you should remain the same seat without re-joining
