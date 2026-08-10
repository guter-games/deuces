---
name: render-server-deploy
description: >-
  Deploy or verify the Deuces Node game server on Render (deuces.onrender.com).
  Use when the user asks to deploy the server, push to Render, check production
  health, update privacy page, or change server/rootDir/render.yaml.
compatibility: Requires git remote access for deploy-via-push; optional Render API/dashboard.
metadata:
  repo: deuces
  service: deuces.onrender.com
---

# render-server-deploy

Production game server for iOS + web clients.

## Service

| Item | Value |
|------|-------|
| URL | `https://deuces.onrender.com` |
| Health | `https://deuces.onrender.com/health` |
| Privacy | `https://deuces.onrender.com/privacy` |
| Create game | `POST https://deuces.onrender.com/create_game` |
| Blueprint | `render.yaml` |
| Root dir | `server` |
| Branch | `master` (auto-deploy) |
| Runtime | Node 20 |
| Plan | free (cold starts; paid recommended for App Store quality) |

Details: [references/service.md](references/service.md).

## Deploy workflow

Render auto-deploys when `master` updates files under `server/` (and `render.yaml`).

```
- [ ] Change server code / static assets
- [ ] Commit (only if user asked)
- [ ] Push master (only if user asked)
- [ ] Wait for Render deploy
- [ ] Verify health + create_game + privacy
```

### 1. Scope changes

Server lives in `server/`:

- `server/server.js` — Express + Socket.IO
- `server/deuces.js` — game engine
- `server/public/privacy.html` — privacy policy (served at `/privacy`)
- `server/package.json` — start script / deps

iOS clients point at production via `ios/DeucesCore/ServerConfig.swift` → `.production`.

### 2. Git

**Never commit or push unless the user explicitly asks.**

When asked to deploy:

```bash
git status
git log -5 --oneline
# commit server changes if needed (user-requested)
git push origin master
```

### 3. Verify production

After deploy finishes (dashboard or ~1–3 min on free tier; longer if cold):

```bash
curl -sf "https://deuces.onrender.com/health" && echo
curl -sf -X POST "https://deuces.onrender.com/create_game" \
  -H 'Content-Type: application/json' \
  -d '{"numPlayers":1}' && echo
curl -sI "https://deuces.onrender.com/privacy" | head -5
```

Expect: health OK, JSON game payload from `create_game`, privacy `200`.

First request after idle may be slow (free-tier spin-up). Retry once before declaring failure.

### 4. Local LAN server (not production)

For device QA against a Mac:

```bash
make up-server    # 0.0.0.0:3012
make stop-server
```

Do not confuse LAN with Render. Shipping iOS uses production URLs.

## Blueprint changes

Edit `render.yaml` only when changing plan, region, build/start, or env. Push to `master` to apply. Current essentials:

- `rootDir: server`
- `buildCommand: yarn install --frozen-lockfile || yarn install`
- `startCommand: yarn start`
- `healthCheckPath: /health`
- `NODE_VERSION=20`

## Security

- Never commit Render API keys
- If a key was pasted into chat or logs, tell the user to rotate it in the Render dashboard
