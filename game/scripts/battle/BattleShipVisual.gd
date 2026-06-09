extends RefCounted
class_name BattleShipVisual

const SHIP_SCENES: Dictionary = {
	"Corvette": preload("res://scenes/models/Corvette.tscn"),
	"Plane": preload("res://scenes/models/Plane.tscn"),
	"Destroyer": preload("res://scenes/models/Destroyer.tscn"),
	"Cruiser": preload("res://scenes/models/Cruiser.tscn"),
	"Battleship": preload("res://scenes/models/Battleship.tscn"),
}

const TARGET_SHIP_LENGTH := 140.0
const TARGET_PLANE_LENGTH := 100.0
const PLANE_FLOAT_HEIGHT := 2.5
## Keep hull above the water quad (y=0) and shader wave displacement.
const HULL_WATER_CLEARANCE := 0.35
const SHIP_RENDER_PRIORITY := 2
const FALLBACK_MODEL_SCALE := 120.0


static func spawn_marker(
	ship_name: String,
	team_color: Color,
	world_pos: Vector3,
	rotation_steps: int
) -> Node3D:
	var marker := Node3D.new()
	marker.position = world_pos
	marker.rotation_degrees.y = float(rotation_steps) * 90.0
	marker.set_meta("team_color", team_color)
	marker.set_meta("ship_name", ship_name)

	var model := _instantiate_ship(ship_name)
	if model == null:
		model = _fallback_hull(team_color)
	marker.add_child(model)
	return marker


static func finalize_marker(marker: Node3D) -> void:
	if marker.get_child_count() == 0:
		return
	var model := marker.get_child(0) as Node3D
	var ship_name := str(marker.get_meta("ship_name", ""))
	var team_color: Color = marker.get_meta("team_color", Color.WHITE)
	_scale_model(model, ship_name)
	_align_model_on_water(model, marker, ship_name)
	_apply_team_tint(marker, team_color, false)
	add_facing_arrow(marker)


static func add_facing_arrow(marker: Node3D) -> void:
	if marker == null or marker.get_node_or_null("FacingArrow") != null:
		return
	var team_color: Color = marker.get_meta("team_color", Color.WHITE)
	var arrow := ShipFacingArrow.new()
	arrow.name = "FacingArrow"
	arrow.setup(team_color)
	marker.add_child(arrow)


static func set_highlight(marker: Node3D, selected: bool) -> void:
	if marker == null:
		return
	var team_color: Color = marker.get_meta("team_color", Color.WHITE)
	_apply_team_tint(marker, team_color, selected)


static func _instantiate_ship(ship_name: String) -> Node3D:
	var scene: PackedScene = SHIP_SCENES.get(ship_name)
	if scene == null:
		push_warning("BattleShipVisual: no scene for ship type '%s'" % ship_name)
		return null
	return scene.instantiate() as Node3D


static func _fallback_hull(team_color: Color) -> MeshInstance3D:
	var hull := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(7.0, 2.0, 14.0)
	hull.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = team_color
	material.emission_enabled = true
	material.emission = team_color * 0.55
	material.render_priority = SHIP_RENDER_PRIORITY
	hull.material_override = material
	return hull


static func _scale_model(model: Node3D, ship_name: String) -> void:
	var aabb := _combined_aabb_in_space(model, model)
	var length := maxf(aabb.size.x, aabb.size.z)
	if length <= 0.01:
		model.scale = Vector3.ONE * FALLBACK_MODEL_SCALE
		return
	var target := TARGET_PLANE_LENGTH if ship_name == "Plane" else TARGET_SHIP_LENGTH
	model.scale *= target / length


static func _align_model_on_water(model: Node3D, marker: Node3D, ship_name: String) -> void:
	var aabb := _combined_aabb_in_space(model, marker)
	if aabb.size == Vector3.ZERO:
		model.position.y += HULL_WATER_CLEARANCE
		return
	model.position.x -= aabb.get_center().x
	model.position.y -= aabb.position.y
	model.position.z -= aabb.get_center().z
	model.position.y += HULL_WATER_CLEARANCE
	if ship_name == "Plane":
		model.position.y += PLANE_FLOAT_HEIGHT
		model.rotation_degrees.y += 180.0


static func _combined_aabb_in_space(model: Node3D, space_root: Node3D) -> AABB:
	var has_aabb := false
	var combined := AABB()
	var space_from_root := space_root.global_transform.affine_inverse()
	for node in model.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		var mesh_aabb := visual.get_aabb()
		if mesh_aabb.size == Vector3.ZERO:
			continue
		var local_xf := space_from_root * visual.global_transform
		var piece_aabb := local_xf * mesh_aabb
		if not has_aabb:
			combined = piece_aabb
			has_aabb = true
		else:
			combined = combined.merge(piece_aabb)
	return combined


static func _apply_team_tint(root: Node3D, team_color: Color, selected: bool) -> void:
	var emission_strength := 1.2 if selected else 0.55
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface_idx in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface_idx)
			if material == null:
				material = mesh.get_active_material(surface_idx)
			if material == null:
				continue
			material = material.duplicate()
			if material is StandardMaterial3D:
				var std := material as StandardMaterial3D
				std.emission_enabled = true
				std.emission = team_color * emission_strength
				std.albedo_color = std.albedo_color.lerp(team_color, 0.18)
				std.render_priority = SHIP_RENDER_PRIORITY
			mesh.set_surface_override_material(surface_idx, material)
