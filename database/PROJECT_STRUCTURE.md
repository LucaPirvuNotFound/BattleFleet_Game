# Project Structure — Battle Fleet 2 Database System (Godot 4)

## File tree

```
godot_version/
├── database/
│   ├── database_schema.sql          # Authoritative SQLite schema
│   ├── DatabaseManager.gd           # Autoload singleton
│   ├── DatabaseModels.gd            # Data classes (class_name BattleFleetModels)
│   ├── PlayerRepository.gd          # Player CRUD
│   ├── PlayerStatsRepository.gd     # Stats, player level, fleet level
│   ├── CaptainRepository.gd         # Captain XP, command cards, accuracy
│   ├── ShipUnlockRepository.gd      # Fleet-level ship gating
│   └── DatabaseUsageExample.gd      # Reference examples (remove from production)
├── ui/
│   └── ProgressionBarUI.gd          # Fleet progress bar + ship unlock list
├── README.md
├── PROJECT_STRUCTURE.md             # This file
└── SETUP_GUIDE.md
```

---

## File purposes

### database_schema.sql — ESSENTIAL
Engine-agnostic SQL definition. Every table and index lives here.
`DatabaseManager.gd` embeds the same statements so tables are created on first launch.
Use this file as the canonical reference when adding new tables.

### DatabaseManager.gd — ESSENTIAL (Autoload)
- Wraps the `godot-sqlite` plugin in three clean methods: `execute_non_query`, `execute_scalar`, `execute_reader`
- Registers as **Autoload** named `DatabaseManager` — every repository calls it directly
- Handles table creation and seed data on `initialize()`
- Call `initialize()` once on game start; call `close()` on exit

### DatabaseModels.gd — ESSENTIAL
- `class_name BattleFleetModels`
- Inner classes: `Player`, `PlayerStats`, `Captain`, `CommandCard`, `CaptainCommandCard`, `BattleRecord`, `CampaignSave`, `ShipUnlockRequirement`, `ShipUnlockStatus`
- No database access — pure data containers
- Access globally: `BattleFleetModels.Player.new("Alice")`

### PlayerRepository.gd
- `class_name PlayerRepository extends RefCounted`
- Full CRUD for the `Players` table
- `create_player()` also creates the associated `PlayerStats` row
- **Fix from Unity**: `_map_player()` now reads `FleetLevel` and `FleetXP`

### PlayerStatsRepository.gd
- `class_name PlayerStatsRepository extends RefCounted`
- Manages two separate systems:
  - **Player Level** (`PlayerStats` table, flat 1000 XP/level) via `add_experience()`, `record_battle_result()`
  - **Fleet Level** (`Players` table, quadratic level×100 XP/level) via `award_fleet_xp_and_level_up()`, `get_progress_bar_data()`
- Leaderboard queries: `get_top_players_by_level()`, `get_top_players_by_win_rate()`
- Signals: `player_leveled_up`, `fleet_leveled_up`
- **Fixes from Unity**: `_db` → `DatabaseManager`; column names `fleet_xp`/`fleet_level` → `FleetXP`/`FleetLevel`; table `players` → `Players`

### CaptainRepository.gd
- `class_name CaptainRepository extends RefCounted`
- Captain XP with quadratic curve (same formula as fleet level)
- `award_battle_xp()` awards XP, handles level-up, auto-unlocks command cards
- Accuracy formula: `(captain_level - 1) × 2.0%` — stored in `Captains.AccuracyBonus`
- Signal: `captain_leveled_up`

### ShipUnlockRepository.gd
- `class_name ShipUnlockRepository extends RefCounted`
- `is_ship_unlocked(player_id, ship_type)` — single unlock check
- `get_all_ship_statuses_for_player(player_id)` — full list for the garage/selection UI
- **Fixes from Unity**: all column names corrected from snake_case to PascalCase; `_db.GetConnection()` replaced with `DatabaseManager` calls

### ProgressionBarUI.gd
- Extends `Control` — attach to a Panel or CanvasLayer in your lobby/fleet scene
- Call `initialise(player_id)` once after login; call `refresh()` after any fleet XP change
- Reads fleet level from `PlayerStatsRepository.get_progress_bar_data()`
- Reads ship list from `ShipUnlockRepository.get_all_ship_statuses_for_player()`
- **Fix from Unity**: removed unused `DatabaseManager db` constructor parameter

### DatabaseUsageExample.gd
- Full working examples of every integration pattern
- Remove from production; use only for development/testing

---

## Dependency diagram

```
Your Game Scenes
      │
      ▼
DatabaseUsageExample / ProgressionBarUI / GameManager
      │
      ├── PlayerRepository
      ├── PlayerStatsRepository
      ├── CaptainRepository
      └── ShipUnlockRepository
              │
              ▼
        DatabaseManager  (Autoload)
              │
              ▼
        godot-sqlite plugin
              │
              ▼
        user://BattleFleetGame.db  (SQLite file)
              │
              ▼
        DatabaseModels (BattleFleetModels.*)
              (no DB access — pure data)
```

---

## Data flow after a battle

```
Battle ends
    │
    ├─► PlayerStatsRepository.record_battle_result()
    │       Updates PlayerStats (level, W/L/D, accuracy, XP)
    │       Emits player_leveled_up if level changes
    │
    ├─► PlayerStatsRepository.award_fleet_xp_and_level_up()
    │       Updates Players.FleetXP + Players.FleetLevel
    │       Emits fleet_leveled_up if fleet level changes
    │
    ├─► CaptainRepository.award_battle_xp()
    │       Updates Captains (XP, level, accuracy bonus)
    │       Auto-unlocks command cards via CaptainCommandCards
    │       Emits captain_leveled_up if level changes
    │
    └─► ProgressionBarUI.refresh()
            Shows updated fleet level + XP bar
            Shows updated ship unlock list
```

---

## XP formulas

### Player Level (flat curve)
```
level = total_experience / 1000 + 1
```
- Level 1 = 0 XP
- Level 2 = 1 000 XP
- Level 3 = 2 000 XP

### Fleet Level & Captain Level (quadratic curve)
```
level N requires N × 100 XP beyond the previous level's threshold
```
| Level | Cumulative XP needed |
|---|---|
| 1 | 0 |
| 2 | 100 |
| 3 | 300 |
| 4 | 600 |
| 5 | 1 000 |

---

## File dependencies

| File | Depends on |
|---|---|
| `DatabaseManager.gd` | `godot-sqlite` plugin |
| `DatabaseModels.gd` | nothing |
| `PlayerRepository.gd` | `DatabaseManager`, `DatabaseModels` |
| `PlayerStatsRepository.gd` | `DatabaseManager`, `DatabaseModels` |
| `CaptainRepository.gd` | `DatabaseManager`, `DatabaseModels` |
| `ShipUnlockRepository.gd` | `DatabaseManager`, `DatabaseModels` |
| `ProgressionBarUI.gd` | `PlayerStatsRepository`, `ShipUnlockRepository`, `DatabaseModels` |
| `DatabaseUsageExample.gd` | all of the above |

---

## Adding new tables

1. Add the SQL to `database_schema.sql`
2. Add the same `CREATE TABLE IF NOT EXISTS` statement to `DatabaseManager._create_tables()`
3. Add a model class to `DatabaseModels.gd`
4. Create a new repository file following the pattern of `PlayerRepository.gd`

---

**Status**: Production ready
**Last updated**: May 2026
**For**: Battle Fleet 2 University Project
