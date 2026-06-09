extends GutTest

func test_get_height_consistent() -> void:
	var terrain = MapGenerator.build_terrain(42)
	var h1 = terrain.get_height(50.0, 100.0)
	var h2 = terrain.get_height(50.0, 100.0)
	assert_eq(h1, h2, "get_height returns identical values for identical input")


func test_get_height_different_positions_different_values() -> void:
	var terrain = MapGenerator.build_terrain(42)
	var h1 = terrain.get_height(0.0, 0.0)
	var h2 = terrain.get_height(200.0, -150.0)
	assert_ne(h1, h2, "different positions give different heights (highly likely)")


func test_get_height_range() -> void:
	var terrain = MapGenerator.build_terrain(42)
	var h = terrain.get_height(0.0, 0.0)
	assert_between(h, -terrain.height, terrain.height, "height is within [-height, height]")


func test_get_normal_returns_vector() -> void:
	var terrain = MapGenerator.build_terrain(42)
	var n = terrain.get_normal(0.0, 0.0)
	assert_not_null(n, "get_normal returns a Vector3")
	assert_gt(n.length(), 0.0, "normal has non-zero length")
