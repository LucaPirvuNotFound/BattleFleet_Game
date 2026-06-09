extends Node
## Autoload: ENet battle server (headless) or client connection to it.

const DEFAULT_PORT := 7777
const AI_USERNAME := "AI_Captain"

signal match_state_received(state: Dictionary)

var battle_state: Dictionary = {}
var is_server_running: bool = false
var _join_failed_message: String = ""


func _ready() -> void:
	if _should_run_battle_server():
		_start_server(_resolve_port())
		return
	# Dedicated server scene (F6 on BattleServerMain) — optional, for testing headless flow.
	call_deferred("_try_start_from_main_scene")
	if _use_embedded_battle_session():
		print("[BattleNetwork] Editor F5 mode: battle placement runs in-process (no separate server window).")


func _try_start_from_main_scene() -> void:
	if is_server_running:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	if str(scene.scene_file_path).ends_with("BattleServerMain.tscn"):
		_start_server(_resolve_port())


func _should_run_battle_server() -> bool:
	if OS.has_feature("server"):
		return true
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--battle-server":
			return true
	return false


func _resolve_port() -> int:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if str(args[i]) == "--port" and i + 1 < args.size():
			return int(args[i + 1])
	return DEFAULT_PORT


func _start_server(port: int) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("BattleNetwork: failed to start server on port %d (%s)" % [port, error_string(err)])
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	is_server_running = true
	print("[BattleNetwork] Server listening on port %d" % port)


func _use_embedded_battle_session() -> bool:
	if not OS.has_feature("editor"):
		return false
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--force-battle-server":
			return false
	return true


func connect_and_join(handoff: Dictionary, username: String) -> Dictionary:
	battle_state.clear()
	var match_id := str(handoff.get("match_id", ""))
	var token := str(handoff.get("battle_token", ""))

	if _use_embedded_battle_session():
		return await _connect_embedded(match_id, token, username)

	var host := str(handoff.get("battle_host", "127.0.0.1"))
	var port := int(handoff.get("battle_port", DEFAULT_PORT))

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		return {"success": false, "error": "Could not create client (%s)." % error_string(err)}

	multiplayer.multiplayer_peer = peer

	if not await _wait_for_connection(peer):
		return {
			"success": false,
			"error": "Could not connect to battle server at %s:%d. Start the Godot battle server first." % [host, port],
		}

	_join_failed_message = ""
	client_request_join.rpc_id(1, match_id, token, username)
	var received: Dictionary = await match_state_received
	if _join_failed_message != "":
		return {"success": false, "error": _join_failed_message}
	if received.is_empty():
		return {"success": false, "error": "Battle server did not return match state."}

	battle_state = received
	return {"success": true, "data": battle_state}


func _connect_embedded(match_id: String, battle_token: String, username: String) -> Dictionary:
	var session := await _fetch_battle_session(match_id, battle_token)
	if not session.get("success", false):
		return {"success": false, "error": str(session.get("error", "Session fetch failed"))}

	var state := _build_match_state(session["data"], username)
	battle_state = state
	print("[BattleNetwork] Embedded placement ready (editor F5).")
	return {"success": true, "data": state}


func _wait_for_connection(peer: ENetMultiplayerPeer) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _on_peer_connected(peer_id: int) -> void:
	print("[BattleNetwork] Peer connected: %d" % peer_id)


@rpc("any_peer", "call_remote", "reliable")
func client_request_join(match_id: String, battle_token: String, username: String) -> void:
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	var session := await _fetch_battle_session(match_id, battle_token)
	if not session.get("success", false):
		server_join_failed.rpc_id(peer_id, str(session.get("error", "Session fetch failed")))
		return

	var state := _build_match_state(session["data"], username)
	server_send_match_state.rpc_id(peer_id, state)


@rpc("authority", "call_remote", "reliable")
func server_send_match_state(state: Dictionary) -> void:
	battle_state = state
	match_state_received.emit(state)


@rpc("authority", "call_remote", "reliable")
func server_join_failed(message: String) -> void:
	_join_failed_message = message
	match_state_received.emit({})


func _fetch_battle_session(match_id: String, battle_token: String) -> Dictionary:
	var url := "%s/matches/%s/battle/session?token=%s" % [
		NetworkManager.api_client.BASE_URL,
		match_id,
		battle_token,
	]
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json"])
	var err := http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		return {"success": false, "error": "HTTP request failed"}

	var completed: Array = await http.request_completed
	http.queue_free()
	var response_code: int = completed[1]
	var body: PackedByteArray = completed[3]
	if response_code < 200 or response_code >= 300:
		return {"success": false, "error": "FastAPI session error (%d)" % response_code}

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed is Dictionary:
		return {"success": false, "error": "Invalid session response"}

	return {"success": true, "data": parsed}


func _build_match_state(session: Dictionary, joining_username: String) -> Dictionary:
	var map_seed := MatchContext.get_battlefield_map_seed()
	if map_seed == 0:
		map_seed = int(session.get("map_seed", 0))
	var terrain := MapGenerator.build_terrain(map_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed

	var players: Array = session.get("players", [])
	var placements_by_username: Dictionary = {}
	var your_placements: Array = []
	var enemy_placements: Array = []

	for player in players:
		var slot := int(player.get("slot", 0))
		var fleet_data: Dictionary = player.get("fleet", {})
		var fleet: Array = fleet_data.get("ships", [])
		var player_name := str(player.get("username", ""))
		var is_ai := bool(player.get("is_ai", false)) or player_name == AI_USERNAME

		var generated := PlacementGenerator.generate_fleet_placements(terrain, fleet, slot, rng)
		placements_by_username[player_name] = generated

		if player_name == joining_username:
			your_placements = generated
		elif not is_ai and joining_username != "":
			enemy_placements = generated
		elif is_ai:
			enemy_placements = generated

	terrain.queue_free()

	return {
		"success": true,
		"match_id": str(session.get("match_id", "")),
		"map_seed": map_seed,
		"map_index": int(session.get("map_index", 1)),
		"mode": str(session.get("mode", "")),
		"first_player_username": str(session.get("first_player_username", "")),
		"phase": "placement",
		"your_placements": your_placements,
		"enemy_placements": enemy_placements,
		"placements_by_username": placements_by_username,
		"placement_source": "godot_server",
	}
