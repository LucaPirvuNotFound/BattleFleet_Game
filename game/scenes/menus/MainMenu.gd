extends Control

const SHIP_DATA: Dictionary = {
	"Corvette": 10,
	"Plane": 15,
	"Destroyer": 20,
	"Cruiser": 35,
	"Battleship": 50,
}
const WEAPON_DATA: Dictionary = {
	"Light Cannon": 5,
	"Anti-Air": 5,
	"Torpedoes": 10,
	"Heavy Battery": 15,
}

const MAX_SHIPS: int = 5
const MAX_WEAPONS_PER_SHIP: int = 3
const MAX_FLEET_COST: int = 100

const SHIP_ROW_FONT_SIZE: int = 15
const SHIP_ROW_FONT_SIZE_SELECTED: int = 19
const SHIP_ROW_MIN_HEIGHT: int = 34
const SHIP_ROW_MIN_HEIGHT_SELECTED: int = 42
const WEAPON_ROW_MIN_HEIGHT: int = 30
const SHIP_ROW_BG_SELECTED := Color(0.12, 0.28, 0.48, 0.92)
const SHIP_ROW_TEXT_SELECTED := Color(0.95, 0.98, 1.0)

@onready var _stages: Array[Control] = [%Stage1, %Stage2, %Stage3]
@onready var _settings_panel: PanelContainer = %SettingsPanel
@onready var _auth_panel: PanelContainer = %AuthPanel
@onready var _login_panel: VBoxContainer = %LoginPanel
@onready var _register_panel: VBoxContainer = %RegisterPanel
@onready var _login_username: LineEdit = %LoginUsername
@onready var _login_password: LineEdit = %LoginPassword
@onready var _register_email: LineEdit = %RegisterEmail
@onready var _register_username: LineEdit = %RegisterUsername
@onready var _register_password: LineEdit = %RegisterPassword
@onready var _register_password_confirm: LineEdit = %RegisterPasswordConfirm
@onready var _register_status_label: Label = %RegisterStatusLabel
@onready var _login_submit: Button = _login_panel.get_node("LoginSubmit")
@onready var _register_submit: Button = _register_panel.get_node("RegisterSubmit")

const REGISTER_ERROR_INVALID_EMAIL := "Register failed: invalid email."
const REGISTER_ERROR_PASSWORD_MISMATCH := "Register failed: passwords do not match."

var _email_regex: RegEx
@onready var _fleet_tree: Tree = %FleetTree
@onready var _total_cost_label: Label = %TotalCostLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _weapon_buttons: VBoxContainer = %WeaponButtons
@onready var _remove_ship_button: Button = %RemoveShipButton
@onready var _weapon_panel_hint: Label = %WeaponPanelHint

var _tree_root: TreeItem
var _fleet: Array[Dictionary] = []
var _weapon_check_buttons: Dictionary = {}
var _selected_fleet_index: int = -1


func _ready() -> void:
	_email_regex = RegEx.new()
	_email_regex.compile("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")

	_fleet_tree.hide_root = true
	_tree_root = _fleet_tree.create_item()
	_configure_fleet_tree_theme()

	_build_weapon_buttons()
	change_stage(0)
	_update_cost_display()
	_update_weapon_panel()
	_settings_panel.visible = false
	_auth_panel.visible = false
	_show_login_form()


func change_stage(target_index: int) -> void:
	for i in _stages.size():
		_stages[i].visible = i == target_index
	if target_index != 2:
		_selected_fleet_index = -1
		_clear_fleet_tree_selection()
	_refresh_fleet_tree_styles()
	_update_weapon_panel()


func _clear_fleet_tree_selection() -> void:
	var selected := _fleet_tree.get_selected()
	if selected != null:
		selected.deselect(0)


func _build_weapon_buttons() -> void:
	for weapon_name in WEAPON_DATA.keys():
		var check := CheckButton.new()
		check.text = _format_weapon_label(weapon_name, false)
		check.add_theme_constant_override("h_separation", 12)
		check.toggled.connect(_on_weapon_toggled.bind(weapon_name))
		_weapon_buttons.add_child(check)
		_weapon_check_buttons[weapon_name] = check


