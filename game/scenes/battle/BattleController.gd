extends Control

const FLEET_COLOR := Color(0.25, 0.7, 1.0, 1.0)
const ENEMY_COLOR := Color(1.0, 0.35, 0.25, 1.0)
## Water quad sits at y=0; shader waves add ~1–2 units of height on top.
const WATER_SURFACE_Y := 1.6
const TURN_TIME_SEC := 120
const SHIP_PICK_RADIUS := 80.0
const CLICK_DRAG_THRESHOLD := 8.0

const SHIP_MAX_HP: Dictionary = {
	"Corvette": 80,
	"Plane": 60,
	"Destroyer": 100,
	"Cruiser": 140,
	"Battleship": 200,
}

const NAVAL_MOVER_SCENE := preload("res://scenes/battle/BattleNavalShipAdapter.tscn")

@onready var _viewport_container: SubViewportContainer = $ViewportContainer
@onready var _map_anchor: Node3D = %MapAnchor
@onready var _ship_markers: Node3D = %ShipMarkers
@onready var _grid_overlay: BattleGridOverlay = %GridOverlay
@onready var _map_camera: Camera3D = %MapCamera
@onready var _loading_overlay: Control = %LoadingOverlay
@onready var _loading_label: Label = %LoadingLabel
@onready var _fleet_panel: PanelContainer = %FleetPanel
@onready var _ship_action_menu: PanelContainer = %ShipActionMenu
@onready var _round_label: Label = %RoundLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _movement_panel: MovementController3D = $UI/BattleMovementPanel
@onready var _movement_cancel_button: Button = $UI/BattleMovementPanel/VBoxContainer/CancelButton

var _terrain: MeshInstance3D
var _player_ships: Array = []
var _ship_movers: Dictionary = {}
var _turn_seconds_left: int = TURN_TIME_SEC
var _turn_timer: Timer
var _selected_ship_index: int = -1
var _movement_ship_index: int = -1
var _round_number: int = 1
var _is_ai_turn: bool = false
var _left_click_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_fleet_panel.ship_selected.connect(_on_fleet_ship_selected)
	_ship_action_menu.move_requested.connect(_on_move_requested)
	_ship_action_menu.fire_requested.connect(_on_fire_requested)
	_movement_panel.movement_confirmed.connect(_on_movement_confirmed)
	_movement_cancel_button.pressed.connect(_on_movement_cancelled)
	_viewport_container.gui_input.connect(_on_viewport_gui_input)

	_turn_timer = Timer.new()
	_turn_timer.wait_time = 1.0
	_turn_timer.timeout.connect(_on_turn_tick)
	add_child(_turn_timer)

	if not MatchContext.is_active:
		_loading_overlay.visible = false
		_fleet_panel.visible = false
		$UI/TurnPanel.visible = false
		$UI/RoundPanel.visible = false
		_ship_action_menu.hide_menu()
		return

	call_deferred("_build_battlefield")


func _process(_delta: float) -> void:
	_sync_movers_to_markers()


func _build_battlefield() -> void:
	_loading_overlay.visible = true
	_loading_label.text = "Loading battlefield..."
	await get_tree().process_frame

	var map_seed := MatchContext.get_battlefield_map_seed()
	if map_seed == 0:
		push_warning("BattleController: battlefield map seed missing.")

	var built := MapGenerator.build_map(map_seed)
	_map_anchor.add_child(built.root)
	_terrain = built.terrain

	if _map_camera.has_method("setup_for_terrain"):
		_map_camera.setup_for_terrain(_terrain)
	if _map_camera.has_signal("zoom_changed"):
		_map_camera.zoom_changed.connect(_on_camera_zoom_changed)
	if _map_camera.has_signal("view_changed"):
		_map_camera.view_changed.connect(_on_camera_view_changed)

	_grid_overlay.setup(_terrain)
	_on_camera_zoom_changed(_map_camera.get_zoom_out_ratio() if _map_camera.has_method("get_zoom_out_ratio") else 0.0)

	_player_ships = _spawn_player_fleet()
	_spawn_fleet_markers(MatchContext.enemy_placements, _enemy_fleet(), ENEMY_COLOR)

	_fleet_panel.populate_ships(_player_ships)
	_begin_player_round()

	var player_center := _fleet_center(_player_ships)
	if player_center != Vector3.ZERO and _map_camera.has_method("focus_on_world_point"):
		_map_camera.focus_on_world_point(player_center)

	_start_turn_timer()
	_loading_overlay.visible = false


