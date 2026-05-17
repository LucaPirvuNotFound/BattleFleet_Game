# Setup Guide — Battle Fleet 2 Database System (Godot 4)

## Prerequisites

- Godot 4.x
- godot-sqlite plugin by 2shady4u

---

## Step 1 — Install the godot-sqlite plugin

**Option A — Asset Library (recommended)**
1. Open your Godot project
2. Go to **AssetLib** tab
3. Search for "SQLite"
4. Install "SQLite" by 2shady4u
5. Enable it in **Project > Project Settings > Plugins**

**Option B — Manual install**
1. Download the release from: https://github.com/2shady4u/godot-sqlite
2. Copy the `addons/godot-sqlite/` folder into your project root
3. Enable it in **Project > Project Settings > Plugins**

---

## Step 2 — Copy the database files

Place the Godot version files in your project:

```
YourProject/
├── addons/godot-sqlite/          # plugin (Step 1)
├── database/
│   ├── database_schema.sql
│   ├── DatabaseManager.gd
│   ├── DatabaseModels.gd
│   ├── PlayerRepository.gd
│   ├── PlayerStatsRepository.gd
│   ├── CaptainRepository.gd
│   ├── ShipUnlockRepository.gd
│   └── DatabaseUsageExample.gd   # optional — remove from production
└── ui/
    └── ProgressionBarUI.gd
```

---

## Step 3 — Register DatabaseManager as an Autoload

1. Open **Project > Project Settings > AutoLoad**
2. Click the folder icon, navigate to `res://database/DatabaseManager.gd`
3. Set the **Node Name** to exactly: `DatabaseManager`
4. Click **Add**

This makes `DatabaseManager` globally accessible from every GDScript file.

---

## Step 4 — Initialize on game start

In your main scene (e.g. `GameManager.gd`):

```gdscript
extends Node

func _ready() -> void:
    # Opens (or creates) the SQLite database and creates all tables
    DatabaseManager.initialize()
    # Default path: user://BattleFleetGame.db
    # Custom path:  DatabaseManager.initialize("user://myGame.db")

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        DatabaseManager.close()
```

The database file is stored in Godot's `user://` directory:
- **Windows**: `%APPDATA%\Godot\app_userdata\<ProjectName>\`
- **macOS**: `~/Library/Application Support/Godot/app_userdata/<ProjectName>/`
- **Linux**: `~/.local/share/godot/app_userdata/<ProjectName>/`

---

## Step 5 — Set up the Progression Bar UI (optional)

1. In your fleet/lobby scene, add a **Control** node
2. Attach `ui/ProgressionBarUI.gd` to it
3. Add the required child nodes and assign them in the Inspector:

| Property | Node type | Purpose |
|---|---|---|
| `xp_bar` | ProgressBar | XP fill within the current fleet level |
| `level_label` | Label | "Fleet Level 4" |
| `xp_label` | Label | "240 / 400 XP" |
| `ship_list` | VBoxContainer | Dynamically populated ship rows |

4. Optionally assign `ship_row_scene` — a PackedScene with a Label named `ShipLabel` and optionally a TextureRect named `LockIcon`. If left empty, a fallback HBoxContainer is used.

5. Call from your player login flow:
```gdscript
$ProgressionBarUI.initialise(player.player_id)
```

6. Refresh after any fleet XP change:
```gdscript
stats_repo.fleet_leveled_up.connect(func(_pid, _old, _new): $ProgressionBarUI.refresh())
```

---

## Usage examples

### Create a player

```gdscript
var player_repo := PlayerRepository.new()
var player := player_repo.create_player("CommanderAlex")
# Returns null if the name already exists
```

### Get player stats

```gdscript
var stats_repo := PlayerStatsRepository.new()
var stats := stats_repo.get_player_stats(player.player_id)
print("Win rate: %.1f%%" % stats.get_win_rate())
```

### After a battle — full update sequence

```gdscript
var battle := BattleFleetModels.BattleRecord.new()
battle.player_id         = player.player_id
battle.opponent_name     = "AI Admiral Tanaka"
battle.result            = "Win"   # "Win" | "Loss" | "Draw"
battle.ships_destroyed   = 3
battle.ships_lost        = 1
battle.experience_gained = 300

# 1. Update player stats (player level)
stats_repo.record_battle_result(player.player_id, battle)

# 2. Update fleet level (gates ship unlocks)
stats_repo.award_fleet_xp_and_level_up(player.player_id, 150)

# 3. Update captain XP (accuracy bonus + command cards)
captain_repo.award_battle_xp(captain_id, battle)

# 4. Refresh UI
$ProgressionBarUI.refresh()
```

### Check ship unlock

```gdscript
var unlock_repo := ShipUnlockRepository.new()
var statuses := unlock_repo.get_all_ship_statuses_for_player(player.player_id)
for s in statuses:
    print("%s: %s" % [s.display_name, s.get_unlock_label()])
```

### Listen to level-up signals

```gdscript
var stats_repo := PlayerStatsRepository.new()

stats_repo.fleet_leveled_up.connect(
    func(player_id, old_level, new_level):
        print("Fleet level up! %d → %d" % [old_level, new_level])
        # Refresh progression bar, check new ships, show popup, etc.
)

stats_repo.player_leveled_up.connect(
    func(player_id, old_level, new_level):
        print("Player leveled up! %d → %d" % [old_level, new_level])
)
```

---

## Best practices

1. **Initialize once, close once** — call `DatabaseManager.initialize()` in `_ready()` and `close()` in `_notification(NOTIFICATION_WM_CLOSE_REQUEST)`
2. **One repository instance per scene** — repositories are lightweight `RefCounted` objects; create them where you need them
3. **Use signals for UI updates** — connect `fleet_leveled_up` to `ProgressionBarUI.refresh()` so the UI stays in sync automatically
4. **Soft delete players** — `player_repo.delete_player(id, false)` preserves battle history for analytics
5. **Check `DatabaseManager.is_ready()`** before running queries in edge cases (loading screens, etc.)

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `SQLite is not a valid class name` | Plugin not enabled | Enable godot-sqlite in Project > Plugins |
| `DatabaseManager: Not initialized` | `initialize()` not called | Add `DatabaseManager.initialize()` to game start |
| Queries return empty arrays | Wrong column names in custom queries | Column names are PascalCase — match the schema |
| Duplicate player error | `create_player()` called twice | Use `player_exists()` to check first |
| Progress bar always shows 0% | `initialise(player_id)` not called | Call `initialise(player_id)` after player login |
| Ship list empty | No rows in ShipUnlockRequirements | Run `DatabaseManager.initialize()` to seed the table |

---

## Extending the system

### Add a new table

1. Add SQL to `database_schema.sql`
2. Add the same statement to `DatabaseManager._create_tables()`
3. Add a model class inside `DatabaseModels.gd`
4. Create a new `.gd` file extending `RefCounted` following the `PlayerRepository` pattern

### Change the XP curve

The quadratic fleet/captain XP formula is in two places — keep them in sync:
- `PlayerStatsRepository.calculate_fleet_level()`
- `CaptainRepository.calculate_captain_level()`

The flat player-level formula is in `PlayerStatsRepository` as `XP_PER_PLAYER_LEVEL = 1000`.

---

**Engine**: Godot 4
**Plugin**: godot-sqlite by 2shady4u
**Database**: SQLite (stored in `user://BattleFleetGame.db`)
