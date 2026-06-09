extends GutTest

const FOG_OF_WAR := preload("res://scenes/FogOfWar.tscn")
const VISION_CIRCLE := preload("res://scenes/VisionCircle.tscn")

var _fog
var _ship


func before_each() -> void:
	var result = MapGenerator.build_map(42)
	add_child_autofree(result.root)

	_fog = FOG_OF_WAR.instantiate()
	add_child_autofree(_fog)

	_ship = Node3D.new()
	_ship.name = "TestShip"
	_ship.add_to_group("ships")
	_ship.position = Vector3(200.0, 0.0, -150.0)
	add_child_autofree(_ship)


func after_each() -> void:
	_fog = null
	_ship = null


func test_terrain_group_discovered_by_fog() -> void:
	await wait_frames(1)
	assert_ne(_fog.map_size, 1024.0, "map_size was updated from terrain (not default 1024)")


func test_fog_auto_discovers_ship() -> void:
	_fog._process(0.0)
	assert_has(_fog.active_ships, _ship, "fog registered the ship after _process")


func test_vision_circle_position_matches_ship_world() -> void:
	_fog._process(0.0)

	var res: float = _fog.resolution
	var ms: float = _fog.map_size
	var expected_nx: float = (_ship.global_position.x / ms) + 0.5
	var expected_nz: float = (_ship.global_position.z / ms) + 0.5
	var expected_pos: Vector2 = Vector2(expected_nx * res, expected_nz * res)

	assert_has(_fog.active_ships, _ship, "ship is registered")
	var circle: Node2D = _fog.active_ships[_ship]
	assert_not_null(circle, "vision circle exists")
	assert_eq(circle.position, expected_pos, "circle position matches ship world position")


func test_vision_circle_follows_ship_movement() -> void:
	_fog._process(0.0)
	assert_has(_fog.active_ships, _ship, "ship registered before move")

	_ship.position = Vector3(-300.0, 0.0, 400.0)
	_fog._process(0.0)

	var res: float = _fog.resolution
	var ms: float = _fog.map_size
	var expected_nx: float = (_ship.global_position.x / ms) + 0.5
	var expected_nz: float = (_ship.global_position.z / ms) + 0.5
	var expected_pos: Vector2 = Vector2(expected_nx * res, expected_nz * res)

	var circle: Node2D = _fog.active_ships[_ship]
	assert_eq(circle.position, expected_pos, "circle follows the ship after movement")


func test_removed_ship_cleans_up_circle() -> void:
	_fog._process(0.0)
	assert_has(_fog.active_ships, _ship, "ship registered")

	_ship.queue_free()
	await wait_frames(1)

	assert_does_not_have(_fog.active_ships, _ship, "ship removed from active_ships after _process")
