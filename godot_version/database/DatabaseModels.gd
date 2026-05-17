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
	## Separate from player stats Level — gates ship unlocks via ShipUnlockRequirements
	var fleet_level: int = 1
	var fleet_xp: int = 0

	func _init(p_name: String = "") -> void:
		player_name = p_name
		is_active = true
		created_date = Time.get_datetime_string_from_system()

	func _to_string() -> String:
		return "Player: %s (ID: %d) | Fleet Lvl %d" % [player_name, player_id, fleet_level]


# ── PlayerStats ───────────────────────────────────────────────────────────────

class PlayerStats:
	var stat_id: int = 0
	var player_id: int = 0
	## Overall player level derived from TotalExperience (flat 1000 XP/level curve)
	var level: int = 1
	var total_experience: int = 0
	var total_battles: int = 0
	var total_wins: int = 0
	var total_losses: int = 0
	var total_draws: int = 0
	var average_accuracy: float = 0.0
	var total_ships_destroyed: int = 0
	var total_ships_lost: int = 0
	var campaign_progress_percentage: float = 0.0
	var highest_level: int = 1
	var last_updated: String = ""

	func _init() -> void:
		level = 1
		highest_level = 1
		last_updated = Time.get_datetime_string_from_system()

	func get_win_rate() -> float:
		if total_battles == 0:
			return 0.0
		return float(total_wins) / float(total_battles) * 100.0

	func _to_string() -> String:
		return "Stats — Lvl:%d XP:%d W-L-D:%d-%d-%d WinRate:%.1f%%" % [
			level, total_experience, total_wins, total_losses, total_draws, get_win_rate()
		]


# ── Captain ───────────────────────────────────────────────────────────────────

class Captain:
	var captain_id: int = 0
	var player_id: int = 0
	var captain_name: String = ""
	var experience_points: int = 0
	var level: int = 1
	## General | Aggressive | Defensive | Scout
	var specialization_class: String = "General"
	var battles_participated: int = 0
	var created_date: String = ""
	var is_available: bool = true
	## Accuracy bonus in percentage points: (level - 1) * 2.0
	var accuracy_bonus: float = 0.0

	func _init(p_name: String = "", spec: String = "General") -> void:
		captain_name = p_name
		specialization_class = spec
		level = 1
		is_available = true
		accuracy_bonus = 0.0
		created_date = Time.get_datetime_string_from_system()


# ── CommandCard ───────────────────────────────────────────────────────────────

class CommandCard:
	var card_id: int = 0
	var card_name: String = ""
	var description: String = ""
	var required_captain_level: int = 1
	## Extra accuracy bonus while this card is active
	var accuracy_bonus: float = 0.0
	## Tactical | Offensive | Defensive
	var card_type: String = "Tactical"

	func _to_string() -> String:
		return "[Lvl %d] %s (%s) — %s" % [required_captain_level, card_name, card_type, description]


# ── CaptainCommandCard ────────────────────────────────────────────────────────

class CaptainCommandCard:
	var id: int = 0
	var captain_id: int = 0
	var card_id: int = 0
	var unlocked_date: String = ""


# ── BattleRecord ──────────────────────────────────────────────────────────────

class BattleRecord:
	var battle_id: int = 0
	var player_id: int = 0
	var opponent_name: String = ""
	var battle_date: String = ""
	## Win | Loss | Draw
	var result: String = ""
	var ships_destroyed: int = 0
	var ships_lost: int = 0
	var experience_gained: int = 0
	## Easy | Normal | Hard | Expert
	var difficulty_level: String = "Normal"
	## SkirmishBattle | Campaign | Multiplayer
	var battle_mode: String = "SkirmishBattle"

	func _init() -> void:
		battle_date = Time.get_datetime_string_from_system()
		difficulty_level = "Normal"
		battle_mode = "SkirmishBattle"

	func _to_string() -> String:
		return "Battle vs %s (%s) — %s | XP: +%d" % [opponent_name, battle_date, result, experience_gained]


# ── CampaignSave ──────────────────────────────────────────────────────────────

class CampaignSave:
	var save_id: int = 0
	var player_id: int = 0
	var campaign_name: String = ""
	var current_turn: int = 1
	var territory_controlled: int = 0
	var resource_points: int = 0
	var enemy_faction: String = "Japan"
	var difficulty_level: String = "Normal"
	var save_date: String = ""
	var last_loaded_date: String = ""
	var is_active: bool = true

	func _init(p_campaign_name: String = "", difficulty: String = "Normal") -> void:
		campaign_name = p_campaign_name
		current_turn = 1
		resource_points = 0
		enemy_faction = "Japan"
		difficulty_level = difficulty
		save_date = Time.get_datetime_string_from_system()
		is_active = true


# ── ShipUnlockRequirement ─────────────────────────────────────────────────────

class ShipUnlockRequirement:
	var ship_type: String = ""
	var required_level: int = 1
	var display_name: String = ""
	var description: String = ""


# ── ShipUnlockStatus ──────────────────────────────────────────────────────────

class ShipUnlockStatus:
	var ship_type: String = ""
	var display_name: String = ""
	var required_level: int = 1
	var is_unlocked: bool = false
	var description: String = ""

	func get_unlock_label() -> String:
		return "Unlocked" if is_unlocked else "Requires Fleet Level %d" % required_level
