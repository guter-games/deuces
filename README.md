# deuces

Big Two / Deuces card game.

## Web + server (original)

```bash
make start
```

See **Makefile** for more commands.

## iMessage app (server-backed)

The `ios/` Messages extension uses the **same create_game + Socket.IO protocol** as `web/`.  
`MSMessage` / `MSSession` only carry an immutable **game-id invite** — no state updates go through iMessage.

```bash
make ios-test    # in-memory server stand-in
make ios-build
```

See [`ios/README.md`](ios/README.md) for architecture, endpoints, and the device checklist.
