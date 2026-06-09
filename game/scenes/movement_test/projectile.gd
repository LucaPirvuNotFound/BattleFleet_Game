extends RigidBody3D
class_name CannonBall

@export var collision_layer_mask: int = 6  # layers 2+3: obstacles + ships

signal landed(position: Vector3)
signal hit_something(collider: Object, position: Vector3)

var target_distance: float = 0.0
var origin: Vector3 = Vector3.ZERO
var _has_hit: bool = false

# Impact marker scene — assign in ship code
var impact_marker_scene: PackedScene = null
var impact_radius: float = 5.0

func _ready():
    # Listen for physics collisions
    contact_monitor = true
    max_contacts_reported = 1
    body_entered.connect(_on_body_entered)

func _physics_process(_delta):
    if _has_hit:
        return

    # Check if we've traveled the target distance horizontally
    var horizontal_traveled = Vector2(
        global_position.x - origin.x,
        global_position.z - origin.z
    ).length()

    if horizontal_traveled >= target_distance:
        _on_landed()

func _on_body_entered(body):
    if _has_hit:
        return
    # Ignore the ship that fired us
    if body == get_meta("firer", null):
        return
    _has_hit = true
    emit_signal("hit_something", body, global_position)
    _spawn_marker()
    queue_free()

func _on_landed():
    if _has_hit:
        return
    _has_hit = true
    emit_signal("landed", global_position)
    _spawn_marker()
    queue_free()

func _spawn_marker():
    if impact_marker_scene:
        var marker = impact_marker_scene.instantiate()
        get_tree().root.add_child(marker)
        marker.global_position = global_position
        marker.global_position.y = 0.1  # Just above sea level
        # Scale the circle by diameter
        marker.scale = Vector3(impact_radius, 1.0, impact_radius)