func _spawn_player_fleet() -> Array:
	var ships: Array = []
	var fleet: Array = MatchContext.your_fleet
	var placements: Array = MatchContext.your_placements
	var name_counts: Dictionary = {}

	for placement in placements:
		if not placement is Dictionary:
			continue
		var ship_index := int(placement.get("ship_index", 0))
		var ship_name := str(placement.get("ship_name", _fleet_ship_name(fleet, ship_index)))
		var weapons: Array = []
		if ship_index >= 0 and ship_index < fleet.size() and fleet[ship_index] is Dictionary:
			var fleet_ship: Dictionary = fleet[ship_index]
			weapons = fleet_ship.get("weapons", [])

		name_counts[ship_name] = int(name_counts.get(ship_name, 0)) + 1
		var display_name := "%s #%d" % [ship_name, name_counts[ship_name]]

		var max_hp := int(SHIP_MAX_HP.get(ship_name, 100))
		var world := _placement_to_world(placement)
		var marker := _create_ship_marker(placement, ship_index, ship_name, FLEET_COLOR)

		var ship_state := {
			"ship_index": ship_index,
			"name": ship_name,
			"display_name": display_name,
			"weapons": weapons,
			"hp": max_hp,
			"max_hp": max_hp,
			"world_pos": world,
			"marker": marker,
		}
		BattleTurnManager.init_ship_round_state(ship_state)
		ships.append(ship_state)

	return ships


func _spawn_fleet_markers(placements: Array, fleet: Array, color: Color) -> void:
	if _terrain == null:
		return
	for entry in placements:
		if not entry is Dictionary:
			continue
		var ship_index := int(entry.get("ship_index", 0))
		var ship_name := str(entry.get("ship_name", _fleet_ship_name(fleet, ship_index)))
		_create_ship_marker(entry, ship_index, ship_name, color)


func _fleet_ship_name(fleet: Array, ship_index: int) -> String:
	if ship_index >= 0 and ship_index < fleet.size() and fleet[ship_index] is Dictionary:
		return str(fleet[ship_index].get("name", "Destroyer"))
	return "Destroyer"


func _enemy_fleet() -> Array:
	var local_name := MatchContext.local_username
	for player in MatchContext.players:
		var username := str(player.get("username", ""))
		if username != "" and username != local_name:
			var fleet_data = player.get("fleet", {})
			if fleet_data is Dictionary:
				return fleet_data.get("ships", [])
	return []


func _create_ship_marker(entry: Dictionary, ship_index: int, ship_name: String, color: Color) -> Node3D:
	var world := _placement_to_world(entry)
	var marker := BattleShipVisual.spawn_marker(
		ship_name,
		color,
		world,
		int(entry.get("rotation", 0))
	)
	marker.name = "ShipMarker_%d" % ship_index
	marker.set_meta("ship_index", ship_index)
	_ship_markers.add_child(marker)
	BattleShipVisual.finalize_marker(marker)
	return marker


func _placement_to_world(entry: Dictionary) -> Vector3:
	var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	var world := PlacementGenerator.grid_to_world(_terrain, cell)
	world.y = WATER_SURFACE_Y
	return world


func _fleet_center(ships: Array) -> Vector3:
	if ships.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for ship in ships:
		sum += ship.get("world_pos", Vector3.ZERO)
	return sum / float(ships.size())


func _get_player_ship(ship_index: int) -> Dictionary:
	for ship in _player_ships:
		if int(ship.get("ship_index", -1)) == ship_index:
			return ship
	return {}


func _select_ship(ship_index: int, glide_camera: bool = false) -> void:
	var ship := _get_player_ship(ship_index)
	if ship.is_empty():
		return

	_selected_ship_index = ship_index
	_fleet_panel.highlight_ship(ship_index)
	_update_marker_highlights(ship_index)

	var screen_pos := _world_to_screen(ship.get("world_pos", Vector3.ZERO))
	_ship_action_menu.show_for_ship(ship, screen_pos)

	if glide_camera and _map_camera.has_method("glide_to_world_point"):
		_map_camera.glide_to_world_point(ship.get("world_pos", Vector3.ZERO))


