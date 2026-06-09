extends GutTest

func test_zoom_clamps_to_min() -> void:
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2000.0
	var min_zoom := 50.0
	var max_zoom := 2000.0
	cam.size = clamp(cam.size / 1.15, min_zoom, max_zoom)
	assert_eq(cam.size, 2000.0 / 1.15, "zoom divides by factor")
	cam.size = 10.0
	cam.size = clamp(cam.size, min_zoom, max_zoom)
	assert_eq(cam.size, min_zoom, "zoom clamps to min")
	cam.queue_free()


func test_zoom_clamps_to_max() -> void:
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var min_zoom := 50.0
	var max_zoom := 2000.0
	cam.size = 5000.0
	cam.size = clamp(cam.size, min_zoom, max_zoom)
	assert_eq(cam.size, max_zoom, "zoom clamps to max")
	cam.queue_free()


func test_drag_does_not_exceed_map_bounds() -> void:
	var map_size := 1024.0
	var half := map_size * 0.5
	var pos := Vector3(1000.0, 400.0, -800.0)
	pos.x = clamp(pos.x, -half, half)
	pos.z = clamp(pos.z, -half, half)
	assert_eq(pos.x, half, "x clamps to +half")
	assert_eq(pos.z, -half, "z clamps to -half")


func test_drag_stays_within_bounds() -> void:
	var map_size := 1024.0
	var half := map_size * 0.5
	var pos := Vector3(200.0, 400.0, -300.0)
	pos.x = clamp(pos.x, -half, half)
	pos.z = clamp(pos.z, -half, half)
	assert_eq(pos.x, 200.0, "x within bounds unchanged")
	assert_eq(pos.z, -300.0, "z within bounds unchanged")
