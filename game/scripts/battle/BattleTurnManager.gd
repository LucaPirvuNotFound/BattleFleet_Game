extends RefCounted
class_name BattleTurnManager

## Per-round ship limits: one move, one shot per weapon.


static func init_ship_round_state(ship: Dictionary) -> void:
	ship["round_moved"] = false
	ship["round_actions"] = []
	var weapons: Array = ship.get("weapons", [])
	ship["weapons_remaining"] = weapons.duplicate()


static func reset_fleet_for_round(ships: Array) -> void:
	for ship in ships:
		if ship is Dictionary:
			init_ship_round_state(ship)


static func can_move(ship: Dictionary) -> bool:
	return not bool(ship.get("round_moved", false))


static func can_fire_any(ship: Dictionary) -> bool:
	var remaining: Array = ship.get("weapons_remaining", [])
	return not remaining.is_empty()


static func can_fire_weapon(ship: Dictionary, weapon_name: String) -> bool:
	var remaining: Array = ship.get("weapons_remaining", [])
	return remaining.has(weapon_name)


static func mark_moved(ship: Dictionary, angle: float, distance: float) -> void:
	ship["round_moved"] = true
	var actions: Array = ship.get("round_actions", [])
	actions.append({
		"type": "move",
		"angle": angle,
		"distance": distance,
	})
	ship["round_actions"] = actions


static func mark_fired(ship: Dictionary, weapon_name: String) -> bool:
	if not can_fire_weapon(ship, weapon_name):
		return false
	var remaining: Array = ship.get("weapons_remaining", [])
	remaining.erase(weapon_name)
	ship["weapons_remaining"] = remaining
	var actions: Array = ship.get("round_actions", [])
	actions.append({
		"type": "fire",
		"weapon": weapon_name,
	})
	ship["round_actions"] = actions
	return true


static func build_turn_package(
	match_id: String,
	round_number: int,
	player_username: String,
	ships: Array
) -> Dictionary:
	var ship_states: Array = []
	for ship in ships:
		if not ship is Dictionary:
			continue
		var marker: Node3D = ship.get("marker")
		var rotation_steps := 0
		if marker:
			rotation_steps = int(round(marker.rotation_degrees.y / 90.0)) % 4
		var world: Vector3 = ship.get("world_pos", Vector3.ZERO)
		ship_states.append({
			"ship_index": int(ship.get("ship_index", -1)),
			"name": str(ship.get("name", "")),
			"display_name": str(ship.get("display_name", "")),
			"hp": int(ship.get("hp", 0)),
			"max_hp": int(ship.get("max_hp", 0)),
			"position": {
				"x": snappedf(world.x, 0.01),
				"y": snappedf(world.y, 0.01),
				"z": snappedf(world.z, 0.01),
				"rotation": rotation_steps,
			},
			"moved": bool(ship.get("round_moved", false)),
			"weapons_remaining": ship.get("weapons_remaining", []).duplicate(),
			"actions": ship.get("round_actions", []).duplicate(),
		})

	return {
		"match_id": match_id,
		"round": round_number,
		"phase": "player_turn_end",
		"player": player_username,
		"ships": ship_states,
	}
