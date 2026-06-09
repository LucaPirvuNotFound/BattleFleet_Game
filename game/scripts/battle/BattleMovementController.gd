extends Control
class_name BattleMovementController

signal movement_confirmed(angle: float, distance: float)

var selected_ship: NavalShip3D

@onready var _status_label: Label = $VBoxContainer/StatusLabel
@onready var _compass: CompassAnglePicker = $VBoxContainer/CompassAnglePicker
@onready var _angle_label: Label = $VBoxContainer/AngleLabel
@onready var _distance_label: Label = $VBoxContainer/DistanceLabel
@onready var _distance_slider: HSlider = $VBoxContainer/DistanceSlider
@onready var _confirm_move_button: Button = $VBoxContainer/ConfirmMoveButton


func _ready() -> void:
	_compass.angle_changed.connect(_on_compass_angle_changed)
	_distance_slider.value_changed.connect(_on_distance_changed)
	_confirm_move_button.pressed.connect(_on_confirm_move_pressed)


func set_selected_ship(ship: NavalShip3D) -> void:
	selected_ship = ship
	_compass.set_angle(0.0)
	_distance_slider.value = 0.0
	_refresh_ui()


func _refresh_ui() -> void:
	if selected_ship == null:
		return
	_status_label.text = "Heading for %s" % selected_ship.name
	_confirm_move_button.disabled = selected_ship.has_moved
	_confirm_move_button.modulate.a = 1.0 if not selected_ship.has_moved else 0.4


func _on_compass_angle_changed(value: float) -> void:
	_angle_label.text = "Angle: %.0f°" % value


func _on_distance_changed(value: float) -> void:
	if value < 0.0:
		_distance_label.text = "Distance: %.0f (reverse)" % value
	else:
		_distance_label.text = "Distance: %.0f" % value


func _on_confirm_move_pressed() -> void:
	if selected_ship == null or selected_ship.has_moved:
		return
	movement_confirmed.emit(_compass.angle, _distance_slider.value)
	selected_ship.has_moved = true
	_refresh_ui()
