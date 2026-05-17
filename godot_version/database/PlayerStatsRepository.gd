# PlayerStatsRepository.gd
# Manages PlayerStats (player-level progression) and Fleet-level progression.
#
# Two parallel XP systems exist in this game:
#   1. Player Level  — stored in PlayerStats.Level / TotalExperience
#                      Flat formula: level = total_xp / 1000 + 1
#                      Updated by record_battle_result() and add_experience()
#
#   2. Fleet Level   — stored in Players.FleetLevel / Players.FleetXP
#                      Quadratic formula: each level costs level*100 XP
#                      Updated by award_fleet_xp_and_level_up()
#                      Gates ship unlocks (ShipUnlockRepository reads FleetLevel)
#
# FIX (vs Unity version):
#   - award_fleet_xp_and_level_up() used undefined "_db" field; now uses DatabaseManager
#   - award_fleet_xp_and_level_up() used wrong table "players" / columns "fleet_xp", "fleet_level"
#     (schema uses "Players", "FleetXP", "FleetLevel")
#   - get_progress_bar_data() had the same naming bugs

class_name PlayerStatsRepository
extends RefCounted

signal player_leveled_up(player_id: int, old_level: int, new_level: int)
signal fleet_leveled_up(player_id: int, old_level: int, new_level: int)

const XP_PER_PLAYER_LEVEL := 1000  # Flat curve for the overall player level


# ── READ ──────────────────────────────────────────────────────────────────────

func get_player_stats(player_id: int) -> BattleFleetModels.PlayerStats:
	var rows := DatabaseManager.execute_reader(
		"SELECT * FROM PlayerStats WHERE PlayerID = ?", [player_id]
	)
	if rows.is_empty():
		return null
	return _map_stats(rows[0])


# ── ADD EXPERIENCE (player level) ─────────────────────────────────────────────

## Adds XP to the player's overall level (flat 1000 XP/level curve).
func add_experience(player_id: int, xp: int) -> bool:
	var stats := get_player_stats(player_id)
	if stats == null:
		push_error("PlayerStatsRepository: Stats not found for player %d." % player_id)
		return false

	var prev_level := stats.level
	stats.total_experience += xp
	stats.level = stats.total_experience / XP_PER_PLAYER_LEVEL + 1

	if stats.level > stats.highest_level:
		stats.highest_level = stats.level

	if stats.level > prev_level:
		print("PlayerStatsRepository: Player %d leveled up! %d → %d" % [player_id, prev_level, stats.level])
		emit_signal("player_leveled_up", player_id, prev_level, stats.level)

	return _update_player_stats(stats)


# ── RECORD BATTLE ─────────────────────────────────────────────────────────────

## Records a battle result, updates wins/losses/experience, and recalculates level.
func record_battle_result(player_id: int, battle: BattleFleetModels.BattleRecord) -> bool:
	var stats := get_player_stats(player_id)
	if stats == null:
		push_error("PlayerStatsRepository: Stats not found for player %d." % player_id)
		return false

	stats.total_battles += 1
	match battle.result:
		"Win":  stats.total_wins   += 1
		"Loss": stats.total_losses += 1
		"Draw": stats.total_draws  += 1

	stats.total_ships_destroyed += battle.ships_destroyed
	stats.total_ships_lost      += battle.ships_lost
	stats.total_experience      += battle.experience_gained

	var prev_level := stats.level
	stats.level = stats.total_experience / XP_PER_PLAYER_LEVEL + 1
	if stats.level > stats.highest_level:
		stats.highest_level = stats.level

	if stats.level > prev_level:
		print("PlayerStatsRepository: Player %d leveled up! %d → %d" % [player_id, prev_level, stats.level])
		emit_signal("player_leveled_up", player_id, prev_level, stats.level)

	stats.last_updated = Time.get_datetime_string_from_system()
	_insert_battle_history(player_id, battle)
	return _update_player_stats(stats)


# ── ACCURACY ──────────────────────────────────────────────────────────────────

func update_accuracy(player_id: int, total_shots: int, successful_shots: int) -> bool:
	if total_shots <= 0:
		push_warning("PlayerStatsRepository: total_shots must be > 0.")
		return false

	var stats := get_player_stats(player_id)
	if stats == null:
		push_error("PlayerStatsRepository: Stats not found for player %d." % player_id)
		return false

	var base: float = stats.average_accuracy * max(stats.total_battles - 1, 0)
	var new_shot_accuracy: float = float(successful_shots) / float(total_shots)
	stats.average_accuracy = (base + new_shot_accuracy) / max(stats.total_battles, 1)
	return _update_player_stats(stats)


