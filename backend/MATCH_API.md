# BattleFleet Match API

Base URL: `http://127.0.0.1:8001` (host port; container still listens on 8000 inside Docker)  
Auth: `Authorization: Bearer <JWT>` (required for PvP/PvE; optional for local instant match)

## Fleet JSON (from Godot menu)

Matches `MainMenu` fleet builder: `_fleet` is an array of ships.

```json
{
  "ships": [
    { "name": "Destroyer", "weapons": ["Torpedoes", "Light Cannon"] },
    { "name": "Corvette", "weapons": ["Anti-Air"] }
  ],
  "total_cost": 45
}
```

| Field | Type | Notes |
|-------|------|--------|
| `ships` | array | 1–5 ships |
| `ships[].name` | string | e.g. Corvette, Destroyer |
| `ships[].weapons` | string[] | weapon names from menu |
| `total_cost` | int | 0–100, must match builder rules |

## Placement JSON (battle phase)

```json
{
  "placements": [
    { "ship_index": 0, "x": 2, "y": 5, "rotation": 0 }
  ]
}
```

One entry per ship; `ship_index` is 0..N-1 in fleet order.

---

## Matchmaking (PvP)

| Method | Path | Body | Response |
|--------|------|------|----------|
| POST | `/matchmaking/queue` | `{ "mode": "pvp", "fleet": FleetPayload }` | `{ "status": "searching" \| "matched", "match_id": null \| uuid, "message": "..." }` |
| GET | `/matchmaking/status` | — | Same as above; returns `matched` when paired |
| DELETE | `/matchmaking/queue` | — | 204, leaves queue |

Poll `GET /matchmaking/status` every ~1s until `status == "matched"`.

---

## Matches

| Method | Path | Body | Notes |
|--------|------|------|--------|
| POST | `/matches/instant` | `{ "mode": "pve" \| "local", "fleet": FleetPayload }` | Instant room (no queue) |
| GET | `/matches/{match_id}` | — | Full match snapshot |
| POST | `/matches/{match_id}/coin_ack` | — | After coin animation |
| POST | `/matches/{match_id}/placement` | PlacementRequest | Submit ship positions |
| POST | `/matches/{match_id}/ready` | — | Confirm placement; starts combat when both ready |

### Match phases

`coin` → `placement` → `combat` → `finished`

- **coin**: server sets `first_player_username` and `map_seed` at creation.
- **placement**: both players POST placement + ready.
- **combat**: stub for gameplay (both ready).

### Match snapshot (`MatchView`)

```json
{
  "match_id": "uuid",
  "mode": "pvp",
  "phase": "coin",
  "map_seed": 123456789,
  "map_index": 1,
  "first_player_username": "player_a",
  "you_go_first": true,
  "local_username": "player_a",
  "opponent_username": "player_b",
  "players": [
    {
      "username": "player_a",
      "slot": 0,
      "fleet": { "ships": [...], "total_cost": 45 },
      "placement_ready": false,
      "coin_ack": false,
      "is_you": true
    }
  ]
}
```

---

## Godot `MatchContext` autoload fields

| Field | Source |
|-------|--------|
| `match_id` | `match_id` |
| `mode` | `mode` |
| `phase` | `phase` |
| `map_seed` | `map_seed` |
| `map_index` | `map_index` |
| `first_player_username` | `first_player_username` |
| `you_go_first` | `you_go_first` |
| `local_username` | `local_username` |
| `opponent_username` | `opponent_username` |
| `your_fleet` | set locally in menu before request |
| `your_fleet_total_cost` | set locally in menu |
| `players` | `players` array from API |

---

## Client flow

1. **Menu**: pick PvP / PvE / Local → build fleet → Continue.
2. **PvP**: `POST /matchmaking/queue` → poll status → `GET /matches/{id}` → `Battle.tscn`.
3. **PvE / Local**: `POST /matches/instant` → `Battle.tscn`.
4. **Battle**: coin_ack → placement + ready → combat (stub).
