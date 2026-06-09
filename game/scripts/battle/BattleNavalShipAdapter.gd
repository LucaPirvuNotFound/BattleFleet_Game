extends NavalShip3D
class_name BattleNavalShipAdapter

## Battle movement with inverted compass heading, reverse distance, collisions, and map-border turn.

signal movement_collision(kind: String, damage: int, other_ship_index: int, other_team: String)

const LAND_HEIGHT_MAX := -1.0
const SHIP_CONTACT_RADIUS := 36.0
const SEPARATION_MARGIN := 8.0
const TERRAIN_DAMAGE := 15
const SHIP_COLLISION_DAMAGE := 20
const BORDER_TURN_DONE_THRESHOLD := 0.08
const BORDER_INSET := 14.0
const WATER_SURFACE_Y := 1.6

var ship_index: int = -1
var terrain: MeshInstance3D
var map_half_size: float = 512.0
var collision_report: Callable

var _move_direction_sign: float = 1.0
var _border_turn_active: bool = false
var _border_turn_target: Quaternion
var _border_resume_distance: float = 0.0


func _ready() -> void:
	add_to_group("battle_ships")
	_hide_placeholder_meshes()


func configure_from_marker(marker: Node3D) -> void:
	global_position = marker.global_position
	rotation.y = marker.rotation.y
	_hide_placeholder_meshes()


func configure_battle(ship_index_in: int, terrain_mesh: MeshInstance3D, map_size: float) -> void:
	ship_index = ship_index_in
	terrain = terrain_mesh
	map_half_size = map_size * 0.5


func force_stop_movement() -> void:
	is_moving = false
	_border_turn_active = false


func set_movement_target(angle: float, distance: float) -> void:
	current_angle = -angle
	_move_direction_sign = 1.0 if distance >= 0.0 else -1.0
	move_distance = clampf(absf(distance), 0.0, max_movement_distance)
	distance_traveled = 0.0

	var absolute_angle := rotation.y + deg_to_rad(-angle)
	target_rotation = Quaternion.from_euler(Vector3(0, absolute_angle, 0))
	_border_turn_active = false

	if _is_on_land(global_position):
		_push_off_land()
	var stuck_ship := _find_ship_contact()
	if stuck_ship != null:
		_push_away_from(stuck_ship)

	is_moving = move_distance > 0.0


func _physics_process(delta: float) -> void:
	if _border_turn_active:
		_process_border_turn(delta)
		return
	if not is_moving:
		return

	var current_quat := Quaternion.from_euler(rotation)
	var interpolated_quat := current_quat.slerp(target_rotation, rotation_speed * delta)
	rotation = interpolated_quat.get_euler()

	var forward_direction := -global_transform.basis.z * _move_direction_sign
	var motion := forward_direction * move_speed * delta
	var next_pos := global_position + motion

	if _is_outside_map(next_pos):
		global_position = _clamp_to_map(global_position)
		_push_off_border()
		_start_border_turn()
		return

	if _is_on_land(next_pos):
		_push_off_land(forward_direction)
		_stop_movement("terrain", TERRAIN_DAMAGE)
		return

	var other_ship := _find_ship_contact()
	if other_ship != null:
		_handle_ship_contact(other_ship)
		return

	var collision := move_and_collide(motion)
	if collision:
		var collider := collision.get_collider()
		var normal := collision.get_normal()
		if normal.length_squared() > 0.001:
			global_position += normal * (SEPARATION_MARGIN + 2.0)
		if collider is BattleNavalShipAdapter or collider is NavalShip3D:
			_handle_ship_contact(collider as Node3D)
			return
		if collider != null and collider.collision_layer & 2:
			_push_off_land(forward_direction)
			_stop_movement("terrain", TERRAIN_DAMAGE)
			return

	if _is_on_land(global_position):
		_push_off_land(forward_direction)
		_stop_movement("terrain", TERRAIN_DAMAGE)
		return

	distance_traveled += move_speed * delta
	if distance_traveled >= move_distance:
		is_moving = false


func _process_border_turn(delta: float) -> void:
	var current_quat := Quaternion.from_euler(rotation)
	var interpolated_quat := current_quat.slerp(_border_turn_target, rotation_speed * delta)
	rotation = interpolated_quat.get_euler()

	if current_quat.angle_to(_border_turn_target) <= BORDER_TURN_DONE_THRESHOLD:
		rotation = _border_turn_target.get_euler()
		_border_turn_active = false
		target_rotation = _border_turn_target
		move_distance = distance_traveled + _border_resume_distance
		_push_off_border()
		is_moving = move_distance > distance_traveled