# ── CAMPAIGN PROGRESS ─────────────────────────────────────────────────────────

func update_campaign_progress(player_id: int, progress_pct: float) -> bool:
	if progress_pct < 0.0 or progress_pct > 100.0:
		push_warning("PlayerStatsRepository: progress_pct must be 0-100.")
		return false

	var stats := get_player_stats(player_id)
	if stats == null:
		push_error("PlayerStatsRepository: Stats not found for player %d." % player_id)
		return false

	stats.campaign_progress_percentage = progress_pct
	return _update_player_stats(stats)


# ── LEADERBOARDS ──────────────────────────────────────────────────────────────

func get_top_players_by_level(top_count: int = 10) -> Array:
	var rows := DatabaseManager.execute_reader(
		"SELECT * FROM PlayerStats ORDER BY Level DESC, TotalExperience DESC LIMIT ?",
		[top_count]
	)
	var result: Array = []
	for row in rows:
		result.append(_map_stats(row))
	return result


func get_top_players_by_win_rate(top_count: int = 10) -> Array:
	var rows := DatabaseManager.execute_reader(
		"""SELECT * FROM PlayerStats
		   WHERE TotalBattles > 0
		   ORDER BY (CAST(TotalWins AS FLOAT) / TotalBattles) DESC, TotalBattles DESC
		   LIMIT ?""",
		[top_count]
	)
	var result: Array = []
	for row in rows:
		result.append(_map_stats(row))
	return result


## Returns 1-based rank of the player (1 = best).
func get_player_rank(player_id: int, by_win_rate: bool = false) -> int:
	var count: Variant
	if by_win_rate:
		count = DatabaseManager.execute_scalar(
			"""SELECT COUNT(*) FROM PlayerStats
			   WHERE (CAST(TotalWins AS FLOAT) / NULLIF(TotalBattles, 0)) >
			         (SELECT CAST(TotalWins AS FLOAT) / NULLIF(TotalBattles, 0)
			          FROM PlayerStats WHERE PlayerID = ?)""",
			[player_id]
		)
	else:
		count = DatabaseManager.execute_scalar(
			"""SELECT COUNT(*) FROM PlayerStats
			   WHERE Level > (SELECT Level FROM PlayerStats WHERE PlayerID = ?)
			      OR (Level = (SELECT Level FROM PlayerStats WHERE PlayerID = ?)
			         AND TotalExperience > (SELECT TotalExperience FROM PlayerStats WHERE PlayerID = ?))""",
			[player_id, player_id, player_id]
		)
	return int(count) + 1  # 1-indexed


func get_experience_for_next_level(current_level: int) -> int:
	return current_level * XP_PER_PLAYER_LEVEL


func get_remaining_experience_for_level(player_id: int) -> int:
	var stats := get_player_stats(player_id)
	if stats == null:
		return 0
	var next_xp := get_experience_for_next_level(stats.level)
	return max(next_xp - stats.total_experience, 0)


# ── FLEET LEVEL (quadratic curve, gates ship unlocks) ─────────────────────────

## Awards fleet XP to a player and handles level-up automatically.
## Returns the new fleet level. Emits fleet_leveled_up signal on level change.
##
## FIX: Unity version used undefined "_db" field, wrong table "players" and
##      snake_case columns "fleet_xp"/"fleet_level". Fixed to use DatabaseManager
##      and the correct PascalCase column names from the schema.
func award_fleet_xp_and_level_up(player_id: int, xp_gained: int) -> int:
	var rows := DatabaseManager.execute_reader(
		"SELECT FleetXP, FleetLevel FROM Players WHERE PlayerID = ?", [player_id]
	)
	if rows.is_empty():
		push_error("PlayerStatsRepository: Player %d not found." % player_id)
		return -1

	var current_xp: int    = int(rows[0].get("FleetXP", 0))
	var current_level: int = int(rows[0].get("FleetLevel", 1))

	var new_xp: int    = current_xp + xp_gained
	var new_level: int = calculate_fleet_level(new_xp)

	DatabaseManager.execute_non_query(
		"UPDATE Players SET FleetXP = ?, FleetLevel = ? WHERE PlayerID = ?",
		[new_xp, new_level, player_id]
	)

	if new_level > current_level:
		print("PlayerStatsRepository: Player %d fleet leveled up! %d → %d" % [player_id, current_level, new_level])
		emit_signal("fleet_leveled_up", player_id, current_level, new_level)

	return new_level


