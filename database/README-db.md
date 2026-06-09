# Battle Fleet 2 — Database System (Godot 4 Version)

A complete SQLite persistence layer for the Battle Fleet 2 game, converted from the original Unity/C# implementation to **Godot 4 + GDScript**.

---

## What changed from the Unity version

| Area | Change |
|---|---|
| Engine | Unity → Godot 4 |
| Language | C# → GDScript |
| SQLite driver | `Mono.Data.Sqlite` → `godot-sqlite` plugin |
| DB path | `Application.persistentDataPath` → `user://` |
| Singleton pattern | `DatabaseManager.Instance` → Godot Autoload |
| UI components | `Slider`, `TextMeshProUGUI` → `ProgressBar`, `Label` |
| Events | Unity callbacks → Godot signals |

### Bug fixes applied during conversion

| File | Bug | Fix |
|---|---|---|
| `DatabaseManager` | Players table missing `FleetLevel`, `FleetXP` columns | Added both columns |
| `PlayerRepository` | `GetPlayerByID/ByName` did not read `FleetLevel`/`FleetXP` | Added to `_map_player()` |
| `PlayerStatsRepository` | `AwardXpAndLevelUp` referenced undefined `_db` field | Uses `DatabaseManager` autoload |
| `PlayerStatsRepository` | Wrong table/column names: `players`, `fleet_xp`, `fleet_level` | Fixed to `Players`, `FleetXP`, `FleetLevel` |
| `PlayerStatsRepository` | `GetProgressBarData` same naming bugs | Fixed |
| `ShipUnlockRepository` | Used snake_case columns (`ship_type`, `required_level`, `fleet_level`) not in schema | Fixed to PascalCase (`ShipType`, `RequiredLevel`, `FleetLevel`) |
| `ShipUnlockRepository` | Used `_db.GetConnection()` which doesn't exist | Uses `DatabaseManager` autoload |
| `ProgressionBarUI` | Constructor passed `DatabaseManager db` to repos that only use singleton | Removed unused parameter |

---

## Two XP systems — quick reference

| System | Table | Curve | Purpose |
|---|---|---|---|
| Player Level | `PlayerStats.Level` + `TotalExperience` | Flat: 1000 XP/level | Overall rank, leaderboards |
| Fleet Level | `Players.FleetLevel` + `FleetXP` | Quadratic: level×100 XP/level | Gates ship unlocks |
| Captain Level | `Captains.Level` + `ExperiencePoints` | Quadratic: level×100 XP/level | Accuracy bonus, command cards |

---

## File structure

```
godot_version/
├── database/
│   ├── database_schema.sql          # Authoritative SQLite schema (engine-agnostic)
│   ├── DatabaseManager.gd           # Autoload singleton — all DB access goes through here
│   ├── DatabaseModels.gd            # All data classes (BattleFleetModels.Player, etc.)
│   ├── PlayerRepository.gd          # Player CRUD
│   ├── PlayerStatsRepository.gd     # Stats, player levelling, fleet levelling
│   ├── CaptainRepository.gd         # Captain XP, command cards, accuracy bonuses
│   ├── ShipUnlockRepository.gd      # Ship unlock checks based on FleetLevel
│   └── DatabaseUsageExample.gd      # Integration examples (remove from production)
├── ui/
│   └── ProgressionBarUI.gd          # Fleet-level progress bar + ship list UI
├── README.md                        # This file
├── PROJECT_STRUCTURE.md             # Detailed file & dependency guide
└── SETUP_GUIDE.md                   # Step-by-step Godot setup
```

---

## Quick start

### Step 1 — Install godot-sqlite

