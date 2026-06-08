extends CharacterBody3D
class_name NavalShip3D

@export var max_movement_distance: float = 500.0
@export var move_speed: float = 100.0
@export var rotation_speed: float = 3.0

var current_angle: float = 0.0
var move_distance: float = 0.0
var is_moving: bool = false
var target_rotation: Quaternion
var distance_traveled: float = 0.0

func _ready():
    pass

func set_movement_target(angle: float, distance: float) -> void:
    """Set movement with angle relative to current ship rotation"""
    current_angle = angle
    move_distance = clamp(distance, 0, max_movement_distance)
    distance_traveled = 0.0

    var absolute_angle = rotation.y + deg_to_rad(angle)
    target_rotation = Quaternion.from_euler(Vector3(0, absolute_angle, 0))

    is_moving = true

func _physics_process(delta):
    if not is_moving:
        return

    # Rotate smoothly toward target
    var current_quat = Quaternion.from_euler(rotation)
    var interpolated_quat = current_quat.slerp(target_rotation, rotation_speed * delta)
    rotation = interpolated_quat.get_euler()

    # Build movement vector and attempt the move
    var forward_direction = -global_transform.basis.z
    var motion = forward_direction * move_speed * delta

    var collision = move_and_collide(motion)

    if collision:
        var collider = collision.get_collider()
        # Check if collider is on the obstacles layer (layer 2 = bit 1)
        if collider.collision_layer & 2:
            is_moving = false
            return
        # If the collider doesn't block ships, slide past it normally
        # (remove this block if you want ALL collisions to stop the ship)

    distance_traveled += move_speed * delta
    if distance_traveled >= move_distance:
        is_moving = false
