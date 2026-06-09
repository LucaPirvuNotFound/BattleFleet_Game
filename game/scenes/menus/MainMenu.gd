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
@onready var _fleet_setup_title: Label = %Title
@onready var _queue_overlay: Control = %QueueOverlay
@onready var _queue_label: Label = %QueueLabel
@onready var _cancel_queue_button: Button = %CancelQueueButton
@onready var _weapon_buttons: VBoxContainer = %WeaponButtons
@onready var _weapon_panel_hint: Label = %WeaponPanelHint

var _tree_root: TreeItem
var _fleet: Array[Dictionary] = []
var _weapon_check_buttons: Dictionary = {}
var _selected_fleet_index: int = -1
var _selected_mode: String = ""
var _local_setup_player: int = 1
var _pvp_queue_aborted: bool = false
const MATCH_PREP_SCENE := preload("res://scenes/match/MatchPrep.tscn")


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
	_queue_overlay.visible = false
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


func _on_mode_selected(mode: String) -> void:
	_selected_mode = mode
	_local_setup_player = 1
	MatchContext.clear_local_two_player_setup()
	_reset_fleet_builder()
	_configure_fleet_setup_header()
	change_stage(2)


func _on_stage2_back_pressed() -> void:
	change_stage(0)


func _on_stage3_back_pressed() -> void:
	if _selected_mode.to_lower() == "local" and _local_setup_player == 2:
		_local_setup_player = 1
		_restore_local_host_fleet()
		_configure_fleet_setup_header()
		return
	MatchContext.clear_local_two_player_setup()
	_local_setup_player = 1
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
	var mode_key := _selected_mode.to_lower()
	if mode_key.is_empty():
		push_warning("[Battlefleet] Select a game mode first.")
		return
	if mode_key == "pvp" and not NetworkManager.is_logged_in():
		print("[Battlefleet] Log in before playing PvP.")
		return
	if mode_key == "pve" and not NetworkManager.is_logged_in():
		print("[Battlefleet] Log in before playing PvE.")
		return

	MatchContext.pending_mode = mode_key
	MatchContext.mode = mode_key

	if mode_key == "local":
		await _continue_local_mode()
		return

	if mode_key == "pvp":
		await _continue_pvp_mode()
		return

	MatchContext.set_local_fleet(_fleet, _get_total_cost())
	await _go_to_match_prep()


func _continue_local_mode() -> void:
	if _local_setup_player == 1:
		var host_name := _resolve_host_display_name()
		MatchContext.save_local_host_fleet(_fleet, _get_total_cost(), host_name)
		MatchContext.local_guest_display_name = "%s's guest" % host_name
		_local_setup_player = 2
		_reset_fleet_builder()
		_configure_fleet_setup_header()
		_reset_continue_button()
		return

	MatchContext.save_local_guest_fleet(_fleet, _get_total_cost())
	MatchContext.set_local_fleet(
		MatchContext.local_host_fleet,
		MatchContext.local_host_fleet_total_cost
	)
	await _go_to_match_prep()


func _continue_pvp_mode() -> void:
	MatchContext.set_local_fleet(_fleet, _get_total_cost())
	_pvp_queue_aborted = false
	_continue_button.disabled = true
	_continue_button.text = "Searching..."
	_show_pvp_queue_overlay("Finding opponent (FastAPI queue)...")

	var fleet_payload := NetworkManager.fleet_service.build_fleet_payload(
		MatchContext.your_fleet,
		MatchContext.your_fleet_total_cost
	)

	var join := await NetworkManager.matchmaking_service.join_queue("pvp", fleet_payload)
	if _pvp_queue_aborted:
		await NetworkManager.matchmaking_service.leave_queue()
		_finish_pvp_queue_ui()
		return
	if not join.success:
		_queue_label.text = "Queue failed: %s" % join.get("error", "")
		await get_tree().create_timer(2.5).timeout
		_finish_pvp_queue_ui()
		return

	var match_id := ""
	if str(join.data.get("status", "")) == "matched":
		match_id = str(join.data.get("match_id", ""))
	else:
		var poll := await NetworkManager.matchmaking_service.poll_until_matched()
		if poll.get("cancelled", false):
			await NetworkManager.matchmaking_service.leave_queue()
			_finish_pvp_queue_ui()
			return
		if not poll.success:
			_queue_label.text = "Matchmaking failed: %s" % poll.get("error", "")
			await get_tree().create_timer(2.5).timeout
			await NetworkManager.matchmaking_service.leave_queue()
			_finish_pvp_queue_ui()
			return
		match_id = str(poll.match_id)

	var fetch := await NetworkManager.match_service.fetch_match(match_id)
	_queue_overlay.visible = false
	if not fetch.success:
		_queue_label.text = "Could not load match."
		_queue_overlay.visible = true
		await get_tree().create_timer(2.0).timeout
		_finish_pvp_queue_ui()
		return

	_finish_pvp_queue_ui()
	await _go_to_match_prep()


