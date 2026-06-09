extends GutTest

func test_build_map_returns_dict_with_expected_keys() -> void:
	var result = MapGenerator.build_map(42)
	assert_true(result.has("root"), "result has 'root' key")
	assert_true(result.has("terrain"), "result has 'terrain' key")
	assert_true(result.has("water"), "result has 'water' key")


func test_build_map_root_is_node3d() -> void:
	var result = MapGenerator.build_map(42)
	assert_not_null(result.root, "root is not null")
	assert_eq(result.root.name, "Map", "root node is named 'Map'")


func test_build_map_terrain_is_meshinstance3d() -> void:
	var result = MapGenerator.build_map(42)
	assert_not_null(result.terrain, "terrain is not null")
	assert_true(result.terrain is MeshInstance3D, "terrain is a MeshInstance3D")


func test_build_map_water_is_node3d() -> void:
	var result = MapGenerator.build_map(42)
	assert_not_null(result.water, "water is not null")
	assert_eq(result.water.name, "WaterPlane", "water node is named 'WaterPlane'")


func test_build_map_terrain_has_noise() -> void:
	var result = MapGenerator.build_map(42)
	assert_not_null(result.terrain.noise, "terrain has noise")


func test_build_map_different_seeds_different_terrain() -> void:
	var a = MapGenerator.build_map(1).terrain
	var b = MapGenerator.build_map(2).terrain
	var noise_a = a.noise
	var noise_b = b.noise
	assert_ne(noise_a.seed, noise_b.seed, "different seeds produce different noise objects")


func test_build_map_same_seed_same_noise() -> void:
	var a = MapGenerator.build_map(42).terrain.noise
	var b = MapGenerator.build_map(42).terrain.noise
	assert_eq(a.seed, b.seed, "same seed produces same noise seed")
	var ha = a.get_noise_2d(100.0, 200.0)
	var hb = b.get_noise_2d(100.0, 200.0)
	assert_eq(ha, hb, "same seed produces identical noise values")


func test_build_terrain_static() -> void:
	var t = MapGenerator.build_terrain(42)
	assert_not_null(t, "build_terrain returns a node")
	assert_true(t is MeshInstance3D, "build_terrain returns MeshInstance3D")
