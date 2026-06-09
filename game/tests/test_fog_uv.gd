extends GutTest

var map_size := 1024.0

func _uv(world_x: float, world_z: float) -> Vector2:
	var nx = (world_x / map_size) + 0.5
	var nz = (world_z / map_size) + 0.5
	return Vector2(nx, nz)


func test_origin_maps_to_center() -> void:
	var uv = _uv(0.0, 0.0)
	assert_eq(uv.x, 0.5, "origin x maps to 0.5")
	assert_eq(uv.y, 0.5, "origin z maps to 0.5")


func test_positive_edge_maps_to_one() -> void:
	var half = map_size * 0.5
	var uv = _uv(half, half)
	assert_eq(uv.x, 1.0, "positive x edge maps to 1.0")
	assert_eq(uv.y, 1.0, "positive z edge maps to 1.0")


func test_negative_edge_maps_to_zero() -> void:
	var half = map_size * 0.5
	var uv = _uv(-half, -half)
	assert_eq(uv.x, 0.0, "negative x edge maps to 0.0")
	assert_eq(uv.y, 0.0, "negative z edge maps to 0.0")


func test_ship_position_matches_uv() -> void:
	var world_pos := Vector2(200.0, -150.0)
	var uv = _uv(world_pos.x, world_pos.y)
	var res := 512.0
	var vp_pixel_x = uv.x * res
	var vp_pixel_y = uv.y * res
	var expected_nx = (world_pos.x / map_size) + 0.5
	var expected_nz = (world_pos.y / map_size) + 0.5
	assert_eq(uv.x, expected_nx, "uv.x matches expected nx")
	assert_eq(uv.y, expected_nz, "uv.y matches expected nz")


func test_clamped_uv_outside_map() -> void:
	var outside := 2000.0
	var uv = _uv(outside, outside)
	var clamped := Vector2(clamp(uv.x, 0.0, 1.0), clamp(uv.y, 0.0, 1.0))
	assert_eq(clamped.x, 1.0, "outside x clamps to 1.0")
	assert_eq(clamped.y, 1.0, "outside z clamps to 1.0")
	uv = _uv(-outside, -outside)
	clamped = Vector2(clamp(uv.x, 0.0, 1.0), clamp(uv.y, 0.0, 1.0))
	assert_eq(clamped.x, 0.0, "outside -x clamps to 0.0")
	assert_eq(clamped.y, 0.0, "outside -z clamps to 0.0")
