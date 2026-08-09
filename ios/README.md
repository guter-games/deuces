# Deuces for iMessage

Turn-based Deuces over the **same Express + Socket.IO server** as the web app.  
The iMessage bubble is only an immutable **game-id invite** — no game state is ever written into `MSMessage.url`.

## Architecture

| Piece | Role |
|-------|------|
| `POST /create_game` | Create a server game → short id |
| Socket.IO | `new_identity` / `identify_as` / `play_cards` / `pass` / `game_update` |
| `MSMessage` + `MSSession` | One-shot invite bubble pointing at that game id |
| Rematch | Brand-new `create_game` + new bubble (ignores server `playAgainGameID`) |

```
Composer → POST create_game → insert invite bubble (game id only) → collapse
Tap bubble → connect socket ?gameID=… → name/join → play via socket
```

### LAN device testing (default)

```bash
make ios-e2e        # start server, point clients at this Mac's Wi‑Fi IP, run live Socket.IO e2e
make ios-install    # build + install on connected devices
```

`ServerConfig.current` uses `LanHost` (`make ios-lan-config` refreshes the IP from `en0`).  
Devices and this Mac must be on the same network; allow Local Network for Deuces when prompted.

Production endpoints (web) remain available as `ServerConfig.production` if you switch `current` back.

## Project layout

- `DeucesCore` — cards/rules helpers, server client, session controller, SwiftUI board
- `DeucesMessages` — Messages extension UI
- `Deuces` — host app + Local 2P (in-memory server stand-in)

## Setup

```bash
cd ios
xcodegen generate
open Deuces.xcodeproj
```

Signing team is set in `project.yml`. Run the **Deuces** scheme on a device, then trust the developer cert under **Settings → General → VPN & Device Management**.

## Tests

```bash
make ios-test
```

Uses an in-memory backend that mirrors the web protocol (no network). Covers create → invite → join → play sync → rematch new id.

## Manual device check

1. Force-quit Messages on both devices  
2. Create a 2-player game → bubble should say `Deuces (2 players)`  
3. Tap bubble on each device → enter name → join  
4. Plays should appear on the other device **while both have the extension open** (live socket), without the bubble URL changing  
5. Rematch sends a **new** bubble with a new game id  
