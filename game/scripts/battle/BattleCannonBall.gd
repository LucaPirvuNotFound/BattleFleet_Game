extends RigidBody3D
class_name BattleCannonBall

signal landed(position: Vector3)
signal hit_something(collider: Object, position: Vector3)

var target_distance: float = 0.0
var origin: Vector3 = Vector3.ZERO
var planned_landing: Vector3 = Vector3.ZERO
var impact_marker_scene: PackedScene
var impact_radius: float = 5.0
var firer_ship_index: int = -1
var world_parent: Node3D

var _has_hit: bool = false
var _grace_time: float = 0.2

const VISUAL_SCALE := 8.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	sleeping = false
	_scale_visual()


func _scale_visual() -> void:
	var mesh_node := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_node:
		mesh_node.scale = Vector3.ONE * VISUAL_SCALE


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	_grace_time = maxf(_grace_time - delta, 0.0)
	if _grace_time > 0.0:
		return

	var horizontal_traveled := Vector2(
		global_position.x - origin.x,
		global_position.z - origin.z
	).length()

	if horizontal_traveled >= target_distance:
		_on_landed()


func _on_body_entered(body: Node) -> void:
	if _has_hit or _grace_time > 0.0:
		return
	if _is_own_ship(body):
		return
	_has_hit = true
	var impact_pos := global_position
	impact_pos.y = 1.55
	hit_something.emit(body, impact_pos)
	_spawn_marker(impact_pos)
	queue_free()


func _on_landed() -> void:
	if _has_hit:
		return
	_has_hit = true
	var impact_pos := _impact_position()
	landed.emit(impact_pos)
	_spawn_marker(impact_pos)
	queue_free()


func _is_own_ship(body: Node) -> bool:
	if body == null:
		return false
	if body == get_meta("firer", null):
		return true
	if int(body.get_meta("ship_index", -1)) == firer_ship_index:
		return true
	var parent := body.get_parent()
	if parent is Node and int(parent.get_meta("ship_index", -1)) == firer_ship_index:
		return true
	return false


func _impact_position() -> Vector3:
	if planned_landing != Vector3.ZERO:
		return planned_landing
	var pos := global_position
	pos.y = 1.55
	return pos


func _spawn_marker(impact_pos: Vector3) -> void:
	if impact_marker_scene == null:
		return
	var marker := impact_marker_scene.instantiate() as Node3D
	var parent := world_parent if world_parent != null else get_parent()
	if parent:
		parent.add_child(marker)
	else:
		get_tree().root.add_child(marker)
	marker.global_position = impact_pos
	marker.global_position.y = 1.55
	marker.scale = Vector3(impact_radius, 1.0, impact_radius)