func _format_weapon_label(weapon_name: String, equipped: bool) -> String:
	var mark := "[ ✓ ]" if equipped else "[   ]"
	return "%s %s (%d pts)" % [mark, weapon_name, WEAPON_DATA[weapon_name]]


func _on_play_pressed() -> void:
	change_stage(1)


func _on_replays_pressed() -> void:
	print("[Battlefleet] Replays: future Python server integration.")


func _on_stats_pressed() -> void:
	print("[Battlefleet] Stats: future Python server integration.")


func _on_settings_pressed() -> void:
	_auth_panel.visible = false
	_settings_panel.visible = true


func _on_settings_close_pressed() -> void:
	_settings_panel.visible = false


func _on_log_in_menu_pressed() -> void:
	_settings_panel.visible = false
	_clear_auth_fields()
	_show_login_form()
	_auth_panel.visible = true


func _on_auth_close_pressed() -> void:
	_auth_panel.visible = false


func _show_login_form() -> void:
	_login_panel.visible = true
	_register_panel.visible = false
	_clear_register_status()


func _show_register_form() -> void:
	_login_panel.visible = false
	_register_panel.visible = true
	_clear_register_status()


func _clear_register_status() -> void:
	_register_status_label.text = ""
	_register_status_label.visible = false


func _show_register_error(message: String) -> void:
	_register_status_label.text = message
	_register_status_label.visible = true


func _clear_auth_fields() -> void:
	_login_username.text = ""
	_login_password.text = ""
	_register_email.text = ""
	_register_username.text = ""
	_register_password.text = ""
	_register_password_confirm.text = ""
	_clear_register_status()


func _is_valid_email(email: String) -> bool:
	if email.is_empty():
		return false
	return _email_regex.search(email) != null


func _on_login_submit_pressed() -> void:
	var username := _login_username.text.strip_edges()
	var password := _login_password.text

	_login_submit.disabled = true
	var result: Dictionary = await NetworkManager.auth_service.login_user(username, password)

	if result.success:
		print("[Battlefleet] Login successful! Token saved.")
		_auth_panel.visible = false
		print("[Battlefleet] Next step: fleet setup / matchmaking (not implemented yet).")
	else:
		var error_message := str(result.get("error", "Login failed."))
		print("[Battlefleet] Login failed: %s" % error_message)

	_login_submit.disabled = false


func _on_go_to_register_pressed() -> void:
	_show_register_form()


func _on_go_to_login_pressed() -> void:
	_show_login_form()


func _on_register_submit_pressed() -> void:
	var email := _register_email.text.strip_edges()
	var username := _register_username.text.strip_edges()
	var password := _register_password.text
	var password_again := _register_password_confirm.text

	if not _is_valid_email(email):
		_show_register_error(REGISTER_ERROR_INVALID_EMAIL)
		return
	if password != password_again:
		_show_register_error(REGISTER_ERROR_PASSWORD_MISMATCH)
		return

	_clear_register_status()
	_register_submit.disabled = true
	var result: Dictionary = await NetworkManager.auth_service.register_user(
		username,
		email,
		password
	)

	if result.success:
		var payload: Dictionary = result.get("payload", result.get("data", {}))
		var success_message := str(
			result.get("message", payload.get("message", "User registered successfully."))
		)
		print("[Battlefleet] Registration successful: %s" % success_message)
		_show_login_form()
	else:
		var error_message := str(result.get("error", "Registration failed."))
		print("[Battlefleet] Registration failed: %s" % error_message)
		_show_register_error(error_message)

	_register_submit.disabled = false


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_mode_selected(_mode: String) -> void:
	change_stage(2)


func _on_stage2_back_pressed() -> void:
	change_stage(0)


func _on_stage3_back_pressed() -> void:
	change_stage(1)


func _on_add_ship_pressed(ship_name: String) -> void:
	if _fleet.size() >= MAX_SHIPS:
		return

	var entry := {"name": ship_name, "weapons": []}
	_fleet.append(entry)
	var fleet_index := _fleet.size() - 1

	var ship_item := _fleet_tree.create_item(_tree_root)
	ship_item.set_text(0, _format_ship_label(ship_name))
	ship_item.set_metadata(0, fleet_index)
	ship_item.select(0)

	_selected_fleet_index = fleet_index
	_refresh_fleet_tree_styles()
	_update_weapon_panel()
	_update_cost_display()


