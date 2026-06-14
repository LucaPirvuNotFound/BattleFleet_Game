extends Control
class_name BattleFireController

signal fire_confirmed(angle: float, distance: float)

var weapon_name: String = ""
var max_range: float = 200.0
var min_range: float = 0.0

@onready var _status_label: Label = $VBoxContainer/StatusLabel
@onready var _weapon_info_label: Label = $VBoxContainer/WeaponInfoLabel
@onready var _compass: CompassAnglePicker = $VBoxContainer/CompassAnglePicker
@onready var _angle_label: Label = $VBoxContainer/AngleLabel
@onready var _distance_label: Label = $VBoxContainer/DistanceLabel
@onready var _distance_slider: HSlider = $VBoxContainer/DistanceSlider
@onready var _confirm_fire_button: Button = $VBoxContainer/ConfirmFireButton


func _ready() -> void:
	_compass.angle_changed.connect(_on_compass_angle_changed)
	_distance_slider.value_changed.connect(_on_distance_changed)
	_confirm_fire_button.pressed.connect(_on_confirm_fire_pressed)


func configure_weapon(weapon: String) -> void:
	weapon_name = weapon
	var stats := BattleTurnManager.get_weapon_stats(weapon)
	max_range = float(stats.get("max_range", 200.0))
	min_range = float(stats.get("min_range", 0.0))
	_distance_slider.min_value = min_range
	_distance_slider.max_value = max_range
	_distance_slider.value = clampf(max_range * 0.55, min_range, max_range)
	_compass.set_angle(0.0)
	_refresh_ui()


func _refresh_ui() -> void:
	if weapon_name.is_empty():
		return
	var stats := BattleTurnManager.get_weapon_stats(weapon_name)
	_status_label.text = "Fire: %s" % weapon_name
	_weapon_info_label.text = "Range %.0f–%.0f  |  Damage %d  |  AOE %.0f" % [
		min_range,
		max_range,
		int(stats.get("damage", 0)),
		float(stats.get("aoe_radius", 0.0)),
	]
	_on_compass_angle_changed(_compass.angle)
	_on_distance_changed(_distance_slider.value)


func _on_compass_angle_changed(value: float) -> void:
	_angle_label.text = "Angle: %.0f°" % value


func _on_distance_changed(value: float) -> void:
	_distance_label.text = "Range: %.0f" % value


func _on_confirm_fire_pressed() -> void:
	if weapon_name.is_empty():
		return
	fire_confirmed.emit(_compass.angle, _distance_slider.value)
