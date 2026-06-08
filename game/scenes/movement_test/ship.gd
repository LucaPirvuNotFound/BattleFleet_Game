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
    
    # Calculate target angle relative to current rotation
    var absolute_angle = rotation.y + deg_to_rad(angle)
    target_rotation = Quaternion.from_euler(Vector3(0, absolute_angle, 0))
    
    is_moving = true

func _physics_process(delta):
    if is_moving:
        # Rotate smoothly toward target direction
        var current_quat = Quaternion.from_euler(rotation)
        var interpolated_quat = current_quat.slerp(target_rotation, rotation_speed * delta)
        rotation = interpolated_quat.get_euler()
        
        # Move forward in the direction the ship is facing
        var forward_direction = -global_transform.basis.z  # Forward direction in Godot
        global_position += forward_direction * move_speed * delta
        distance_traveled += move_speed * delta
        
        # Stop when we've traveled the desired distance
        if distance_traveled >= move_distance:
            is_moving = false
