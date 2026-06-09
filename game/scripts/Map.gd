@tool
extends Node3D

@export var water_plane: Node3D

var map_size: float = 2048.0
var _fog_of_war: FogOfWar

var active_ships: Dictionary:
	get:
		return _fog_of_war.active_ships if _fog_of_war else {}


func _ready() -> void:
    add_to_group("map")

    if %Terrain:
        map_size = %Terrain.size

	_fog_of_war = get_node_or_null("FogOfWar") as FogOfWar
	if _fog_of_war:
		_fog_of_war.setup(map_size)


func _follow_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	if water_plane:
		water_plane.position.x = cam.global_position.x
		water_plane.position.z = cam.global_position.z
	if _fog_of_war:
		_fog_of_war.follow_camera(cam)


func _process(_delta: float) -> void:
    if not Engine.is_editor_hint():
        _follow_camera()


func register_ship(ship: Node3D) -> void:
	if _fog_of_war:
		_fog_of_war.register_ship(ship)


func unregister_ship(ship: Node3D) -> void:
	if _fog_of_war:
		_fog_of_war.unregister_ship(ship)
