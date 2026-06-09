extends Node3D
class_name BattleGridOverlay

## Tactical grid lines every N km. Map width matches placement grid (128 km).

const MAP_WIDTH_KM := 128
const GRID_SPACING_KM := 10
const GRID_Y := 1.25

var _mesh_instance: MeshInstance3D


func setup(terrain: MeshInstance3D) -> void:
	_clear_grid()
	if terrain == null:
		return

	var map_size := float(terrain.size)
	var km_step := map_size / float(MAP_WIDTH_KM)
	var half := map_size * 0.5
	var vertices := PackedVector3Array()

	var km := 0
	while km <= MAP_WIDTH_KM:
		var offset := -half + float(km) * km_step
		vertices.append(Vector3(-half, GRID_Y, offset))
		vertices.append(Vector3(half, GRID_Y, offset))
		vertices.append(Vector3(offset, GRID_Y, -half))
		vertices.append(Vector3(offset, GRID_Y, half))
		km += GRID_SPACING_KM

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices

	var line_mesh := ArrayMesh.new()
	line_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.55, 0.82, 1.0, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "KmGridLines"
	_mesh_instance.mesh = line_mesh
	_mesh_instance.material_override = material
	_mesh_instance.visible = false
	add_child(_mesh_instance)


func set_grid_visible(should_show: bool) -> void:
	if _mesh_instance:
		_mesh_instance.visible = should_show


func _clear_grid() -> void:
	for child in get_children():
		child.queue_free()
	_mesh_instance = null
