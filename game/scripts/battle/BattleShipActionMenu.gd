extends BattleHudPanel
class_name BattleShipActionMenu

signal move_requested(ship_index: int)
signal fire_requested(ship_index: int, weapon_name: String)
signal dismissed

@onready var _title: Label = %ActionTitle
@onready var _actions: VBoxContainer = %ActionList
@onready var _content: VBoxContainer = _title.get_parent()

var _ship_index: int = -1
var _pending_anchor: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false


func show_for_ship(ship: Dictionary, screen_anchor: Vector2) -> void:
	var ship_index := int(ship.get("ship_index", -1))
	var needs_rebuild := ship_index != _ship_index or not visible
	_ship_index = ship_index

	_title.text = str(ship.get("display_name", ship.get("name", "Ship")))
	_rebuild_actions(ship)
	visible = true
	if needs_rebuild:
		call_deferred("_fit_and_position", screen_anchor)
	else:
		set_screen_anchor(screen_anchor)


func set_screen_anchor(screen_anchor: Vector2) -> void:
	_pending_anchor = screen_anchor
	if not visible:
		return
	if size.y <= 0.0:
		call_deferred("_fit_and_position", screen_anchor)
		return
	position = _anchor_to_position(_pending_anchor)


func _rebuild_actions(ship: Dictionary) -> void:
	for child in _actions.get_children():
		child.queue_free()

	if BattleTurnManager.can_move(ship):
		var move_btn := Button.new()
		move_btn.text = "Move"
		move_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		move_btn.custom_minimum_size = Vector2(120, 28)
		move_btn.pressed.connect(func() -> void: move_requested.emit(_ship_index))
		_actions.add_child(move_btn)
	else:
		var moved_label := Label.new()
		moved_label.text = "Already moved"
		moved_label.add_theme_font_size_override("font_size", 11)
		moved_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
		_actions.add_child(moved_label)

	var weapons: Array = ship.get("weapons_remaining", ship.get("weapons", []))
	if weapons.is_empty():
		var no_weapons := Label.new()
		no_weapons.text = "No weapons"
		no_weapons.add_theme_font_size_override("font_size", 11)
		no_weapons.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
		_actions.add_child(no_weapons)
	else:
		for weapon_name in weapons:
			var weapon := str(weapon_name)
			var fire_btn := Button.new()
			fire_btn.text = "Fire: %s" % weapon
			fire_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			fire_btn.custom_minimum_size = Vector2(120, 28)
			fire_btn.pressed.connect(_emit_fire.bind(weapon))
			_actions.add_child(fire_btn)


func _fit_and_position(screen_anchor: Vector2 = Vector2.ZERO) -> void:
	if screen_anchor != Vector2.ZERO:
		_pending_anchor = screen_anchor
	await get_tree().process_frame
	reset_size()
	var panel_size := get_minimum_size()
	if panel_size == Vector2.ZERO:
		panel_size = _content.get_minimum_size()
	custom_minimum_size = panel_size
	size = panel_size
	position = _anchor_to_position(_pending_anchor)


func _anchor_to_position(screen_anchor: Vector2) -> Vector2:
	return screen_anchor - Vector2(size.x * 0.5, size.y + 12.0)


func _emit_fire(weapon: String) -> void:
	fire_requested.emit(_ship_index, weapon)


func hide_menu() -> void:
	if not visible:
		return
	visible = false
	_ship_index = -1
	custom_minimum_size = Vector2.ZERO
	dismissed.emit()
