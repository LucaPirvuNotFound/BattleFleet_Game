extends Node3D
class_name ShipFacingArrow

const ARROW_LENGTH := 12.0
const ARROW_WIDTH := 6.0
const Y_OFFSET := 0.12


func setup(team_color: Color) -> void:
	position = Vector3(0.0, Y_OFFSET, 0.0)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "ArrowMesh"
	mesh_instance.mesh = _build_arrow_mesh()

	var material := StandardMaterial3D.new()
	material.albedo_color = team_color.lerp(Color(1.0, 0.92, 0.35), 0.55)
	material.emission_enabled = true
	material.emission = team_color.lerp(Color(1.0, 0.85, 0.2), 0.65)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 3
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _build_arrow_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var half_w := ARROW_WIDTH * 0.5
	var base_z := -ARROW_LENGTH * 0.2
	var tip_z := -ARROW_LENGTH
	var verts := PackedVector3Array([
		Vector3(0.0, 0.0, tip_z),
		Vector3(-half_w, 0.0, base_z),
		Vector3(half_w, 0.0, base_z),
	])
	var indices := PackedInt32Array([0, 1, 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
