extends Node3D
class_name FogOfWar

@export var resolution: float = 768.0
@export var vision_radius: float = 240.0
@export var fog_height: float = 20.0
@export var vision_circle_scene: PackedScene

@export var sub_viewport: SubViewport
@export var fog_plane: MeshInstance3D

var map_size: float = 1024.0
var active_ships: Dictionary = {}


func setup(terrain_size: float) -> void:
	map_size = terrain_size
	if sub_viewport:
		sub_viewport.size = Vector2i(int(resolution), int(resolution))
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var color_rect := sub_viewport.get_node_or_null("ColorRect") as ColorRect
		if color_rect:
			color_rect.size = Vector2(resolution, resolution)

	var fog_material: ShaderMaterial = fog_plane.get_active_material(0) if fog_plane else null
	if fog_material:
		fog_material.set_shader_parameter("fog_mask", sub_viewport.get_texture())
		fog_material.set_shader_parameter("map_size", map_size)

	if fog_plane:
		fog_plane.position.y = fog_height


func follow_camera(cam: Camera3D) -> void:
	if cam == null or fog_plane == null:
		return
	fog_plane.position.x = cam.global_position.x
	fog_plane.position.z = cam.global_position.z
	fog_plane.position.y = fog_height


func register_ship(ship: Node3D) -> void:
	if not vision_circle_scene or active_ships.has(ship):
		return

	var circle: Node2D = vision_circle_scene.instantiate()
	var sprite_scale := _vision_sprite_scale()
	circle.scale = Vector2(sprite_scale, sprite_scale)
	sub_viewport.add_child(circle)
	active_ships[ship] = circle

	if not ship.tree_exiting.is_connected(_on_ship_tree_exiting):
		ship.tree_exiting.connect(_on_ship_tree_exiting.bind(ship))


func is_world_position_visible(world_pos: Vector3) -> bool:
	return is_visible_from_observers(world_pos, active_ships.keys())


func is_visible_from_observers(world_pos: Vector3, observers: Array) -> bool:
	var clear_radius := vision_radius * 0.72
	for observer in observers:
		if not is_instance_valid(observer):
			continue
		var origin: Vector3 = observer.global_position
		var dist := Vector2(
			origin.x - world_pos.x,
			origin.z - world_pos.z
		).length()
		if dist <= clear_radius:
			return true
	return false


func unregister_ship(ship: Node3D) -> void:
	if not active_ships.has(ship):
		return
	var circle: Node2D = active_ships[ship]
	if is_instance_valid(circle):
		circle.queue_free()
	active_ships.erase(ship)


func _on_ship_tree_exiting(ship: Node3D) -> void:
	unregister_ship(ship)


func _vision_sprite_scale() -> float:
	const TEXTURE_SIZE := 512.0
	var diameter_px := (2.0 * vision_radius / map_size) * resolution
	return diameter_px / TEXTURE_SIZE


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	for ship in active_ships:
		if not is_instance_valid(ship):
			continue
		var nx: float = (ship.global_position.x / map_size) + 0.5
		var nz: float = (ship.global_position.z / map_size) + 0.5
		active_ships[ship].position = Vector2(nx * resolution, nz * resolution)
