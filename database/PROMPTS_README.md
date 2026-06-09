# Prompt History — Battle Fleet 2 Godot Version

Tracks the prompts that produced this `godot_version/` folder and a short summary of each response.

---

**Prompt 6 (Claude) — Godot conversion**
"we decided to create a game based on BattleFleet2(the naval turn-based game). the gameplay should be very similar to the original game, so most of the logic should be implemented the same way. My tasks were to implement the database scripts, the levelling up and the progression bar. additionally i should write up the logic of saving up the progress (only the database part). As you can see you have in this folder scripts in sql and c#, but we decided to change the framework and go with GODOT. I want you, based on what I described to you, to read the scripts, search up the game logic if needed, check and modify the logical errors if are any and to convert all the scripts into GODOT, in another folder that will be named 'godot_version'. If there are any missing pieces, please add them, but be mindful not to break the flow. All the changes and adds will be placed inside the new folder. Please modify the markdown files, too and add them in the folder changed."

Assistant response summary:
- **Action**: Read all existing C# and SQL files, identified logic bugs, converted the full system to Godot 4 + GDScript inside `godot_version/`.
- **Files created**:
  - `database/database_schema.sql` — Unchanged SQL schema (engine-agnostic SQLite)
  - `database/DatabaseManager.gd` — Autoload singleton, wraps godot-sqlite plugin
  - `database/DatabaseModels.gd` — All data classes as `BattleFleetModels.*` inner classes
  - `database/PlayerRepository.gd` — Player CRUD
  - `database/PlayerStatsRepository.gd` — Stats + player level + fleet level; signals `player_leveled_up`, `fleet_leveled_up`
  - `database/CaptainRepository.gd` — Captain XP, command cards, accuracy bonus; signal `captain_leveled_up`
  - `database/ShipUnlockRepository.gd` — Ship unlock check based on fleet level
  - `database/DatabaseUsageExample.gd` — New: 6 full integration examples
  - `ui/ProgressionBarUI.gd` — Godot Control node: XP bar + ship list
  - `README.md`, `PROJECT_STRUCTURE.md`, `SETUP_GUIDE.md`, `PROMPTS_README.md`
- **Bugs fixed** (from the original C# version):

| File | Bug | Fix |
|---|---|---|
| `DatabaseManager` | Players table missing `FleetLevel`, `FleetXP` | Added both columns |
| `PlayerRepository` | `GetPlayerByID/ByName` didn't read `FleetLevel`/`FleetXP` | Fixed in `_map_player()` |
| `PlayerStatsRepository` | `AwardXpAndLevelUp` used undefined `_db` field | Uses `DatabaseManager` autoload |
| `PlayerStatsRepository` | Wrong table/column names: `players.fleet_xp`, `fleet_level` | Fixed to `Players.FleetXP`, `FleetLevel` |
| `PlayerStatsRepository` | `GetProgressBarData` same naming bugs | Fixed |
| `ShipUnlockRepository` | Snake_case column names don't exist in schema | Fixed to PascalCase |
| `ShipUnlockRepository` | `_db.GetConnection()` doesn't exist | Uses `DatabaseManager` autoload |
| `ProgressionBarUI` | Passed `DatabaseManager db` to repos that use singleton | Removed unused parameter |

---

**Prompt 7 (Claude) — Logic check & prompt update**
"add these prompts inside the PROMPTS_README and then check one more time if the logic is 100% followed and no mistakes were made. look up the original game logic online if needed and only if you have a strong reason, suggest me follow-ups adding/modifications"

Assistant response summary:
- **Action**: Updated PROMPTS_README files. Researched Battle Fleet 2 mechanics online. Performed a full logic pass over all Godot scripts.
- **Verified correct**:
  - Captain XP + accuracy bonus system — confirmed captains have experience in the original game
  - Campaign with Japan faction — confirmed in the original game
  - Accuracy as a core mechanic — confirmed (targeting reticles scale with difficulty)
  - Both XP curves (flat player level, quadratic fleet/captain level) — consistent across all files
  - `INSERT OR IGNORE` for command card unlocks — safe, no duplicate risk
  - `ProgressionBarUI` correctly uses `calculate_fleet_level()` static method
  - All fixed column names match the schema throughout all repositories
- **One follow-up suggested** (see below)

---

## Follow-up: BattleHistory is never populated

**Why this matters (strong reason):** `record_battle_result()` updates the `PlayerStats` aggregates (wins, losses, XP, etc.) but never inserts a row into the `BattleHistory` table. The table and schema exist, the `BattleRecord` model contains all the needed data, but nothing ever writes to it. This means:

- The AI difficulty system (described in the project brief) cannot read individual battle logs
- Analytics on opponent matchups, ship choices, and battle modes are impossible
- Leaderboards only show aggregated stats, not recent match history

**The fix is small** — one `_insert_battle_history()` call inside `record_battle_result()` in `PlayerStatsRepository.gd`:

```gdscript
func record_battle_result(player_id: int, battle: BattleFleetModels.BattleRecord) -> bool:
    # ... existing stats update code ...
    _insert_battle_history(player_id, battle)   # add this line
    return _update_player_stats(stats)

func _insert_battle_history(player_id: int, battle: BattleFleetModels.BattleRecord) -> void:
    DatabaseManager.execute_non_query(
        """INSERT INTO BattleHistory
           (PlayerID, OpponentName, BattleDate, Result,
            ShipsDestroyed, ShipsLost, ExperienceGained, DifficultyLevel, BattleMode)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        [
            player_id,
            battle.opponent_name,
            Time.get_datetime_string_from_system(),
            battle.result,
            battle.ships_destroyed,
            battle.ships_lost,
            battle.experience_gained,
            battle.difficulty_level,
            battle.battle_mode
        ]
    )
```