func _start_border_turn() -> void:
	_border_turn_active = true
	is_moving = false
	_border_resume_distance = maxf(move_distance - distance_traveled, 0.0)
	_border_turn_target = Quaternion.from_euler(Vector3(0, rotation.y + PI, 0))
	_move_direction_sign = 1.0


func _handle_ship_contact(other: Node3D) -> void:
	var other_index := int(other.get_meta("ship_index", -1))
	var other_team := str(other.get_meta("team", "enemy"))
	_push_away_from(other)
	if other is BattleNavalShipAdapter:
		var other_adapter := other as BattleNavalShipAdapter
		other_adapter.force_stop_movement()
		other_adapter._push_away_from(self)
	_stop_movement("ship", SHIP_COLLISION_DAMAGE, other_index, other_team)


func _stop_movement(
	kind: String,
	damage: int,
	other_ship_index: int = -1,
	other_team: String = ""
) -> void:
	is_moving = false
	_border_turn_active = false
	if collision_report.is_valid():
		collision_report.call(kind, damage, other_ship_index, other_team)
	else:
		_report_collision_fallback(kind, damage)
	movement_collision.emit(kind, damage, other_ship_index, other_team)


func _report_collision_fallback(kind: String, damage: int) -> void:
	var battle := get_tree().get_first_node_in_group("battle_controller")
	if battle == null or not battle.has_method("apply_collision_damage"):
		return
	var team := str(get_meta("team", "player"))
	var index := ship_index if ship_index >= 0 else int(get_meta("ship_index", -1))
	battle.apply_collision_damage(team, index, damage, kind)


func _push_away_from(other: Node3D) -> void:
	var offset := global_position - other.global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		offset = Vector3(1.0, 0.0, 0.0)
	offset = offset.normalized() * (SHIP_CONTACT_RADIUS + SEPARATION_MARGIN)
	global_position = other.global_position + offset
	global_position.y = WATER_SURFACE_Y


func _push_off_border() -> void:
	var pos := global_position
	if absf(pos.x) > map_half_size - 1.0:
		pos.x = signf(pos.x) * maxf(map_half_size - BORDER_INSET, 0.0)
	if absf(pos.z) > map_half_size - 1.0:
		pos.z = signf(pos.z) * maxf(map_half_size - BORDER_INSET, 0.0)
	global_position = pos
	global_position.y = WATER_SURFACE_Y


func _push_off_land(away_from: Vector3 = Vector3.ZERO) -> void:
	if terrain == null or not terrain.has_method("get_height"):
		return

	var away := away_from
	away.y = 0.0
	if away.length_squared() > 0.01:
		away = -away.normalized()
	else:
		away = Vector3(0.0, 0.0, 1.0)

	var search_dirs: Array[Vector3] = [
		away,
		away.rotated(Vector3.UP, PI * 0.5),
		away.rotated(Vector3.UP, -PI * 0.5),
		Vector3(1.0, 0.0, 0.0),
		Vector3(-1.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 0.0, -1.0),
	]

	for dir: Vector3 in search_dirs:
		for step: float in [12.0, 24.0, 36.0, 52.0, 72.0, 96.0]:
			var test: Vector3 = global_position + dir * step
			if not _is_on_land(test):
				global_position = test
				global_position.y = WATER_SURFACE_Y
				return


func _is_on_land(pos: Vector3) -> bool:
	if terrain == null or not terrain.has_method("get_height"):
		return false
	var samples: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(14.0, 0.0),
		Vector2(-14.0, 0.0),
		Vector2(0.0, 14.0),
		Vector2(0.0, -14.0),
	]
	for offset: Vector2 in samples:
		if terrain.get_height(pos.x + offset.x, pos.z + offset.y) > LAND_HEIGHT_MAX:
			return true
	return false


func _is_outside_map(pos: Vector3) -> bool:
	return absf(pos.x) >= map_half_size or absf(pos.z) >= map_half_size


func _clamp_to_map(pos: Vector3) -> Vector3:
	return Vector3(
		clampf(pos.x, -map_half_size, map_half_size),
		pos.y,
		clampf(pos.z, -map_half_size, map_half_size)
	)


func _find_ship_contact() -> Node3D:
	for node in get_tree().get_nodes_in_group("battle_ships"):
		if node == self or not node is Node3D:
			continue
		var other := node as Node3D
		if int(other.get_meta("ship_index", -1)) == ship_index:
			continue
		var dist := Vector2(
			global_position.x - other.global_position.x,
			global_position.z - other.global_position.z
		).length()
		if dist < SHIP_CONTACT_RADIUS:
			return other
	return null


func _hide_placeholder_meshes() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false
