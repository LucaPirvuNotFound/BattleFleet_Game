# DatabaseModels.gd
# All data-model classes for Battle Fleet 2 (Godot version).
# Access globally as:  BattleFleetModels.Player.new("Alice")
#                      BattleFleetModels.BattleRecord.new()  etc.

class_name BattleFleetModels


# ── Player ────────────────────────────────────────────────────────────────────

class Player:
	var player_id: int = 0
	var player_name: String = ""
	var created_date: String = ""
	var last_played_date: String = ""
	var is_active: bool = true
	var elo: int = 0

	func _init(p_name: String = "") -> void:
		player_name = p_name
		is_active = true
		created_date = Time.get_datetime_string_from_system()

	func _to_string() -> String:
		return "Player: %s (ID: %d)" % [player_name, player_id]


# ── PlayerStats ───────────────────────────────────────────────────────────────

class PlayerStats:
	var stat_id: int = 0
	var player_id: int = 0
	var total_battles: int = 0
	var total_wins: int = 0
	var total_losses: int = 0
	var total_draws: int = 0
	var average_accuracy: float = 0.0
	var total_ships_destroyed: int = 0
	var total_ships_lost: int = 0
	var last_updated: String = ""
	var battleship_kills: int = 0
	var battleship_deaths: int = 0
	var battleship_accuracy: int =0
	var cruiser_kills: int =0
	var cruiser_deaths: int =0
	var cruiser_accuracy: int =0
	var destroyer_kills: int =0
	var destroyer_deaths: int =0
	var destroyer_accuracy: int=0
	var corvette_kills: int = 0
	var corvette_deaths: int =0
	var corvette_accuracy: int=0
	var torpedo_boat_kills: int =0
	var torpedo_boat_deaths: int =0
	var torpedo_boat_accuracy: int =0

	func _init() -> void:
		last_updated = Time.get_datetime_string_from_system()

	func get_win_rate() -> float:
		if total_battles == 0:
			return 0.0
		return float(total_wins) / float(total_battles) * 100.0

	func _to_string() -> String:
		return "Stats — W-L-D:%d-%d-%d WinRate:%.1f%%" % [total_wins, total_losses, total_draws, get_win_rate()]



# ── BattleRecord ──────────────────────────────────────────────────────────────

class BattleRecord:
	var battle_id: int = 0
	var player_id: int = 0
	var opponent_name: String = ""
	var battle_date: String = ""
	## Win | Loss | Draw
	var result: int= 1 # presupun winner player=1, 2=openent wins
	var ships_destroyed: int = 0
	var ships_lost: int = 0
	## Easy | Normal | Hard | Expert
	var difficulty_level: String = "Normal"
	## SkirmishBattle | Campaign | Multiplayer
	var battle_mode: String = "SkirmishBattle"

	func _init() -> void:
		battle_date = Time.get_datetime_string_from_system()
		difficulty_level = "Normal"
		battle_mode = "SkirmishBattle"

	func _to_string() -> String:
		return "Battle vs %s (%s) — %s" % [opponent_name, battle_date, result]


# ── Move ──────────────────────────────────────────────────────────────
class Move:
	var move_id: int =0
	var turn_number: int = 0
	var match_id: int =0
	var player_id: int = 0
	var type: String = ""
	var distance: float = 0.0
	var angle: float = 0.0
	var position: String = ""

	func _init(p_match_id: int = 0, p_turn: int = 0) -> void:
		match_id = p_match_id
		turn_number = p_turn
		type = "Move"
		distance = 0.0
		angle = 0.0
		position = "0,0"

	func _to_string() -> String:
		return "Move #%d: Player %d performed %s at turn %d" % [move_id, player_id, type, turn_number]