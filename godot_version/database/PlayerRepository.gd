# PlayerRepository.gd
# CRUD operations for the Players table.
# FIX (vs Unity version): GetPlayerByID / GetPlayerByName now read FleetLevel and FleetXP.

class_name PlayerRepository
extends RefCounted


func _init() -> void:
	pass  # Uses DatabaseManager autoload singleton directly


# ── CREATE ────────────────────────────────────────────────────────────────────

## Insert a new player and create an associated PlayerStats row.
## Returns the new Player object, or null on failure.
func create_player(player_name: String) -> BattleFleetModels.Player:
	if player_name.strip_edges().is_empty():
		push_error("PlayerRepository: Player name cannot be empty.")
		return null

	if player_exists(player_name):
		push_warning("PlayerRepository: Player '%s' already exists." % player_name)
		return null

	var now := Time.get_datetime_string_from_system()
	var rows_affected := DatabaseManager.execute_non_query(
		"INSERT INTO Players (PlayerName, CreatedDate, IsActive, FleetLevel, FleetXP) VALUES (?, ?, 1, 1, 0)",
		[player_name, now]
	)

	if rows_affected <= 0:
		push_error("PlayerRepository: Failed to insert player '%s'." % player_name)
		return null

	var player_id: int = DatabaseManager.get_last_insert_id()
	_create_player_stats(player_id, now)

	print("PlayerRepository: Created player '%s' (ID: %d)." % [player_name, player_id])
	return get_player_by_id(player_id)


# ── READ ──────────────────────────────────────────────────────────────────────

## Returns a Player by primary key, or null if not found.
func get_player_by_id(player_id: int) -> BattleFleetModels.Player:
	var rows := DatabaseManager.execute_reader(
		"SELECT * FROM Players WHERE PlayerID = ?", [player_id]
	)
	if rows.is_empty():
		return null
	return _map_player(rows[0])


## Returns a Player by name, or null if not found.
func get_player_by_name(player_name: String) -> BattleFleetModels.Player:
	var rows := DatabaseManager.execute_reader(
		"SELECT * FROM Players WHERE PlayerName = ?", [player_name]
	)
	if rows.is_empty():
		return null
	return _map_player(rows[0])


## Returns all players with IsActive = 1, sorted by name.
func get_all_active_players() -> Array:
	var rows := DatabaseManager.execute_reader(
		"SELECT * FROM Players WHERE IsActive = 1 ORDER BY PlayerName ASC"
	)
	var players: Array = []
	for row in rows:
		players.append(_map_player(row))
	return players


# ── UPDATE ────────────────────────────────────────────────────────────────────

## Updates PlayerName, LastPlayedDate and IsActive. Returns true on success.
func update_player(player: BattleFleetModels.Player) -> bool:
	if player == null or player.player_id <= 0:
		push_error("PlayerRepository: Invalid player object.")
		return false

	var result := DatabaseManager.execute_non_query(
		"UPDATE Players SET PlayerName = ?, LastPlayedDate = ?, IsActive = ? WHERE PlayerID = ?",
		[player.player_name, player.last_played_date, (1 if player.is_active else 0), player.player_id]
	)
	return result > 0


## Stamps LastPlayedDate with the current time.
func update_last_played_date(player_id: int) -> bool:
	var result := DatabaseManager.execute_non_query(
		"UPDATE Players SET LastPlayedDate = ? WHERE PlayerID = ?",
		[Time.get_datetime_string_from_system(), player_id]
	)
	return result > 0


# ── DELETE ────────────────────────────────────────────────────────────────────

## Soft delete (default) sets IsActive = 0. Hard delete removes the row entirely.
func delete_player(player_id: int, hard_delete: bool = false) -> bool:
	var result: int
	if hard_delete:
		result = DatabaseManager.execute_non_query(
			"DELETE FROM Players WHERE PlayerID = ?", [player_id]
		)
		if result > 0:
			print("PlayerRepository: Player %d permanently deleted." % player_id)
	else:
		result = DatabaseManager.execute_non_query(
			"UPDATE Players SET IsActive = 0 WHERE PlayerID = ?", [player_id]
		)
		if result > 0:
			print("PlayerRepository: Player %d deactivated." % player_id)
	return result > 0


# ── HELPERS ───────────────────────────────────────────────────────────────────

func player_exists(player_name: String) -> bool:
	var count = DatabaseManager.execute_scalar(
		"SELECT COUNT(*) FROM Players WHERE PlayerName = ?", [player_name]
	)
	return int(count) > 0


func get_player_id_by_name(player_name: String) -> int:
	var result = DatabaseManager.execute_scalar(
		"SELECT PlayerID FROM Players WHERE PlayerName = ? LIMIT 1", [player_name]
	)
	return int(result) if result != null else -1


func get_total_player_count(active_only: bool = true) -> int:
	var query := "SELECT COUNT(*) FROM Players WHERE IsActive = 1" if active_only \
		else "SELECT COUNT(*) FROM Players"
	var result = DatabaseManager.execute_scalar(query)
	return int(result) if result != null else 0


# ── Private ───────────────────────────────────────────────────────────────────

func _create_player_stats(player_id: int, now: String) -> void:
	DatabaseManager.execute_non_query(
		"""INSERT INTO PlayerStats
		   (PlayerID, Level, TotalExperience, TotalBattles,
		    TotalWins, TotalLosses, TotalDraws, LastUpdated)
		   VALUES (?, 1, 0, 0, 0, 0, 0, ?)""",
		[player_id, now]
	)


## FIX: reads FleetLevel and FleetXP which the Unity version omitted.
func _map_player(row: Dictionary) -> BattleFleetModels.Player:
	var p := BattleFleetModels.Player.new()
	p.player_id       = int(row.get("PlayerID", 0))
	p.player_name     = str(row.get("PlayerName", ""))
	p.created_date    = str(row.get("CreatedDate", ""))
	p.last_played_date = str(row.get("LastPlayedDate", ""))
	p.is_active       = int(row.get("IsActive", 1)) == 1
	p.fleet_level     = int(row.get("FleetLevel", 1))
	p.fleet_xp        = int(row.get("FleetXP", 0))
	return p