func _format_ship_label(ship_name: String) -> String:
	return "%s (%d pts)" % [ship_name, SHIP_DATA[ship_name]]


func _on_fleet_tree_item_selected() -> void:
	var selected := _fleet_tree.get_selected()
	if selected == null or selected == _tree_root:
		_selected_fleet_index = -1
	else:
		_selected_fleet_index = int(selected.get_metadata(0))
	_refresh_fleet_tree_styles()
	_update_weapon_panel()


func _on_remove_ship_pressed() -> void:
	var selected := _fleet_tree.get_selected()
	if selected == null or selected == _tree_root:
		return

	var fleet_index: int = int(selected.get_metadata(0))
	selected.free()
	_fleet.remove_at(fleet_index)
	_reindex_fleet_metadata()

	if _fleet.is_empty():
		_selected_fleet_index = -1
		_clear_fleet_tree_selection()
	elif _selected_fleet_index >= _fleet.size():
		_selected_fleet_index = _fleet.size() - 1
		_select_fleet_index(_selected_fleet_index)
	elif _selected_fleet_index == fleet_index:
		_selected_fleet_index = mini(fleet_index, _fleet.size() - 1)
		_select_fleet_index(_selected_fleet_index)

	_refresh_fleet_tree_styles()
	_update_weapon_panel()
	_update_cost_display()


func _configure_fleet_tree_theme() -> void:
	_fleet_tree.add_theme_constant_override("item_margin", 10)
	_fleet_tree.add_theme_constant_override("inner_item_margin_top", 6)
	_fleet_tree.add_theme_constant_override("inner_item_margin_bottom", 10)
	_fleet_tree.add_theme_constant_override("inner_item_margin_left", 14)
	_fleet_tree.add_theme_constant_override("inner_item_margin_right", 10)


func _refresh_fleet_tree_styles() -> void:
	var ship_item := _tree_root.get_first_child()
	while ship_item != null:
		var fleet_index: int = int(ship_item.get_metadata(0))
		var is_selected := fleet_index == _selected_fleet_index
		_style_ship_tree_item(ship_item, is_selected)

		var weapon_item := ship_item.get_first_child()
		while weapon_item != null:
			_style_weapon_tree_item(weapon_item)
			weapon_item = weapon_item.get_next()

		ship_item = ship_item.get_next()


func _style_ship_tree_item(item: TreeItem, selected: bool) -> void:
	if selected:
		item.set_custom_bg_color(0, SHIP_ROW_BG_SELECTED)
		item.set_custom_font_size(0, SHIP_ROW_FONT_SIZE_SELECTED)
		item.set_custom_color(0, SHIP_ROW_TEXT_SELECTED)
		item.set_custom_minimum_height(SHIP_ROW_MIN_HEIGHT_SELECTED)
	else:
		item.clear_custom_bg_color(0)
		item.set_custom_font_size(0, SHIP_ROW_FONT_SIZE)
		item.clear_custom_color(0)
		item.set_custom_minimum_height(SHIP_ROW_MIN_HEIGHT)


func _style_weapon_tree_item(item: TreeItem) -> void:
	item.clear_custom_bg_color(0)
	item.set_custom_font_size(0, -1)
	item.clear_custom_color(0)
	item.set_custom_minimum_height(WEAPON_ROW_MIN_HEIGHT)


func _reindex_fleet_metadata() -> void:
	var ship_item := _tree_root.get_first_child()
	var index := 0
	while ship_item != null:
		ship_item.set_metadata(0, index)
		ship_item.set_text(0, _format_ship_label(_fleet[index]["name"]))
		var weapon_item := ship_item.get_first_child()
		while weapon_item != null:
			weapon_item.set_metadata(0, index)
			weapon_item = weapon_item.get_next()
		ship_item = ship_item.get_next()
		index += 1
	_refresh_fleet_tree_styles()