func _deselect_ship() -> void:
	_selected_ship_index = -1
	_fleet_panel.highlight_ship(-1)
	_update_marker_highlights(-1)
	_ship_action_menu.hide_menu()


func _update_marker_highlights(selected_index: int) -> void:
	for ship in _player_ships:
		var marker: Node3D = ship.get("marker")
		if marker == null:
			continue
		var is_selected := int(ship.get("ship_index", -1)) == selected_index
		BattleShipVisual.set_highlight(marker, is_selected)


func _world_to_screen(world_pos: Vector3) -> Vector2:
	if _map_camera.is_position_behind(world_pos):
		return Vector2(400, 300)
	var viewport_pos := _map_camera.unproject_position(world_pos)
	var container_pos := _viewport_container.get_global_rect().position
	return container_pos + viewport_pos


func _try_pick_player_ship(local_pos: Vector2) -> void:
	var origin := _map_camera.project_ray_origin(local_pos)
	var direction := _map_camera.project_ray_normal(local_pos)
	var plane := Plane(Vector3.UP, WATER_SURFACE_Y)
	var hit: Variant = plane.intersects_ray(origin, direction)
	if hit == null:
		_deselect_ship()
		return

	var hit_vec: Vector3 = hit
	var best_index := -1
	var best_dist := SHIP_PICK_RADIUS

	for ship in _player_ships:
		var pos: Vector3 = ship.get("world_pos", Vector3.ZERO)
		var dist := Vector2(hit_vec.x - pos.x, hit_vec.z - pos.z).length()
		if dist < best_dist:
			best_dist = dist
			best_index = int(ship.get("ship_index", -1))

	if best_index >= 0:
		_select_ship(best_index, false)
	else:
		_deselect_ship()


func _start_turn_timer() -> void:
	_turn_seconds_left = TURN_TIME_SEC
	_update_timer_label()
	_turn_timer.start()


func _update_timer_label() -> void:
	var minutes := _turn_seconds_left / 60
	var seconds := _turn_seconds_left % 60
	_timer_label.text = "%02d:%02d" % [minutes, seconds]


func _on_turn_tick() -> void:
	_turn_seconds_left = maxi(0, _turn_seconds_left - 1)
	_update_timer_label()
	if _turn_seconds_left <= 0:
		_on_end_turn_pressed()


func _on_end_turn_pressed() -> void:
	if _is_ai_turn:
		return
	_turn_timer.stop()
	_on_movement_cancelled()
	_deselect_ship()
	_set_player_input_enabled(false)
	await _run_ai_turn_stub()
	_round_number += 1
	_begin_player_round()
	_set_player_input_enabled(true)
	_start_turn_timer()


func _begin_player_round() -> void:
	BattleTurnManager.reset_fleet_for_round(_player_ships)
	_reset_ship_movers_for_new_turn()
	_update_round_label()
	_fleet_panel.refresh_all_ship_status(_player_ships)


func _update_round_label() -> void:
	if _is_ai_turn:
		_round_label.text = "Round %d — AI turn" % _round_number
	else:
		_round_label.text = "Round %d — Your turn" % _round_number


func _set_player_input_enabled(enabled: bool) -> void:
	_end_turn_button.disabled = not enabled
	_fleet_panel.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _run_ai_turn_stub() -> void:
	_is_ai_turn = true
	_update_round_label()

	var package := BattleTurnManager.build_turn_package(
		MatchContext.match_id,
		_round_number,
		MatchContext.local_username,
		_player_ships
	)
	print("[Battle] Turn package for FastAPI (stub):")
	print(JSON.stringify(package))

	await get_tree().create_timer(1.2).timeout

	var ai_response := {
		"match_id": MatchContext.match_id,
		"round": _round_number,
		"phase": "ai_turn_end",
		"action": "end_turn",
	}
	print("[Battle] AI response (stub):")
	print(JSON.stringify(ai_response))

	_is_ai_turn = false


func _on_fleet_ship_selected(ship_index: int) -> void:
	_select_ship(ship_index, true)


