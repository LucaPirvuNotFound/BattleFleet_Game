# BattleFleet — Meta-Game vs Real-Time Battle

## Current implementation (prototype)

```text
Godot Client                    FastAPI (port 8001)
─────────────                   ───────────────────
Login / Register        ──────► auth.py (JWT)
Fleet builder (menu)    ──────► fleet JSON in memory
Continue
  └─► MatchPrep scene
        1. MapGenerator → Terrain.gd (noise seed, update_mesh)
        2. Top-down map camera
        3. Coin flip UI (red left / blue right, 3D coin)
        4. FastAPI matchmaking (PvP) or instant match (PvE/Local)
        5. coin_ack, then placement stub (Battle.tscn)
```

**Not built yet:** Godot headless dedicated server, ENet, disconnecting from FastAPI for combat.

---

## Target architecture (your design)

### Phase A — Meta-game (FastAPI + HTTP / WebSockets)

- Auth, profiles, fleet loadout validation
- Matchmaking queue by skill level
- Persist match records, XP, winners in DB
- Issue **Godot dedicated server** connection info when match is ready

### Phase B — Battle (Godot dedicated server + ENet)

- Players leave real-time combat on FastAPI (except post-game report)
- Connect to **match-specific** Godot headless instance (IP:port from FastAPI)
- Real-time placement, turns, shots via Godot multiplayer API
- Server authoritative simulation

### Phase C — End of match

```http
POST /matches/{id}/result
{ "winner": "Player1", "xp_gained": 50 }
```

- Godot server notifies FastAPI
- FastAPI updates database
- Godot server instance shuts down

---

## Player flow (target)

1. Open game → login (FastAPI)
2. Build fleet in menu
3. **Find match** → FastAPI queue
4. FastAPI pairs players → spawns Godot headless server → returns `{ host, port, match_token }`
5. Client shows map + coin (can use match seed from FastAPI)
6. Clients connect ENet to Godot server for placement + combat
7. Server reports winner to FastAPI

---

## What to build next (suggested order)

1. WebSocket match status on FastAPI (replace queue polling)
2. Persist `users` / `matches` in SQLite or Postgres
3. Godot headless export + minimal ENet lobby scene
4. FastAPI endpoint to spawn Docker per match (or single long-lived headless with rooms)
5. Remove placement from FastAPI once ENet handles it
