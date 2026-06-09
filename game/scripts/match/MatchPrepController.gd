extends Control

const BATTLE_SCENE := preload("res://scenes/battle/Battle.tscn")
const POST_COIN_COUNTDOWN_SEC := 5
const COIN_SPIN_DURATION := 3.0
const COIN_FULL_SPINS := 4
const COIN_RADIUS := 3.5
const COIN_DISC_THICKNESS := 0.08
const COIN_HALF_SEP := 0.14
const COIN_BORDER_THICKNESS := 0.28
## Two discs on ±Z; camera at +Z sees blue at 0, red at PI (matches you_go_first → BLUE/RED text).
const COIN_LAND_BLUE_X := 0.0
const COIN_LAND_RED_X := PI

@onready var _map_anchor: Node3D = %MapAnchor
@onready var _map_camera: Camera3D = %MapCamera
@onready var _coin_camera: Camera3D = %CoinCamera
@onready var _coin_pivot: Node3D = %CoinPivot

@onready var _loading_overlay: Control = %LoadingOverlay
@onready var _loading_label: Label = %LoadingLabel
@onready var _loading_bar: ProgressBar = %LoadingBar

@onready var _coin_overlay: Control = %CoinOverlay
@onready var _red_name_label: Label = %RedPlayerName
@onready var _blue_name_label: Label = %BluePlayerName
@onready var _coin_hud_panel: PanelContainer = %CoinHudPanel
@onready var _coin_title_label: Label = %CoinTitleLabel
@onready var _coin_message_label: Label = %CoinMessageLabel
@onready var _coin_result_label: Label = %CoinResultLabel

@onready var _matchmaking_overlay: Control = %MatchmakingOverlay
@onready var _matchmaking_label: Label = %MatchmakingLabel

var _map_root: Node3D
var _terrain: MeshInstance3D
var _water: Node3D

var _mat_coin_red: StandardMaterial3D
var _mat_coin_blue: StandardMaterial3D
var _mat_coin_edge: StandardMaterial3D
var _coin_faces_built: bool = false


func _ready() -> void:
	_build_coin_materials()
	_hide_all_overlays()
	_coin_pivot.visible = false
	_matchmaking_overlay.visible = false
	call_deferred("_run_match_prep_flow")


func _build_coin_materials() -> void:
	_mat_coin_red = StandardMaterial3D.new()
	_mat_coin_red.albedo_color = Color(0.92, 0.18, 0.14)
	_mat_coin_red.emission_enabled = true
	_mat_coin_red.emission = Color(0.35, 0.06, 0.05)
	_mat_coin_red.metallic = 0.35
	_mat_coin_red.roughness = 0.25
	_mat_coin_red.cull_mode = BaseMaterial3D.CULL_DISABLED

	_mat_coin_blue = StandardMaterial3D.new()
	_mat_coin_blue.albedo_color = Color(0.15, 0.45, 0.98)
	_mat_coin_blue.emission_enabled = true
	_mat_coin_blue.emission = Color(0.05, 0.12, 0.35)
	_mat_coin_blue.metallic = 0.35
	_mat_coin_blue.roughness = 0.25
	_mat_coin_blue.cull_mode = BaseMaterial3D.CULL_DISABLED

	_mat_coin_edge = StandardMaterial3D.new()
	_mat_coin_edge.albedo_color = Color(0.42, 0.44, 0.5)
	_mat_coin_edge.emission_enabled = true
	_mat_coin_edge.emission = Color(0.06, 0.06, 0.08)
	_mat_coin_edge.metallic = 0.85
	_mat_coin_edge.roughness = 0.22


func _make_coin_disc(mat: Material, local_z: float, disc_name: String) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.name = disc_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = COIN_RADIUS
	cyl.bottom_radius = COIN_RADIUS
	cyl.height = COIN_DISC_THICKNESS
	cyl.radial_segments = 64
	disc.mesh = cyl
	disc.material_override = mat
	disc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	disc.position = Vector3(0.0, 0.0, local_z)
	return disc


func _make_coin_barrel() -> MeshInstance3D:
	## Fills the gap between the two face discs along the coin edge.
	var barrel := MeshInstance3D.new()
	barrel.name = "CoinBarrel"
	var cyl := CylinderMesh.new()
	var barrel_radius := COIN_RADIUS - 0.04
	cyl.top_radius = barrel_radius
	cyl.bottom_radius = barrel_radius
	cyl.height = COIN_BORDER_THICKNESS
	cyl.radial_segments = 64
	barrel.mesh = cyl
	barrel.material_override = _mat_coin_edge
	barrel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	return barrel


func _make_coin_rim() -> MeshInstance3D:
	## Raised outer ring so the coin has a visible metal border when face-on or spinning.
	var rim := MeshInstance3D.new()
	rim.name = "CoinRim"
	var torus := TorusMesh.new()
	torus.inner_radius = COIN_RADIUS - 0.06
	torus.outer_radius = COIN_RADIUS + 0.22
	torus.rings = 8
	torus.ring_segments = 64
	rim.mesh = torus
	rim.material_override = _mat_coin_edge
	rim.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	return rim


