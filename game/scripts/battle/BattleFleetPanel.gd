extends BattleHudPanel
class_name BattleFleetPanel

signal ship_selected(ship_index: int)

@onready var _ship_list: VBoxContainer = %ShipListVBox


func populate_ships(ships: Array) -> void:
	for child in _ship_list.get_children():
		child.queue_free()

	for ship in ships:
		if not ship is Dictionary:
			continue
		_ship_list.add_child(_build_ship_row(ship))

	var panel_width := offset_right - offset_left
	fit_to_content(panel_width)


func refresh_all_ship_status(ships: Array) -> void:
	for ship in ships:
		if ship is Dictionary:
			update_ship_status(int(ship.get("ship_index", -1)), ship)


func update_ship_status(ship_index: int, ship: Dictionary) -> void:
	for child in _ship_list.get_children():
		if int(child.get_meta("ship_index", -1)) != ship_index:
			continue
		var move_icon: Label = child.get_node_or_null("StatusRow/MoveIcon")
		var fire_icon: Label = child.get_node_or_null("StatusRow/FireIcon")
		if move_icon == null or fire_icon == null:
			return
		var can_move := BattleTurnManager.can_move(ship)
		var can_fire := BattleTurnManager.can_fire_any(ship)
		move_icon.modulate = Color(0.45, 0.95, 1.0, 1.0) if can_move else Color(0.45, 0.55, 0.65, 0.35)
		move_icon.tooltip_text = "Can move" if can_move else "Already moved"
		fire_icon.modulate = Color(1.0, 0.55, 0.35, 1.0) if can_fire else Color(0.55, 0.45, 0.4, 0.35)
		fire_icon.tooltip_text = "Weapon available" if can_fire else "No shots left"
		return


func highlight_ship(ship_index: int) -> void:
	for child in _ship_list.get_children():
		var row_index := int(child.get_meta("ship_index", -1))
		var is_selected := ship_index >= 0 and row_index == ship_index
		child.modulate = Color(1.15, 1.2, 1.3, 1.0) if is_selected else Color.WHITE


func update_ship_health(ship_index: int, hp: int, max_hp: int) -> void:
	for child in _ship_list.get_children():
		if int(child.get_meta("ship_index", -1)) != ship_index:
			continue
		var bar: ProgressBar = child.find_child("HealthBar", true, false) as ProgressBar
		if bar:
			bar.max_value = float(max_hp)
			bar.value = float(hp)
		var hp_label: Label = child.find_child("HpLabel", true, false) as Label
		if hp_label:
			hp_label.text = "%d/%d" % [hp, max_hp]
		child.modulate = Color(0.45, 0.5, 0.55, 0.65) if hp <= 0 else Color.WHITE
		return


func _build_ship_row(ship: Dictionary) -> Control:
	var ship_index := int(ship.get("ship_index", 0))
	var display_name := str(ship.get("display_name", ship.get("name", "Ship %d" % ship_index)))

	var wrapper := Button.new()
	wrapper.name = "ShipRow_%d" % ship_index
	wrapper.flat = true
	wrapper.alignment = HORIZONTAL_ALIGNMENT_LEFT
	wrapper.custom_minimum_size = Vector2(0, 52)
	wrapper.set_meta("ship_index", ship_index)
	wrapper.pressed.connect(func() -> void: ship_selected.emit(ship_index))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	vbox.add_child(title_row)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(80, 18)
	name_label.add_theme_font_size_override("font_size", 13)
	title_row.add_child(name_label)

	var status_row := HBoxContainer.new()
	status_row.name = "StatusRow"
	status_row.add_theme_constant_override("separation", 4)
	title_row.add_child(status_row)

	var move_icon := Label.new()
	move_icon.name = "MoveIcon"
	move_icon.text = "M"
	move_icon.add_theme_font_size_override("font_size", 12)
	move_icon.tooltip_text = "Can move"
	status_row.add_child(move_icon)

	var fire_icon := Label.new()
	fire_icon.name = "FireIcon"
	fire_icon.text = "F"
	fire_icon.add_theme_font_size_override("font_size", 12)
	fire_icon.tooltip_text = "Weapon available"
	status_row.add_child(fire_icon)

	var health_bar := ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.custom_minimum_size = Vector2(130, 10)
	health_bar.max_value = float(ship.get("max_hp", 100))
	health_bar.value = float(ship.get("hp", 100))
	health_bar.show_percentage = false
	vbox.add_child(health_bar)

	var hp_label := Label.new()
	hp_label.name = "HpLabel"
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95))
	hp_label.text = "%d/%d" % [int(ship.get("hp", 100)), int(ship.get("max_hp", 100))]
	vbox.add_child(hp_label)

	return wrapper
