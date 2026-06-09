@tool
extends Node3D

@export var resolution: float = 512.0
@export var vision_circle_scene: PackedScene

var map_size: float = 1024.0
var active_ships: Dictionary = {}

@onready var _sub_viewport: SubViewport = $SubViewport
@onready var _fog_plane: MeshInstance3D = $FogPlane
@onready var _color_rect: ColorRect = $SubViewport/ColorRect


func _ready() -> void:
	_setup_sub_viewport()
	_find_terrain()
	_setup_fog_material()


func _setup_sub_viewport() -> void:
	_sub_viewport.size = Vector2i(int(resolution), int(resolution))
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_color_rect.size = Vector2(resolution, resolution)


func _find_terrain() -> void:
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain and "size" in terrain:
		map_size = terrain.size


func _setup_fog_material() -> void:
	var mat = _fog_plane.get_active_material(0) as ShaderMaterial
	if mat and _sub_viewport:
		mat.set_shader_parameter("fog_mask", _sub_viewport.get_texture())
		mat.set_shader_parameter("map_size", map_size)


func register_ship(ship: Node3D) -> void:
	if not vision_circle_scene or active_ships.has(ship):
		return
	var circle: Node2D = vision_circle_scene.instantiate()
	_sub_viewport.add_child(circle)
	active_ships[ship] = circle
	ship.tree_exiting.connect(func():
		if active_ships.has(ship):
			active_ships[ship].queue_free()
			active_ships.erase(ship))


func _process(_delta: float) -> void:
	for ship in get_tree().get_nodes_in_group("ships"):
		if is_instance_valid(ship) and not active_ships.has(ship):
			register_ship(ship)

	for ship in active_ships:
		if is_instance_valid(ship):
			var nx: float = (ship.global_position.x / map_size) + 0.5
			var nz: float = (ship.global_position.z / map_size) + 0.5
			active_ships[ship].position = Vector2(nx * resolution, nz * resolution)
