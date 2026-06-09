extends Control
class_name MovementController3D

## Emitted when the player confirms a movement order.
signal movement_confirmed(angle: float, distance: float)

## Emitted when the player confirms a fire order.
signal fire_confirmed(angle: float, distance: float)

## Emitted when the player ends their turn manually.
signal turn_ended

var selected_ship: NavalShip3D

@onready var _status_label := $VBoxContainer/StatusLabel as Label
@onready var _angle_label := $VBoxContainer/AngleLabel as Label
@onready var _angle_slider := $VBoxContainer/AngleSlider as HSlider
@onready var _distance_label := $VBoxContainer/DistanceLabel as Label
@onready var _distance_slider := $VBoxContainer/DistanceSlider as HSlider
@onready var _move_panel := $VBoxContainer/MovePanel as PanelContainer
@onready var _confirm_move_button := $VBoxContainer/MovePanel/VBoxContainer/ConfirmMoveButton as Button
@onready var _fire_panel := $VBoxContainer/FirePanel as PanelContainer
@onready var _confirm_fire_button := $VBoxContainer/FirePanel/VBoxContainer/ConfirmFireButton as Button
@onready var _end_turn_button := $VBoxContainer/EndTurnButton as Button


func _ready() -> void:
    _angle_slider.value_changed.connect(_on_angle_changed)
    _distance_slider.value_changed.connect(_on_distance_changed)
    _confirm_move_button.pressed.connect(_on_confirm_move_pressed)
    _confirm_fire_button.pressed.connect(_on_confirm_fire_pressed)
    _end_turn_button.pressed.connect(_on_end_turn_pressed)


func set_selected_ship(ship: NavalShip3D) -> void:
    selected_ship = ship
    _angle_slider.value = 0.0
    _distance_slider.value = 0.0
    _refresh_ui()


func _refresh_ui() -> void:
    if not selected_ship:
        return
    _status_label.text = "Ship: %s" % selected_ship.name
    _set_panel_available(_move_panel, _confirm_move_button, not selected_ship.has_moved)
    _set_panel_available(_fire_panel, _confirm_fire_button, not selected_ship.has_fired)


func _set_panel_available(
    panel: PanelContainer,
    button: Button,
    available: bool
) -> void:
    panel.modulate.a = 1.0 if available else 0.4
    button.disabled = not available


func _on_angle_changed(value: float) -> void:
    _angle_label.text = "Angle: %.0f°" % value


func _on_distance_changed(value: float) -> void:
    _distance_label.text = "Distance: %.0f" % value


func _on_confirm_move_pressed() -> void:
    if not selected_ship or selected_ship.has_moved:
        return
    movement_confirmed.emit(_angle_slider.value, _distance_slider.value)
    selected_ship.has_moved = true
    _refresh_ui()


func _on_confirm_fire_pressed() -> void:
    if not selected_ship or selected_ship.has_fired:
        return
    fire_confirmed.emit(_angle_slider.value, _distance_slider.value)
    selected_ship.has_fired = true
    _refresh_ui()


func _on_end_turn_pressed() -> void:
    turn_ended.emit()
