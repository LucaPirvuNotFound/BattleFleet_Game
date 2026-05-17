# ShipUnlockRepository.gd
# Checks which ships a player has unlocked based on their fleet level.
#
# FIX (vs Unity version):
#   - Unity code used snake_case column names: "fleet_level", "ship_type",
#     "required_level", "display_name" — none of which match the schema.
#     Schema uses PascalCase: "FleetLevel", "ShipType", "RequiredLevel", "DisplayName".
#   - Unity code used "_db.GetConnection()" which does not exist in DatabaseManager.
#     Fixed to use DatabaseManager autoload (execute_reader / execute_scalar).

class_name ShipUnlockRepository
extends RefCounted


# ── Core unlock check ─────────────────────────────────────────────────────────

## Returns true if the player's FleetLevel meets the ship's RequiredLevel.
func is_ship_unlocked(player_id: int, ship_type: String) -> bool:
	var result = DatabaseManager.execute_scalar(
		"""SELECT CASE WHEN p.FleetLevel >= s.RequiredLevel THEN 1 ELSE 0 END
		   FROM Players p
		   JOIN ShipUnlockRequirements s ON s.ShipType = ?
		   WHERE p.PlayerID = ?""",
		[ship_type, player_id]
	)
	return result != null and int(result) == 1


# ── Full status list (used by fleet selection UI) ─────────────────────────────

## Returns every ship with its unlock status for a given player.
## Use this to populate the ship selection / garage screen.
func get_all_ship_statuses_for_player(player_id: int) -> Array:
	var rows := DatabaseManager.execute_reader(
		"""SELECT
		       s.ShipType,
		       s.DisplayName,
		       s.RequiredLevel,
		       s.Description,
		       CASE WHEN p.FleetLevel >= s.RequiredLevel THEN 1 ELSE 0 END AS IsUnlocked
		   FROM ShipUnlockRequirements s
		   JOIN Players p ON p.PlayerID = ?
		   ORDER BY s.RequiredLevel ASC""",
		[player_id]
	)

	var statuses: Array = []
	for row in rows:
		var status := BattleFleetModels.ShipUnlockStatus.new()
		status.ship_type      = str(row.get("ShipType", ""))
		status.display_name   = str(row.get("DisplayName", ""))
		status.required_level = int(row.get("RequiredLevel", 1))
		status.description    = str(row.get("Description", ""))
		status.is_unlocked    = int(row.get("IsUnlocked", 0)) == 1
		statuses.append(status)

	return statuses


# ── All requirements (used by progression display / tooltips) ─────────────────

## Returns raw unlock threshold definitions, ordered by RequiredLevel.
func get_all_requirements() -> Array:
	var rows := DatabaseManager.execute_reader(
		"SELECT ShipType, RequiredLevel, DisplayName, Description FROM ShipUnlockRequirements ORDER BY RequiredLevel ASC"
	)

	var requirements: Array = []
	for row in rows:
		var req := BattleFleetModels.ShipUnlockRequirement.new()
		req.ship_type      = str(row.get("ShipType", ""))
		req.required_level = int(row.get("RequiredLevel", 1))
		req.display_name   = str(row.get("DisplayName", ""))
		req.description    = str(row.get("Description", ""))
		requirements.append(req)

	return requirements
