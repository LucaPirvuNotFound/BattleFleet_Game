extends RefCounted
class_name BattleTurnManager

## Per-round ship limits: one move, one shot per weapon.

const MAX_MOVE_DISTANCE := 90.0
const MOVE_ANGLE_MIN := -180.0
const MOVE_ANGLE_MAX := 180.0

const WEAPON_STATS: Dictionary = {
	"Light Cannon": {
		"max_range": 200.0,
		"min_range": 20.0,
		"damage": 25,
		"aoe_radius": 18.0,
	},
	"Anti-Air": {
		"max_range": 150.0,
		"min_range": 10.0,
		"damage": 20,
		"aoe_radius": 14.0,
	},
	"Torpedoes": {
		"max_range": 120.0,
		"min_range": 15.0,
		"damage": 40,
		"aoe_radius": 22.0,
	},
	"Heavy Battery": {
		"max_range": 300.0,
		"min_range": 40.0,
		"damage": 55,
		"aoe_radius": 28.0,
	},
}


static func get_weapon_stats(weapon_name: String) -> Dictionary:
	var defaults := {
		"max_range": 200.0,
		"min_range": 0.0,
		"damage": 20,
		"aoe_radius": 16.0,
	}
	var stats: Dictionary = WEAPON_STATS.get(weapon_name, defaults)
	return {
		"max_range": float(stats.get("max_range", defaults.max_range)),
		"min_range": float(stats.get("min_range", defaults.min_range)),
		"damage": int(stats.get("damage", defaults.damage)),
		"aoe_radius": float(stats.get("aoe_radius", defaults.aoe_radius)),
	}


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


static func mark_fired(ship: Dictionary, weapon_name: String, angle: float = 0.0, distance: float = 0.0) -> bool:
	if not can_fire_weapon(ship, weapon_name):
		return false
	var remaining: Array = ship.get("weapons_remaining", [])
	remaining.erase(weapon_name)
	ship["weapons_remaining"] = remaining
	var actions: Array = ship.get("round_actions", [])
	var action := {
		"type": "fire",
		"weapon": weapon_name,
		"angle": angle,
		"distance": distance,
	}
	actions.append(action)
	ship["round_actions"] = actions
	return true


static func build_turn_package(
	match_id: String,
	round_number: int,
	player_username: String,
	ships: Array
) -> Dictionary:
	return {
		"match_id": match_id,
		"round": round_number,
		"phase": "player_turn_end",
		"player": player_username,
		"ships": serialize_fleet(ships),
	}


static func build_ai_turn_request(context: Dictionary) -> Dictionary:
	var human_fleet: Array = context.get("human_fleet", [])
	var ai_fleet: Array = context.get("ai_fleet", [])
	var fog: FogOfWar = context.get("fog_of_war")
	var ai_observers: Array = []
	for ship in ai_fleet:
		var marker: Node3D = ship.get("marker")
		if marker:
			ai_observers.append(marker)

	var visible_human: Array = []
	var hidden_human_count := 0
	for ship in human_fleet:
		var serialized := serialize_ship(ship)
		var marker: Node3D = ship.get("marker")
		var world: Vector3 = ship.get("world_pos", Vector3.ZERO)
		var visible := true
		if fog and marker:
			visible = fog.is_visible_from_observers(world, ai_observers)
		serialized["visible_to_ai"] = visible
		if visible:
			visible_human.append(serialized)
		else:
			hidden_human_count += 1

	return {
		"match_id": str(context.get("match_id", "")),
		"round": int(context.get("round", 1)),
		"phase": "request_ai_turn",
		"mode": str(context.get("mode", "pve")),
		"human_player": str(context.get("human_player", "")),
		"ai_player": str(context.get("ai_player", "")),
		"map": {
			"seed": int(context.get("map_seed", 0)),
			"size": snappedf(float(context.get("map_size", 1024.0)), 0.01),
			"grid_max": PlacementGenerator.GRID_MAX,
			"water_surface_y": snappedf(float(context.get("water_surface_y", 1.6)), 0.01),
		},
		"rules": {
		"max_move_distance": MAX_MOVE_DISTANCE,
		"min_move_distance": -MAX_MOVE_DISTANCE,
		"move_angle_min": MOVE_ANGLE_MIN,
		"move_angle_max": MOVE_ANGLE_MAX,
		"move_angle_inverted_in_battle": true,
			"moves_per_ship_per_round": 1,
			"shots_per_weapon_per_round": 1,
			"move_angle_relative_to_heading": true,
			"coordinate_system": {
				"world_origin": "map_center",
				"heading_rotation_steps": "0=north(-Z), 1=west(-X), 2=south(+Z), 3=east(+X)",
				"angle_convention": "0=ahead, negative=port, positive=starboard",
			},
		},
		"fog_of_war": {
			"vision_radius": snappedf(float(context.get("vision_radius", 0.0)), 0.01),
			"ai_uses_fog": true,
			"human_ships_hidden_from_ai": hidden_human_count,
		},
		"weapons": _serialize_weapon_catalog(),
		"human_turn": {
			"player": str(context.get("human_player", "")),
			"fleet": serialize_fleet(human_fleet),
		},
		"ai_fleet": serialize_fleet(ai_fleet),
		"visible_human_ships": visible_human,
	}


static func serialize_fleet(ships: Array) -> Array:
	var result: Array = []
	for ship in ships:
		if ship is Dictionary:
			result.append(serialize_ship(ship))
	return result


static func serialize_ship(ship: Dictionary) -> Dictionary:
	var marker: Node3D = ship.get("marker")
	var heading_deg := 0.0
	var rotation_steps := 0
	if marker:
		heading_deg = snappedf(marker.rotation_degrees.y, 0.01)
		rotation_steps = int(round(marker.rotation_degrees.y / 90.0)) % 4
	var world: Vector3 = ship.get("world_pos", Vector3.ZERO)
	var weapons: Array = ship.get("weapons", [])
	var remaining: Array = ship.get("weapons_remaining", weapons)
	var weapon_entries: Array = []
	for weapon_name in weapons:
		var wname := str(weapon_name)
		var stats := get_weapon_stats(wname)
		weapon_entries.append({
			"name": wname,
			"max_range": stats.get("max_range", 200.0),
			"min_range": stats.get("min_range", 0.0),
			"damage": stats.get("damage", 20),
			"aoe_radius": stats.get("aoe_radius", 16.0),
			"available": remaining.has(wname),
		})

	return {
		"ship_index": int(ship.get("ship_index", -1)),
		"name": str(ship.get("name", "")),
		"display_name": str(ship.get("display_name", "")),
		"hp": int(ship.get("hp", 0)),
		"max_hp": int(ship.get("max_hp", 0)),
		"position": {
			"x": snappedf(world.x, 0.01),
			"y": snappedf(world.y, 0.01),
			"z": snappedf(world.z, 0.01),
			"heading_degrees": heading_deg,
			"rotation": rotation_steps,
		},
		"can_move": can_move(ship),
		"can_fire": can_fire_any(ship),
		"weapons": weapon_entries,
		"actions_this_round": ship.get("round_actions", []).duplicate(),
	}


static func _serialize_weapon_catalog() -> Array:
	var catalog: Array = []
	for weapon_name in WEAPON_STATS.keys():
		var stats := get_weapon_stats(weapon_name)
		catalog.append({
			"name": weapon_name,
			"max_range": stats.get("max_range", 0.0),
			"min_range": stats.get("min_range", 0.0),
			"damage": stats.get("damage", 0),
			"aoe_radius": stats.get("aoe_radius", 0.0),
		})
	return catalog
