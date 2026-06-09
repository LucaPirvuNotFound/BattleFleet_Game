extends RefCounted
class_name MapGenerator

const WATER_SCENE := preload("res://scenes/WaterPlane.tscn")
const TERRAIN_SCENE := preload("res://scenes/Terrain.tscn")

## Same layout as res://scenes/Map.tscn (water + procedural terrain).
const WATER_TRANSFORM := Transform3D(
	Vector3(5000.0, 0.0, 0.0),
	Vector3(0.0, 1.0, 0.0),
	Vector3(0.0, 0.0, 5000.0),
	Vector3(0.0, -2.0, 0.0)
)
const TERRAIN_TRANSFORM := Transform3D(
	Vector3(0.9988981, 0.0, 0.0),
	Vector3(0.0, 0.9988981, 0.0),
	Vector3(0.0, 0.0, 0.9988981),
	Vector3.ZERO
)


## Returns { "root": Node3D, "terrain": MeshInstance3D, "water": Node3D }
static func build_map(map_seed: int) -> Dictionary:
	var map_root := Node3D.new()
	map_root.name = "Map"

	var water: Node3D = WATER_SCENE.instantiate()
	water.name = "WaterPlane"
	water.transform = WATER_TRANSFORM
	map_root.add_child(water)

	var terrain := build_terrain(map_seed)
	terrain.name = "Terrain"
	terrain.transform = TERRAIN_TRANSFORM
	map_root.add_child(terrain)

	return {
		"root": map_root,
		"terrain": terrain,
		"water": water,
	}


## Terrain only — uses existing Terrain.gd (noise + update_mesh); script is not modified.
static func build_terrain(map_seed: int) -> MeshInstance3D:
	var terrain: MeshInstance3D = TERRAIN_SCENE.instantiate()
	if terrain.noise:
		var noise: FastNoiseLite = terrain.noise.duplicate()
		noise.seed = map_seed
		terrain.noise = noise
	terrain.update_mesh()
	return terrain
