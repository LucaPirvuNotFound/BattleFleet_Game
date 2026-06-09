extends RefCounted
class_name PlacementGenerator

const GRID_MAX := 127
const SLOT_0_X_MAX := 63
const SLOT_1_X_MIN := 64
const MAX_PLACEMENT_ATTEMPTS := 200
const MIN_CELL_SPACING := 3
## Terrain height at or below this value is deep enough water for ships.
const WATER_HEIGHT_MAX := -1.0

static func generate_fleet_placements(
	terrain: MeshInstance3D,
	fleet: Array,
	slot: int,
	rng: RandomNumberGenerator
) -> Array:
	var placements: Array = []
	var occupied: Array[Vector2i] = []

	for ship_index in fleet.size():
		var placement: Dictionary = _place_single_ship(terrain, slot, ship_index, fleet, occupied, rng)
		if placement.is_empty():
			push_warning("PlacementGenerator: fallback grid placement for ship %d slot %d" % [ship_index, slot])
			placement = _fallback_placement(slot, ship_index, fleet, occupied)
		placements.append(placement)
		occupied.append(Vector2i(int(placement["x"]), int(placement["y"])))

	return placements


static func _ship_name_at(fleet: Array, ship_index: int) -> String:
	if ship_index >= 0 and ship_index < fleet.size() and fleet[ship_index] is Dictionary:
		return str(fleet[ship_index].get("name", "Destroyer"))
	return "Destroyer"


static func _place_single_ship(
	terrain: MeshInstance3D,
	slot: int,
	ship_index: int,
	fleet: Array,
	occupied: Array[Vector2i],
	rng: RandomNumberGenerator
) -> Dictionary:
	for _attempt in MAX_PLACEMENT_ATTEMPTS:
		var x := _random_x_for_slot(slot, rng)
		var y := rng.randi_range(0, GRID_MAX)
		var rotation := rng.randi_range(0, 3)
		var cell := Vector2i(x, y)
		if not _is_cell_available(terrain, cell, occupied):
			continue
		return {
			"ship_index": ship_index,
			"ship_name": _ship_name_at(fleet, ship_index),
			"x": x,
			"y": y,
			"rotation": rotation,
		}
	return {}


static func _fallback_placement(slot: int, ship_index: int, fleet: Array, occupied: Array[Vector2i]) -> Dictionary:
	var x_start := 0 if slot == 0 else SLOT_1_X_MIN
	var x_end := SLOT_0_X_MAX if slot == 0 else GRID_MAX
	for x in range(x_start, x_end + 1, MIN_CELL_SPACING):
		for y in range(0, GRID_MAX + 1, MIN_CELL_SPACING):
			var cell := Vector2i(x, y)
			if _is_far_enough(cell, occupied):
				return {
					"ship_index": ship_index,
					"ship_name": _ship_name_at(fleet, ship_index),
					"x": x,
					"y": y,
					"rotation": 0,
				}
	return {
		"ship_index": ship_index,
		"ship_name": _ship_name_at(fleet, ship_index),
		"x": x_start + ship_index * MIN_CELL_SPACING,
		"y": 0,
		"rotation": 0,
	}


static func _random_x_for_slot(slot: int, rng: RandomNumberGenerator) -> int:
	if slot == 0:
		return rng.randi_range(0, SLOT_0_X_MAX)
	return rng.randi_range(SLOT_1_X_MIN, GRID_MAX)


static func _is_cell_available(
	terrain: MeshInstance3D,
	cell: Vector2i,
	occupied: Array[Vector2i]
) -> bool:
	if not _is_water_cell(terrain, cell):
		return false
	return _is_far_enough(cell, occupied)


static func _is_far_enough(cell: Vector2i, occupied: Array[Vector2i]) -> bool:
	for other in occupied:
		if cell.distance_to(other) < float(MIN_CELL_SPACING):
			return false
	return true


static func _is_water_cell(terrain: MeshInstance3D, cell: Vector2i) -> bool:
	if terrain == null or not terrain.has_method("get_height"):
		return true
	var world := grid_to_world(terrain, cell)
	return terrain.get_height(world.x, world.z) <= WATER_HEIGHT_MAX


static func grid_to_world(terrain: MeshInstance3D, cell: Vector2i) -> Vector3:
	var map_size := 256.0
	if terrain.has_method("get"):
		map_size = float(terrain.get("size"))
	var half := map_size * 0.5
	var world_x := (float(cell.x) / float(GRID_MAX)) * map_size - half
	var world_z := (float(cell.y) / float(GRID_MAX)) * map_size - half
	return Vector3(world_x, 0.0, world_z)
