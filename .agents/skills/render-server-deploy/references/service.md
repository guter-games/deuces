# Render service reference

## Blueprint (`render.yaml`)

```yaml
services:
  - type: web
    name: deuces
    runtime: node
    plan: free
    region: oregon
    branch: master
    rootDir: server
    buildCommand: yarn install --frozen-lockfile || yarn install
    startCommand: yarn start
    healthCheckPath: /health
    envVars:
      - key: NODE_VERSION
        value: "20"
```

## Protocol surface (clients)

Same Node Express + Socket.IO protocol as `web/`:

- `POST /create_game` — body `{ "numPlayers": N }` → game id / join info
- Socket.IO: `new_identity`, `identify_as`, `play_cards`, `pass`, `game_update`
- `GET /health` — liveness
- `GET /privacy` — static HTML from `server/public/privacy.html`

Server listens on `process.env.PORT || 3012`, bind `0.0.0.0`.

## iOS production URLs

`ServerConfig.production`:

- create: `https://deuces.onrender.com/create_game`
- socket: `https://deuces.onrender.com`

`ServerConfig.current` must remain `.production` for App Store / TestFlight builds.

## Free tier notes

- Cold start can take 30–60+ seconds
- App Store reviewers may hit a sleeping service — consider a paid plan before review
- Auto-deploy only from `master`; other branches do not ship unless blueprint changes
