extends Node3D
class_name RangeRing

@export var ring_radius: float = 200.0
@export var ring_thickness: float = 1.5
@export var ring_color: Color = Color(0.882, 0.472, 0.87, 1.0)

@onready var _mesh_instance := $MeshInstance3D as MeshInstance3D


func _ready() -> void:
    _build_ring()


func attach_to_ship(ship: NavalShip3D) -> void:
    # Reparent to the new ship and reset local position
    if get_parent():
        get_parent().remove_child(self)
    ship.add_child(self)
    position = Vector3.ZERO


func _build_ring() -> void:
    var torus := TorusMesh.new()
    torus.inner_radius = ring_radius - ring_thickness
    torus.outer_radius = ring_radius + ring_thickness
    torus.rings = 128
    torus.ring_segments = 8

    var material := StandardMaterial3D.new()
    material.albedo_color = ring_color
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    torus.material = material

    _mesh_instance.mesh = torus