Download or install via the Asset Library:
[github.com/2shady4u/godot-sqlite](https://github.com/2shady4u/godot-sqlite)

Copy the `addons/godot-sqlite/` folder into your project root.
Enable it in **Project > Project Settings > Plugins**.

### Step 2 — Register the Autoload

**Project > Project Settings > AutoLoad**
- Path: `res://database/DatabaseManager.gd`
- Name: `DatabaseManager`

### Step 3 — Initialize on game start

```gdscript
# In your main scene or GameManager.gd
func _ready() -> void:
    DatabaseManager.initialize()   # uses user://BattleFleetGame.db by default

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        DatabaseManager.close()
```

### Step 4 — Create a player

```gdscript
var player_repo := PlayerRepository.new()
var player := player_repo.create_player("CommanderAlex")
print(player)  # Player: CommanderAlex (ID: 1) | Fleet Lvl 1
```

---

## Code examples

### Get player stats

```gdscript
var stats_repo := PlayerStatsRepository.new()
var stats := stats_repo.get_player_stats(player.player_id)
print("Level: %d  XP: %d  Win rate: %.1f%%" % [stats.level, stats.total_experience, stats.get_win_rate()])
```

### Record a battle result

```gdscript
var battle := BattleFleetModels.BattleRecord.new()
battle.player_id         = player.player_id
battle.opponent_name     = "AI Admiral"
battle.result            = "Win"       # "Win" | "Loss" | "Draw"
battle.ships_destroyed   = 3
battle.ships_lost        = 1
battle.experience_gained = 300

stats_repo.record_battle_result(player.player_id, battle)
# Also award fleet XP (gates ship unlocks):
stats_repo.award_fleet_xp_and_level_up(player.player_id, 150)
```

### Captain progression

```gdscript
var captain_repo := CaptainRepository.new()

# Create captain
var captain := BattleFleetModels.Captain.new("Captain Morgan", "Aggressive")
captain.player_id = player.player_id
var captain_id := captain_repo.create_captain(captain)

# Award XP after battle (auto-unlocks command cards on level-up)
captain_repo.award_battle_xp(captain_id, battle)

# Get accuracy bonus to apply during combat
var bonus: float = captain_repo.get_captain_accuracy_bonus(captain_id)
print("+%.1f%% accuracy" % bonus)
```

### Ship unlock check

```gdscript
var unlock_repo := ShipUnlockRepository.new()

if unlock_repo.is_ship_unlocked(player.player_id, "Carrier"):
    print("Carrier available!")
else:
    print("Reach Fleet Level 7 to unlock the Carrier.")
```

### Connect level-up signals

```gdscript
var stats_repo := PlayerStatsRepository.new()
stats_repo.fleet_leveled_up.connect(func(pid, old, new_lvl):
    print("Fleet level up! New ships may be available.")
    progression_bar_ui.refresh()
)

var captain_repo := CaptainRepository.new()
captain_repo.captain_leveled_up.connect(func(cid, old, new_lvl, acc):
    print("Captain leveled up! Accuracy bonus: +%.1f%%" % acc)
)
```

### Leaderboard

```gdscript
var top := stats_repo.get_top_players_by_level(10)
for stats in top:
    var p := player_repo.get_player_by_id(stats.player_id)
    print("%s — Level %d" % [p.player_name, stats.level])
```

---

## Database schema

9 tables — see `database/database_schema.sql` for the full definition.

```
Players            — Profiles + FleetLevel/FleetXP
PlayerStats        — Level, XP, W/L/D, accuracy, campaign progress
Captains           — Captain XP, level, accuracy bonus
CommandCards       — Card definitions (seeded, 5 cards)
CaptainCommandCards — Junction: which cards each captain has unlocked
PlayerShips        — Fleet ships
ShipWeapons        — Weapon loadouts
CampaignSaves      — Campaign state
BattleHistory      — Battle records
PlayerAchievements — Unlockables
ShipUnlockRequirements — Fleet-level thresholds (seeded, 6 ship types)
```

---

## Ship unlock thresholds

| Ship | Fleet Level |
|---|---|
| Sloop | 1 (default) |
| Brig | 1 (default) |
| Frigate | 3 |
| Man-O-War | 5 |
| Ironclad | 6 |
| Carrier | 7 |

---

## Performance notes

- All queries use positional `?` bindings — no SQL injection risk
- Indexes on all foreign keys and frequently queried columns
- Single persistent connection via Autoload singleton
- `INSERT OR IGNORE` prevents duplicate seed data on every launch

---

**Project**: Battle Fleet 2 — University Software Developer Project
**Engine**: Godot 4
**Database**: SQLite via godot-sqlite plugin