func _show_pvp_queue_overlay(message: String) -> void:
	_queue_label.text = message
	_cancel_queue_button.disabled = false
	_queue_overlay.visible = true


func _on_cancel_queue_pressed() -> void:
	if not _queue_overlay.visible:
		return
	_pvp_queue_aborted = true
	_cancel_queue_button.disabled = true
	_queue_label.text = "Leaving queue..."
	NetworkManager.matchmaking_service.request_poll_cancel()


func _finish_pvp_queue_ui() -> void:
	_pvp_queue_aborted = false
	NetworkManager.matchmaking_service.reset_poll_cancel()
	_queue_overlay.visible = false
	_cancel_queue_button.disabled = false
	_reset_continue_button()


func _go_to_match_prep() -> void:
	_continue_button.disabled = true
	_continue_button.text = "Loading..."
	await get_tree().process_frame
	get_tree().change_scene_to_packed(MATCH_PREP_SCENE)


func _resolve_host_display_name() -> String:
	if NetworkManager.logged_in_username != "":
		return NetworkManager.logged_in_username
	return "Guest"


func _configure_fleet_setup_header() -> void:
	if _selected_mode.to_lower() != "local":
		_fleet_setup_title.text = "Fleet Builder — %s" % _selected_mode
		return
	if _local_setup_player == 1:
		_fleet_setup_title.text = "Player 1 — %s" % _resolve_host_display_name()
	else:
		_fleet_setup_title.text = "Player 2 — %s" % MatchContext.local_guest_display_name


func _reset_fleet_builder() -> void:
	_fleet.clear()
	_selected_fleet_index = -1
	var ship_item := _tree_root.get_first_child()
	while ship_item != null:
		var next := ship_item.get_next()
		ship_item.free()
		ship_item = next
	_update_weapon_panel()
	_update_cost_display()


func _restore_local_host_fleet() -> void:
	_fleet.clear()
	for ship in MatchContext.local_host_fleet:
		_fleet.append(ship.duplicate(true))
	_selected_fleet_index = -1
	_rebuild_fleet_tree_from_fleet()
	_update_weapon_panel()
	_update_cost_display()


func _rebuild_fleet_tree_from_fleet() -> void:
	var ship_item := _tree_root.get_first_child()
	while ship_item != null:
		var next := ship_item.get_next()
		ship_item.free()
		ship_item = next

	for fleet_index in _fleet.size():
		var ship: Dictionary = _fleet[fleet_index]
		var ship_name: String = ship["name"]
		var new_ship_item := _fleet_tree.create_item(_tree_root)
		new_ship_item.set_text(0, _format_ship_label(ship_name))
		new_ship_item.set_metadata(0, fleet_index)
		for weapon_name in ship["weapons"]:
			var weapon_item := _fleet_tree.create_item(new_ship_item)
			weapon_item.set_text(0, "%s (%d pts)" % [weapon_name, WEAPON_DATA[weapon_name]])
			weapon_item.set_metadata(0, fleet_index)
	_refresh_fleet_tree_styles()


func _reset_continue_button() -> void:
	_continue_button.text = "Continue"
	_update_cost_display()