## Returns (total_xp, xp_at_level_start, xp_at_level_end) for a fleet progress bar.
## Used by ProgressionBarUI.
##
## FIX: Unity version used undefined "_db" field, wrong table and column names.
func get_progress_bar_data(player_id: int) -> Dictionary:
	var rows := DatabaseManager.execute_reader(
		"SELECT FleetXP, FleetLevel FROM Players WHERE PlayerID = ?", [player_id]
	)
	if rows.is_empty():
		return {"total_xp": 0, "xp_start": 0, "xp_end": 100}

	var total_xp: int = int(rows[0].get("FleetXP", 0))
	var level: int    = int(rows[0].get("FleetLevel", 1))

	var xp_start: int = 0
	for l in range(1, level):
		xp_start += l * 100
	var xp_end: int = xp_start + level * 100

	return {"total_xp": total_xp, "xp_start": xp_start, "xp_end": xp_end}


## Quadratic XP curve: level N costs N*100 XP on top of the previous total.
## Level 1 = 0 XP | Level 2 = 100 | Level 3 = 300 | Level 4 = 600 …
## Mirrors CaptainRepository.calculate_captain_level — keep in sync if you change the curve.
static func calculate_fleet_level(total_xp: int) -> int:
	var level: int    = 1
	var xp_needed: int = 0
	while total_xp >= xp_needed + level * 100:
		xp_needed += level * 100
		level     += 1
	return level


# ── RESET (admin / debug) ─────────────────────────────────────────────────────

func reset_player_stats(player_id: int) -> bool:
	var result := DatabaseManager.execute_non_query(
		"""UPDATE PlayerStats
		   SET Level = 1, TotalExperience = 0, TotalBattles = 0,
		       TotalWins = 0, TotalLosses = 0, TotalDraws = 0,
		       AverageAccuracy = 0.0, TotalShipsDestroyed = 0, TotalShipsLost = 0,
		       CampaignProgressPercentage = 0.0, HighestLevel = 1,
		       LastUpdated = ?
		   WHERE PlayerID = ?""",
		[Time.get_datetime_string_from_system(), player_id]
	)
	if result > 0:
		print("PlayerStatsRepository: Stats reset for player %d." % player_id)
	return result > 0


# ── Private ───────────────────────────────────────────────────────────────────

func _update_player_stats(stats: BattleFleetModels.PlayerStats) -> bool:
	var result := DatabaseManager.execute_non_query(
		"""UPDATE PlayerStats
		   SET Level = ?, TotalExperience = ?, TotalBattles = ?,
		       TotalWins = ?, TotalLosses = ?, TotalDraws = ?,
		       AverageAccuracy = ?, TotalShipsDestroyed = ?, TotalShipsLost = ?,
		       CampaignProgressPercentage = ?, HighestLevel = ?, LastUpdated = ?
		   WHERE PlayerID = ?""",
		[
			stats.level, stats.total_experience, stats.total_battles,
			stats.total_wins, stats.total_losses, stats.total_draws,
			stats.average_accuracy, stats.total_ships_destroyed, stats.total_ships_lost,
			stats.campaign_progress_percentage, stats.highest_level,
			Time.get_datetime_string_from_system(), stats.player_id
		]
	)
	return result > 0


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


func _map_stats(row: Dictionary) -> BattleFleetModels.PlayerStats:
	var s := BattleFleetModels.PlayerStats.new()
	s.stat_id                      = int(row.get("StatID", 0))
	s.player_id                    = int(row.get("PlayerID", 0))
	s.level                        = int(row.get("Level", 1))
	s.total_experience             = int(row.get("TotalExperience", 0))
	s.total_battles                = int(row.get("TotalBattles", 0))
	s.total_wins                   = int(row.get("TotalWins", 0))
	s.total_losses                 = int(row.get("TotalLosses", 0))
	s.total_draws                  = int(row.get("TotalDraws", 0))
	s.average_accuracy             = float(row.get("AverageAccuracy", 0.0))
	s.total_ships_destroyed        = int(row.get("TotalShipsDestroyed", 0))
	s.total_ships_lost             = int(row.get("TotalShipsLost", 0))
	s.campaign_progress_percentage = float(row.get("CampaignProgressPercentage", 0.0))
	s.highest_level                = int(row.get("HighestLevel", 1))
	s.last_updated                 = str(row.get("LastUpdated", ""))
	return s
