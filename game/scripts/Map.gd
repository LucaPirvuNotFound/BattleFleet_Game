@tool
extends Node3D

@export var resolution: float = 512.0
@export var vision_circle_scene: PackedScene

@export var sub_viewport: SubViewport
@export var fog_plane: MeshInstance3D
@export var water_plane: Node3D

var map_size: float = 2048.0
var active_ships: Dictionary = {}

func _ready() -> void:
    add_to_group("map")

    if %Terrain:
        map_size = %Terrain.size

    # Ensure the SubViewport is properly sized and updating
    sub_viewport.size = Vector2i(int(resolution), int(resolution))
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

    # Ensure the background ColorRect matches the SubViewport size
    var color_rect = sub_viewport.get_node_or_null("ColorRect")
    if color_rect:
        color_rect.size = Vector2(resolution, resolution)

    var fog_material: ShaderMaterial = fog_plane.get_active_material(0)
    if fog_material:
        fog_material.set_shader_parameter("fog_mask", sub_viewport.get_texture())
        fog_material.set_shader_parameter("map_size", map_size)

func _follow_camera() -> void:
    var cam := get_viewport().get_camera_3d()
    if not cam:
        return
    if water_plane:
        water_plane.position.x = cam.global_position.x
        water_plane.position.z = cam.global_position.z
    if fog_plane:
        fog_plane.position.x = cam.global_position.x
        fog_plane.position.z = cam.global_position.z


func _process(_delta: float) -> void:
    if not Engine.is_editor_hint():
        _follow_camera()

    for ship in active_ships:
        if is_instance_valid(ship):
            var nx: float = (ship.global_position.x / map_size) + 0.5
            var nz: float = (ship.global_position.z / map_size) + 0.5
            active_ships[ship].position = Vector2(nx * resolution, nz * resolution)

func register_ship(ship: Node3D) -> void:
    if not vision_circle_scene:
        return

    var circle: Node2D = vision_circle_scene.instantiate()
    sub_viewport.add_child(circle)
    active_ships[ship] = circle

    ship.tree_exiting.connect(func():
        if active_ships.has(ship):
            active_ships[ship].queue_free()
            active_ships.erase(ship))