func _on_move_requested(ship_index: int) -> void:
	_ship_action_menu.hide_menu()
	_begin_movement_for_ship(ship_index)


func _begin_movement_for_ship(ship_index: int) -> void:
	var ship := _get_player_ship(ship_index)
	if ship.is_empty():
		return

	var mover := _get_or_create_mover(ship_index, ship)
	if not BattleTurnManager.can_move(ship):
		return

	_movement_ship_index = ship_index
	_movement_panel.set_selected_ship(mover)
	_movement_panel.visible = true


func _on_movement_confirmed(angle: float, distance: float) -> void:
	if _movement_ship_index < 0 or _is_ai_turn:
		return
	var ship := _get_player_ship(_movement_ship_index)
	if ship.is_empty() or not BattleTurnManager.can_move(ship):
		_on_movement_cancelled()
		return
	var mover := _ship_movers.get(_movement_ship_index) as NavalShip3D
	if mover == null:
		return
	mover.set_movement_target(angle, distance)
	BattleTurnManager.mark_moved(ship, angle, distance)
	_fleet_panel.update_ship_status(_movement_ship_index, ship)
	_movement_panel.visible = false
	_movement_ship_index = -1


func _on_movement_cancelled() -> void:
	_movement_panel.visible = false
	_movement_ship_index = -1


func _get_or_create_mover(ship_index: int, ship: Dictionary) -> BattleNavalShipAdapter:
	var existing := _ship_movers.get(ship_index) as BattleNavalShipAdapter
	if existing != null:
		var marker: Node3D = ship.get("marker")
		if marker:
			existing.configure_from_marker(marker)
		return existing

	var marker: Node3D = ship.get("marker")
	var mover := NAVAL_MOVER_SCENE.instantiate() as BattleNavalShipAdapter
	mover.name = "Mover_%d" % ship_index
	_ship_markers.add_child(mover)
	if marker:
		mover.configure_from_marker(marker)
	_ship_movers[ship_index] = mover
	return mover


func _reset_ship_movers_for_new_turn() -> void:
	for mover in _ship_movers.values():
		if mover is NavalShip3D:
			(mover as NavalShip3D).reset_turn_actions()


func _sync_movers_to_markers() -> void:
	for ship in _player_ships:
		var ship_index := int(ship.get("ship_index", -1))
		var mover := _ship_movers.get(ship_index) as NavalShip3D
		var marker: Node3D = ship.get("marker")
		if mover == null or marker == null:
			continue
		marker.global_position = mover.global_position
		marker.rotation.y = mover.rotation.y
		ship["world_pos"] = mover.global_position


func _on_fire_requested(ship_index: int, weapon_name: String) -> void:
	if _is_ai_turn:
		return
	var ship := _get_player_ship(ship_index)
	if ship.is_empty() or not BattleTurnManager.mark_fired(ship, weapon_name):
		return
	print("[Battle] Fire %s from ship %d (stub)" % [weapon_name, ship_index])
	_fleet_panel.update_ship_status(ship_index, ship)
	_ship_action_menu.hide_menu()


func _on_camera_zoom_changed(zoom_out_ratio: float) -> void:
	if _map_camera.has_method("should_show_km_grid"):
		_grid_overlay.set_grid_visible(_map_camera.should_show_km_grid())
	else:
		_grid_overlay.set_grid_visible(zoom_out_ratio >= 0.8)


func _on_camera_view_changed() -> void:
	if _selected_ship_index < 0:
		return
	var ship := _get_player_ship(_selected_ship_index)
	if ship.is_empty():
		return
	if _ship_action_menu.has_method("set_screen_anchor"):
		_ship_action_menu.set_screen_anchor(_world_to_screen(ship.get("world_pos", Vector3.ZERO)))


func _on_viewport_gui_input(event: InputEvent) -> void:
	if _loading_overlay.visible or not MatchContext.is_active or _is_ai_turn:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_left_click_start = mb.position
			elif _left_click_start.distance_to(mb.position) < CLICK_DRAG_THRESHOLD:
				_try_pick_player_ship(mb.position)
			return

	_forward_camera_input(event)


func _forward_camera_input(event: InputEvent) -> void:
	if _map_camera and _map_camera.has_method("handle_input_event"):
		_map_camera.handle_input_event(event)