func _build_coin_faces() -> void:
	if _coin_faces_built:
		return

	for child in _coin_pivot.get_children():
		child.queue_free()

	# Barrel + rim hide the seam between the two colored face discs.
	_coin_pivot.add_child(_make_coin_barrel())
	_coin_pivot.add_child(_make_coin_disc(_mat_coin_red, -COIN_HALF_SEP, "DiscRed"))
	_coin_pivot.add_child(_make_coin_disc(_mat_coin_blue, COIN_HALF_SEP, "DiscBlue"))
	_coin_pivot.add_child(_make_coin_rim())
	_coin_faces_built = true


func _run_match_prep_flow() -> void:
	await get_tree().process_frame

	var match_ready := false
	match_ready = await _resolve_match_from_server()
	if not match_ready:
		return

	await _build_map_phase()
	await _run_coin_phase()

	if not MatchContext.is_active:
		return

	var coin_result := await NetworkManager.match_service.coin_ack(MatchContext.match_id)
	if not coin_result.success:
		await _show_flow_error("Coin ack failed: %s" % str(coin_result.get("error", "unknown")))
		return

	var handoff := await NetworkManager.match_service.request_battle_handoff(MatchContext.match_id)
	if not handoff.success:
		await _show_flow_error("Battle handoff failed: %s" % str(handoff.get("error", "unknown")))
		return

	_loading_overlay.visible = true
	_loading_label.text = "Connecting to battle server..."
	_loading_bar.value = 0.5
	await get_tree().process_frame

	var username := MatchContext.local_username
	if username == "":
		username = "Guest"

	var join := await BattleNetwork.connect_and_join(handoff.data, username)
	_loading_overlay.visible = false

	if not join.success:
		await _show_flow_error(str(join.get("error", "Could not join battle server.")))
		return

	MatchContext.apply_battle_state(join.data)
	get_tree().change_scene_to_packed(BATTLE_SCENE)


func _resolve_match_from_server() -> bool:
	if MatchContext.pending_mode == "pvp":
		if MatchContext.is_active:
			return true
		return await _run_fastapi_matchmaking()
	if MatchContext.pending_mode == "local" and not MatchContext.local_guest_fleet.is_empty():
		return await _run_local_instant_match()
	return await _run_fastapi_instant_match()


func _build_map_phase() -> void:
	_loading_overlay.visible = true
	_loading_label.text = "Generating map..."
	_loading_bar.value = 0.0
	await get_tree().process_frame

	_loading_bar.value = 0.25
	await get_tree().process_frame

	var built: Dictionary = MapGenerator.build_map(MatchContext.map_seed)
	_map_root = built.root
	_terrain = built.terrain
	_water = built.water
	_map_anchor.add_child(_map_root)

	_loading_bar.value = 0.9
	await get_tree().process_frame

	MatchContext.lock_battlefield_map()
	_fit_camera_to_map()
	_loading_bar.value = 1.0
	await get_tree().create_timer(0.35).timeout
	_loading_overlay.visible = false


func _run_local_instant_match() -> bool:
	_matchmaking_overlay.visible = true
	_matchmaking_label.text = "Preparing local match..."

	var host_payload := NetworkManager.fleet_service.build_fleet_payload(
		MatchContext.local_host_fleet,
		MatchContext.local_host_fleet_total_cost
	)
	var guest_payload := NetworkManager.fleet_service.build_fleet_payload(
		MatchContext.local_guest_fleet,
		MatchContext.local_guest_fleet_total_cost
	)
	var result := await NetworkManager.match_service.create_local_match(
		host_payload,
		guest_payload,
		MatchContext.local_guest_display_name
	)
	_matchmaking_overlay.visible = false

	if not result.success:
		_matchmaking_label.text = "Match failed: %s" % result.get("error", "")
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_packed(preload("res://scenes/menus/MainMenu.tscn"))
		return false

	return true


func _fit_camera_to_map() -> void:
	var height := 420.0
	var ortho_size := 520.0
	if _terrain:
		if _terrain.has_method("get_height"):
			height = maxf(280.0, float(_terrain.height) * 3.5)
		ortho_size = maxf(400.0, float(_terrain.size) * 0.85)
	_map_camera.position = Vector3(0.0, height, 0.0)
	_map_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_map_camera.size = ortho_size
	_map_camera.current = true
	_coin_camera.current = false


func _focus_camera_on_coin() -> void:
	var coin_pos := Vector3(0.0, _get_coin_height(), 0.0)
	_coin_pivot.position = coin_pos
	# Straight-on view along +Z so the coin lands flat facing the camera.
	_coin_camera.position = coin_pos + Vector3(0.0, 0.0, 32.0)
	_coin_camera.rotation = Vector3.ZERO
	_coin_camera.look_at(coin_pos, Vector3.UP)
	_map_camera.current = false
	_coin_camera.current = true


