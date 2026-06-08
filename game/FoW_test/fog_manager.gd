# fog_manager.gd
extends Node3D

@export var map_size: Vector2 = Vector2(200, 1000)
var fog_mesh: MeshInstance3D

func _ready():
    fog_mesh = MeshInstance3D.new()
    var plane = PlaneMesh.new()
    plane.size = map_size
    fog_mesh.mesh = plane
    fog_mesh.position.y = 2.0  # hover above sea level

    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0, 0, 0, 0.95)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    fog_mesh.material_override = mat
    add_child(fog_mesh)