func _select_fleet_index(fleet_index: int) -> void:
	var ship_item := _tree_root.get_first_child()
	var index := 0
	while ship_item != null:
		if index == fleet_index:
			ship_item.select(0)
			return
		ship_item = ship_item.get_next()
		index += 1


func _on_weapon_toggled(pressed: bool, weapon_name: String) -> void:
	if _selected_fleet_index < 0 or _selected_fleet_index >= _fleet.size():
		_weapon_check_buttons[weapon_name].set_pressed_no_signal(false)
		_weapon_check_buttons[weapon_name].text = _format_weapon_label(weapon_name, false)
		return

	var ship: Dictionary = _fleet[_selected_fleet_index]
	var weapons: Array = ship["weapons"]

	if pressed:
		if weapons.size() >= MAX_WEAPONS_PER_SHIP:
			_weapon_check_buttons[weapon_name].set_pressed_no_signal(false)
			_weapon_check_buttons[weapon_name].text = _format_weapon_label(weapon_name, false)
			return
		weapons.append(weapon_name)
		_add_weapon_tree_item(_selected_fleet_index, weapon_name)
	else:
		weapons.erase(weapon_name)
		_remove_weapon_tree_item(_selected_fleet_index, weapon_name)

	_weapon_check_buttons[weapon_name].text = _format_weapon_label(weapon_name, pressed)
	_refresh_fleet_tree_styles()
	_update_cost_display()


func _find_ship_tree_item(fleet_index: int) -> TreeItem:
	var ship_item := _tree_root.get_first_child()
	var index := 0
	while ship_item != null:
		if index == fleet_index:
			return ship_item
		ship_item = ship_item.get_next()
		index += 1
	return null


func _add_weapon_tree_item(fleet_index: int, weapon_name: String) -> void:
	var ship_item := _find_ship_tree_item(fleet_index)
	if ship_item == null:
		return
	var weapon_item := _fleet_tree.create_item(ship_item)
	weapon_item.set_text(0, "%s (%d pts)" % [weapon_name, WEAPON_DATA[weapon_name]])
	weapon_item.set_metadata(0, fleet_index)


func _remove_weapon_tree_item(fleet_index: int, weapon_name: String) -> void:
	var ship_item := _find_ship_tree_item(fleet_index)
	if ship_item == null:
		return
	var weapon_item := ship_item.get_first_child()
	while weapon_item != null:
		var next := weapon_item.get_next()
		if weapon_item.get_text(0).begins_with(weapon_name):
			weapon_item.free()
			return
		weapon_item = next


func _update_weapon_panel() -> void:
	var has_ship := _selected_fleet_index >= 0 and _selected_fleet_index < _fleet.size()
	_weapon_panel_hint.visible = not has_ship

	for weapon_name in WEAPON_DATA.keys():
		var check: CheckButton = _weapon_check_buttons[weapon_name]
		check.disabled = not has_ship
		if not has_ship:
			check.set_pressed_no_signal(false)
			check.text = _format_weapon_label(weapon_name, false)
			continue

		var equipped: bool = weapon_name in _fleet[_selected_fleet_index]["weapons"]
		check.set_pressed_no_signal(equipped)
		check.text = _format_weapon_label(weapon_name, equipped)


func _get_total_cost() -> int:
	var total := 0
	for ship in _fleet:
		total += SHIP_DATA[ship["name"]]
		for weapon_name in ship["weapons"]:
			total += WEAPON_DATA[weapon_name]
	return total


func _update_cost_display() -> void:
	var total := _get_total_cost()
	_total_cost_label.text = "Total Cost: %d / %d" % [total, MAX_FLEET_COST]

	if total > MAX_FLEET_COST:
		_total_cost_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	elif total == 0:
		_total_cost_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	else:
		_total_cost_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))

	var can_continue := not _fleet.is_empty() and total <= MAX_FLEET_COST
	_continue_button.disabled = not can_continue


func _on_continue_pressed() -> void:
	print(
		"[Battlefleet] Fleet ready — sending to Python server: ",
		_fleet,
		" (total cost: ",
		_get_total_cost(),
		")"
	)
