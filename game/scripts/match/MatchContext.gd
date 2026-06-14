extends Node
## Autoload: snapshot of the active match returned by the API.

var match_id: String = ""
var mode: String = ""          # "pvp" | "pve" | "local"
var phase: String = ""         # "coin" | "placement" | "combat" | "finished"
var map_seed: int = 0
## Locked when the coin-flip map is generated — battle must reuse this exact seed.
var battlefield_map_seed: int = 0
var map_index: int = 1
var first_player_username: String = ""
var you_go_first: bool = false
var local_username: String = ""
var opponent_username: String = ""

## Fleet from menu: [{ "name": String, "weapons": Array[String] }, ...]
var your_fleet: Array = []
var your_fleet_total_cost: int = 0

var players: Array = []        # API player views
var is_active: bool = false

## Set in menu before MatchPrep ("pvp" | "pve" | "local").
var pending_mode: String = ""

var red_display_name: String = "Red Fleet"
var blue_display_name: String = "Blue Fleet"

## Hot-seat local: player 1 fleet saved while player 2 builds on the same menu.
var local_host_fleet: Array = []
var local_host_fleet_total_cost: int = 0
var local_host_display_name: String = ""
var local_guest_fleet: Array = []
var local_guest_fleet_total_cost: int = 0
var local_guest_display_name: String = ""
var local_awaiting_guest_fleet: bool = false

## Godot battle server handoff (from FastAPI POST /battle/handoff).
var battle_host: String = ""
var battle_port: int = 0
var battle_token: String = ""
var your_placements: Array = []
var enemy_placements: Array = []
var placement_source: String = ""
var battle_connected: bool = false


func apply_handoff(data: Dictionary) -> void:
	match_id = str(data.get("match_id", match_id))
	mode = str(data.get("mode", mode))
	map_seed = int(data.get("map_seed", map_seed))
	map_index = int(data.get("map_index", map_index))
	first_player_username = str(data.get("first_player_username", first_player_username))
	you_go_first = bool(data.get("you_go_first", you_go_first))
	local_username = str(data.get("local_username", local_username))
	if data.has("players"):
		players = data.get("players", players)
	phase = "combat"
	is_active = match_id != ""
	battle_host = str(data.get("battle_host", ""))
	battle_port = int(data.get("battle_port", 0))
	battle_token = str(data.get("battle_token", ""))


func lock_battlefield_map() -> void:
	if map_seed != 0:
		battlefield_map_seed = map_seed


func get_battlefield_map_seed() -> int:
	if battlefield_map_seed != 0:
		return battlefield_map_seed
	return map_seed


func apply_battle_state(data: Dictionary) -> void:
	phase = str(data.get("phase", "placement"))
	your_placements = data.get("your_placements", [])
	enemy_placements = data.get("enemy_placements", [])
	placement_source = str(data.get("placement_source", ""))
	battle_connected = true


func apply_snapshot(data: Dictionary) -> void:
	match_id = str(data.get("match_id", ""))
	mode = str(data.get("mode", ""))
	phase = str(data.get("phase", ""))
	var incoming_seed := int(data.get("map_seed", 0))
	if incoming_seed != 0:
		map_seed = incoming_seed
	map_index = int(data.get("map_index", 1))
	first_player_username = str(data.get("first_player_username", ""))
	you_go_first = bool(data.get("you_go_first", false))
	local_username = str(data.get("local_username", ""))
	opponent_username = str(data.get("opponent_username", ""))
	players = data.get("players", [])
	is_active = match_id != ""
	_sync_local_display_names_from_players()


func set_local_fleet(fleet: Array, total_cost: int) -> void:
	your_fleet = fleet.duplicate(true)
	your_fleet_total_cost = total_cost


func save_local_host_fleet(fleet: Array, total_cost: int, display_name: String) -> void:
	local_host_fleet = fleet.duplicate(true)
	local_host_fleet_total_cost = total_cost
	local_host_display_name = display_name
	local_awaiting_guest_fleet = true
	your_fleet = local_host_fleet.duplicate(true)
	your_fleet_total_cost = local_host_fleet_total_cost


func save_local_guest_fleet(fleet: Array, total_cost: int) -> void:
	local_guest_fleet = fleet.duplicate(true)
	local_guest_fleet_total_cost = total_cost
	your_fleet = local_host_fleet.duplicate(true)
	your_fleet_total_cost = local_host_fleet_total_cost


func clear_local_two_player_setup() -> void:
	local_host_fleet.clear()
	local_host_fleet_total_cost = 0
	local_host_display_name = ""
	local_guest_fleet.clear()
	local_guest_fleet_total_cost = 0
	local_guest_display_name = ""
	local_awaiting_guest_fleet = false


func configure_player_sides() -> void:
	if mode == "local":
		var host := _local_host_label()
		var guest := _local_guest_label()
		if you_go_first:
			blue_display_name = host
			red_display_name = guest
		else:
			red_display_name = host
			blue_display_name = guest
		return

	var you := local_username if local_username != "" else "You"
	var foe := opponent_username if opponent_username != "" else "Opponent"
	if you_go_first:
		blue_display_name = you
		red_display_name = foe
	else:
		red_display_name = you
		blue_display_name = foe


func _local_host_label() -> String:
	if local_host_display_name != "":
		return local_host_display_name
	if local_username != "":
		return local_username
	return "Guest"


func _local_guest_label() -> String:
	if local_guest_display_name != "":
		return local_guest_display_name
	if opponent_username != "" and opponent_username != "Local_Opponent":
		return opponent_username
	return "%s's guest" % _local_host_label()


func _sync_local_display_names_from_players() -> void:
	if mode != "local":
		return
	for player in players:
		var player_name := str(player.get("username", ""))
		if player_name.is_empty():
			continue
		if bool(player.get("is_you", false)):
			if local_host_display_name == "":
				local_host_display_name = player_name
		elif player_name != "Local_Opponent":
			if local_guest_display_name == "":
				local_guest_display_name = player_name
			opponent_username = player_name


func get_your_player() -> Dictionary:
	for player in players:
		if bool(player.get("is_you", false)):
			return player
	return {}


func clear() -> void:
	match_id = ""
	mode = ""
	phase = ""
	map_seed = 0
	battlefield_map_seed = 0
	map_index = 1
	first_player_username = ""
	you_go_first = false
	local_username = ""
	opponent_username = ""
	your_fleet.clear()
	your_fleet_total_cost = 0
	players.clear()
	is_active = false
	pending_mode = ""
	red_display_name = "Red Fleet"
	blue_display_name = "Blue Fleet"
	clear_local_two_player_setup()
	battle_host = ""
	battle_port = 0
	battle_token = ""
	your_placements.clear()
	enemy_placements.clear()
	placement_source = ""
	battle_connected = false
