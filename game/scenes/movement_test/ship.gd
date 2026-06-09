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

# At the top of NavalShip3D.gd, add these exports
@export var cannonball_scene: PackedScene          # Drag CannonBall.tscn here
@export var impact_marker_scene: PackedScene       # Drag ImpactMarker.tscn here
@export var impact_radius: float = 5.0             # Diameter of the landing circle
@export var muzzle_height: float = 2.0             # Height of cannon above waterline
@export var gravity: float = 9.8

@export var max_cannon_range: float = 300.0   # Maximum firing distance
@export var min_launch_angle_deg: float = 5.0  # Flattest shot at point-blank
@export var max_launch_angle_deg: float = 45.0 # Most lobbed at max range

var has_moved: bool = false
var has_fired: bool = false

func reset_turn_actions() -> void:
    has_moved = false
    has_fired = false

func _ready():
    pass

func fire_cannon(angle_deg: float, distance: float) -> void:
    """
    angle_deg: horizontal angle relative to ship's forward, in degrees
    distance:  how far the shot travels horizontally before landing
    """
    if not cannonball_scene:
        push_error("NavalShip3D: cannonball_scene not assigned!")
        return

    var clamped_distance = clamp(distance, 0.0, max_cannon_range)

    # --- Scale launch angle based on distance ratio ---
    var distance_ratio = clamped_distance / max_cannon_range
    var launch_angle_deg = lerp(min_launch_angle_deg, max_launch_angle_deg, distance_ratio)
    var launch_angle_rad = deg_to_rad(launch_angle_deg)

    # --- Spawn position ---
    var spawn_pos = global_position + Vector3(0, muzzle_height, 0)

    # --- Horizontal direction ---
    var ship_forward = -global_transform.basis.z
    var direction = ship_forward.rotated(Vector3.UP, deg_to_rad(angle_deg)).normalized()

    # --- Launch speed from range formula: v = sqrt(d * g / sin(2θ)) ---
    var v = sqrt(clamped_distance * gravity / sin(2.0 * launch_angle_rad))

    var launch_velocity = (
        direction * v * cos(launch_angle_rad)
        + Vector3.UP * v * sin(launch_angle_rad)
    )

    # --- Spawn the cannonball ---
    var ball = cannonball_scene.instantiate() as CannonBall
    get_tree().root.add_child(ball)
    ball.global_position = spawn_pos
    ball.set_meta("firer", self)
    ball.target_distance = clamped_distance
    ball.origin = spawn_pos
    ball.impact_marker_scene = impact_marker_scene
    ball.impact_radius = impact_radius
    ball.linear_velocity = launch_velocity

    print("Distance ratio: ", distance_ratio, 
          " | Launch angle: ", launch_angle_deg, "°",
          " | Speed: ", v)

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
