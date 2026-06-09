@tool
extends Camera3D

@export var drag_button: int = MOUSE_BUTTON_RIGHT
@export var map_size: float = 1024.0:
    set(v):
        map_size = v
        update_configuration_warnings()
@export var zoom_speed: float = 1.15
@export var min_zoom: float = 50.0
@export var max_zoom: float = 2000.0
@export var clamp_to_map: bool = true

var _dragging: bool = false
var _drag_start: Vector2
var _drag_start_cam_pos: Vector3


func setup(terrain_size: float) -> void:
    map_size = terrain_size


func _get_configuration_warnings() -> PackedStringArray:
    if not Engine.is_editor_hint():
        return []
    if map_size <= 0:
        return ["map_size is not set"]
    return []


func _unhandled_input(event: InputEvent) -> void:
    if not current:
        return

    if event is InputEventMouseButton:
        if event.button_index == drag_button:
            if event.pressed:
                _dragging = true
                _drag_start = event.position
                _drag_start_cam_pos = position
            else:
                _dragging = false

        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            size = max(min_zoom, size / zoom_speed)
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            size = min(max_zoom, size * zoom_speed)

    if event is InputEventMouseMotion and _dragging:
        var world_start := project_position(_drag_start, 1.0)
        var world_now := project_position(event.position, 1.0)
        var offset := world_now - world_start
        position = _drag_start_cam_pos - offset

        if clamp_to_map:
            var half := map_size * 0.5
            position.x = clamp(position.x, -half, half)
            position.z = clamp(position.z, -half, half)
