@tool
extends Node3D

@export var water_plane: Node3D


func _ready() -> void:
	add_to_group("map")


func _follow_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	if water_plane:
		water_plane.position.x = cam.global_position.x
		water_plane.position.z = cam.global_position.z


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_follow_camera()
