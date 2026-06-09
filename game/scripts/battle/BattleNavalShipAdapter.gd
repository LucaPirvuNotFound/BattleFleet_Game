extends NavalShip3D
class_name BattleNavalShipAdapter

## Bridges battle map markers to movement_test NavalShip3D without editing ship.gd.


func configure_from_marker(marker: Node3D) -> void:
	global_position = marker.global_position
	rotation.y = marker.rotation.y
	_hide_placeholder_meshes()


func _hide_placeholder_meshes() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false