func _coin_land_rotation_x(land_on_blue: bool) -> float:
	return COIN_LAND_BLUE_X if land_on_blue else COIN_LAND_RED_X


func _play_coin_flip_animation(land_on_blue: bool) -> void:
	var target_x := _coin_land_rotation_x(land_on_blue)
	var end_x := target_x + TAU * float(COIN_FULL_SPINS)

	_coin_pivot.rotation = Vector3.ZERO
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_coin_pivot, "rotation:x", end_x, COIN_SPIN_DURATION)
	await tween.finished
	_coin_pivot.rotation = Vector3(target_x, 0.0, 0.0)


func _run_coin_phase() -> void:
	_configure_player_names_from_match()
	_build_coin_faces()
	_coin_overlay.visible = true
	_coin_hud_panel.visible = true
	_coin_pivot.visible = true
	_coin_result_label.visible = false
	_coin_title_label.text = "Coin Flip"
	_coin_message_label.text = "Coin spinning..."
	_focus_camera_on_coin()

	var land_on_blue := MatchContext.you_go_first
	await _play_coin_flip_animation(land_on_blue)

	var winner_color := "BLUE" if land_on_blue else "RED"
	_coin_result_label.visible = true
	_coin_result_label.text = "%s goes first!" % winner_color
	_coin_message_label.text = "%s wins the toss" % winner_color

	await _run_post_coin_countdown()

	_coin_overlay.visible = false
	_coin_hud_panel.visible = false
	_coin_pivot.visible = false
	_map_camera.current = true
	_coin_camera.current = false
	_fit_camera_to_map()


func _run_post_coin_countdown() -> void:
	for seconds_left in range(POST_COIN_COUNTDOWN_SEC, -1, -1):
		_coin_message_label.text = "Game starts in %d" % seconds_left
		await get_tree().create_timer(1.0).timeout


func _run_fastapi_matchmaking() -> bool:
	_matchmaking_overlay.visible = true
	_matchmaking_label.text = "Finding opponent (FastAPI queue)..."

	var fleet_payload := NetworkManager.fleet_service.build_fleet_payload(
		MatchContext.your_fleet,
		MatchContext.your_fleet_total_cost
	)

	var join := await NetworkManager.matchmaking_service.join_queue("pvp", fleet_payload)
	if not join.success:
		_matchmaking_label.text = "Queue failed: %s" % join.get("error", "")
		await get_tree().create_timer(2.5).timeout
		get_tree().change_scene_to_packed(preload("res://scenes/menus/MainMenu.tscn"))
		return false

	var poll := await NetworkManager.matchmaking_service.poll_until_matched()
	if not poll.success:
		_matchmaking_label.text = "Matchmaking failed: %s" % poll.get("error", "")
		await get_tree().create_timer(2.5).timeout
		get_tree().change_scene_to_packed(preload("res://scenes/menus/MainMenu.tscn"))
		return false

	var fetch := await NetworkManager.match_service.fetch_match(str(poll.match_id))
	_matchmaking_overlay.visible = false
	if not fetch.success:
		_matchmaking_label.text = "Could not load match."
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_packed(preload("res://scenes/menus/MainMenu.tscn"))
		return false

	return true


func _run_fastapi_instant_match() -> bool:
	_matchmaking_overlay.visible = true
	_matchmaking_label.text = "Preparing match..."

	var fleet_payload := NetworkManager.fleet_service.build_fleet_payload(
		MatchContext.your_fleet,
		MatchContext.your_fleet_total_cost
	)
	var result := await NetworkManager.match_service.create_instant_match(
		MatchContext.pending_mode,
		fleet_payload
	)
	_matchmaking_overlay.visible = false

	if not result.success:
		_matchmaking_label.text = "Match failed: %s" % result.get("error", "")
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_packed(preload("res://scenes/menus/MainMenu.tscn"))
		return false

	return true


func _configure_player_names_from_match() -> void:
	MatchContext.configure_player_sides()
	_red_name_label.text = MatchContext.red_display_name
	_blue_name_label.text = MatchContext.blue_display_name


func _get_coin_height() -> float:
	if _terrain and _terrain.has_method("get_height"):
		return maxf(22.0, _terrain.get_height(0.0, 0.0) + 16.0)
	return 32.0


func _hide_all_overlays() -> void:
	_loading_overlay.visible = false
	_coin_overlay.visible = false
	_coin_hud_panel.visible = false
	_matchmaking_overlay.visible = false


func _show_flow_error(message: String) -> void:
	_matchmaking_overlay.visible = true
	_matchmaking_label.text = message
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_packed(preload("res://scenes/menus/MainMenu.tscn"))
