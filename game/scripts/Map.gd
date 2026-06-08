extends Node3D

@export var resolution: float = 512.0
@export var vision_circle_scene: PackedScene

@onready var sub_viewport: SubViewport = $SubViewport
@onready var fog_plane: MeshInstance3D = $FogPlane

var map_size: float = 2048.0
var active_ships: Dictionary = {}

func _ready() -> void:
	if %Terrain:
		map_size = %Terrain.size

	var fog_material: ShaderMaterial = fog_plane.get_active_material(0)
	if fog_material:
		fog_material.set_shader_parameter("fog_mask", sub_viewport.get_texture())
		fog_material.set_shader_parameter("map_size", map_size)

func _process(_delta: float) -> void:
	for ship in active_ships:
		if is_instance_valid(ship):
			var nx: float = (ship.global_position.x / map_size) + 0.5
			var nz: float = (ship.global_position.z / map_size) + 0.5
			active_ships[ship].position = Vector2(nx * resolution, nz * resolution)

func register_ship(ship: Node3D) -> void:
	if not vision_circle_scene:
		return

	var sprite: Sprite2D = vision_circle_scene.instantiate()
	sub_viewport.add_child(sprite)
	active_ships[ship] = sprite

	ship.tree_exiting.connect(func():
		if active_ships.has(ship):
			active_ships[ship].queue_free()
			active_ships.erase(ship))
