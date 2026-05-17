# CaptainRepository.gd
# Captain CRUD, XP/level progression, command card unlocking, and accuracy bonuses.
#
# XP awarded per battle:
#   Win          +150 XP
#   Loss         +50  XP
#   Draw         +75  XP
#   Per ship destroyed: +25 XP
#
# Accuracy bonus formula: (captain_level - 1) * 2.0%
# Command cards: one card auto-unlocked at each captain level (Levels 1-5).

class_name CaptainRepository
extends RefCounted

signal captain_leveled_up(captain_id: int, old_level: int, new_level: int, new_accuracy_bonus: float)

const XP_VICTORY            := 150
const XP_DEFEAT             := 50
const XP_DRAW               := 75
const XP_PER_SHIP_DESTROYED := 25
const ACCURACY_PER_LEVEL    := 2.0  # percentage points per level above 1


# ── READ ──────────────────────────────────────────────────────────────────────

func get_captain(captain_id: int) -> BattleFleetModels.Captain:
	var rows := DatabaseManager.execute_reader(
		"SELECT * FROM Captains WHERE CaptainID = ?", [captain_id]
	)
	if rows.is_empty():
		return null
	return _map_captain(rows[0])


func get_captains_by_player(player_id: int) -> Array:
	var rows := DatabaseManager.execute_reader(
		"SELECT * FROM Captains WHERE PlayerID = ? AND IsAvailable = 1", [player_id]
	)
	var captains: Array = []
	for row in rows:
		captains.append(_map_captain(row))
	return captains


# ── CREATE ────────────────────────────────────────────────────────────────────

## Creates a new captain at Level 1 and automatically unlocks Level 1 command cards.
## Returns the new CaptainID, or -1 on failure.
func create_captain(captain: BattleFleetModels.Captain) -> int:
	var now := Time.get_datetime_string_from_system()
	var result := DatabaseManager.execute_non_query(
		"""INSERT INTO Captains
		   (PlayerID, CaptainName, ExperiencePoints, Level,
		    SpecializationClass, BattlesParticipated, CreatedDate, IsAvailable, AccuracyBonus)
		   VALUES (?, ?, 0, 1, ?, 0, ?, 1, 0.0)""",
		[captain.player_id, captain.captain_name, captain.specialization_class, now]
	)
	if result <= 0:
		push_error("CaptainRepository: Failed to create captain '%s'." % captain.captain_name)
		return -1

	var captain_id: int = DatabaseManager.get_last_insert_id()
	_unlock_eligible_command_cards(captain_id, 1)
	print("CaptainRepository: Created captain '%s' (ID: %d)." % [captain.captain_name, captain_id])
	return captain_id


# ── XP & LEVELLING ────────────────────────────────────────────────────────────

## Awards battle XP to a captain, handles level-up and command card unlocks.
## Returns the captain's new level, or -1 on error.
func award_battle_xp(captain_id: int, battle: BattleFleetModels.BattleRecord) -> int:
	var captain := get_captain(captain_id)
	if captain == null:
		push_error("CaptainRepository: Captain %d not found." % captain_id)
		return -1

	var xp_gained: int   = _calculate_battle_xp(battle)
	var prev_level: int  = captain.level

	captain.experience_points   += xp_gained
	captain.level                = calculate_captain_level(captain.experience_points)
	captain.battles_participated += 1
	captain.accuracy_bonus       = (captain.level - 1) * ACCURACY_PER_LEVEL

	_update_captain(captain)

	if captain.level > prev_level:
		print("CaptainRepository: Captain '%s' leveled up! %d → %d. Accuracy bonus: +%.1f%%" % [
			captain.captain_name, prev_level, captain.level, captain.accuracy_bonus])
		_unlock_eligible_command_cards(captain_id, captain.level)
		emit_signal("captain_leveled_up", captain_id, prev_level, captain.level, captain.accuracy_bonus)
	else:
		print("CaptainRepository: Captain '%s' gained %d XP (total: %d). Accuracy: +%.1f%%" % [
			captain.captain_name, xp_gained, captain.experience_points, captain.accuracy_bonus])

	return captain.level


# ── ACCURACY ─────────────────────────────────────────────────────────────────

## Returns accuracy bonus (percentage points) for a captain: (level - 1) * 2.0%
func get_captain_accuracy_bonus(captain_id: int) -> float:
	var captain := get_captain(captain_id)
	return captain.accuracy_bonus if captain != null else 0.0


# ── COMMAND CARDS ─────────────────────────────────────────────────────────────

## Returns all command card definitions ordered by required level.
func get_all_command_cards() -> Array:
	var rows := DatabaseManager.execute_reader(
		"SELECT * FROM CommandCards ORDER BY RequiredCaptainLevel ASC"
	)
	var cards: Array = []
	for row in rows:
		cards.append(_map_command_card(row))
	return cards


## Returns only the command cards this captain has already unlocked.
func get_unlocked_command_cards(captain_id: int) -> Array:
	var rows := DatabaseManager.execute_reader(
		"""SELECT cc.*
		   FROM CommandCards cc
		   INNER JOIN CaptainCommandCards ccc ON cc.CardID = ccc.CardID
		   WHERE ccc.CaptainID = ?
		   ORDER BY cc.RequiredCaptainLevel ASC""",
		[captain_id]
	)
	var cards: Array = []
	for row in rows:
		cards.append(_map_command_card(row))
	return cards


# ── HELPERS ───────────────────────────────────────────────────────────────────

## Quadratic XP curve mirroring PlayerStatsRepository.calculate_fleet_level.
## Level 1 = 0 XP | Level 2 = 100 | Level 3 = 300 | Level 4 = 600 …
static func calculate_captain_level(total_xp: int) -> int:
	var level: int     = 1
	var xp_needed: int = 0
	while total_xp >= xp_needed + level * 100:
		xp_needed += level * 100
		level     += 1
	return level


func _calculate_battle_xp(battle: BattleFleetModels.BattleRecord) -> int:
	var xp: int
	match battle.result:
		"Win":  xp = XP_VICTORY
		"Loss": xp = XP_DEFEAT
		_:      xp = XP_DRAW
	xp += battle.ships_destroyed * XP_PER_SHIP_DESTROYED
	return xp


## Auto-unlocks all command cards whose required level <= captain_level.
## INSERT OR IGNORE prevents duplicates if called multiple times.
func _unlock_eligible_command_cards(captain_id: int, captain_level: int) -> void:
	var now := Time.get_datetime_string_from_system()
	var cards := DatabaseManager.execute_reader(
		"SELECT CardID FROM CommandCards WHERE RequiredCaptainLevel <= ?", [captain_level]
	)
	for card_row in cards:
		DatabaseManager.execute_non_query(
			"INSERT OR IGNORE INTO CaptainCommandCards (CaptainID, CardID, UnlockedDate) VALUES (?, ?, ?)",
			[captain_id, int(card_row.get("CardID", 0)), now]
		)


func _update_captain(captain: BattleFleetModels.Captain) -> bool:
	var result := DatabaseManager.execute_non_query(
		"""UPDATE Captains
		   SET ExperiencePoints = ?, Level = ?, BattlesParticipated = ?, AccuracyBonus = ?
		   WHERE CaptainID = ?""",
		[captain.experience_points, captain.level, captain.battles_participated,
		 captain.accuracy_bonus, captain.captain_id]
	)
	return result > 0


func _map_captain(row: Dictionary) -> BattleFleetModels.Captain:
	var c := BattleFleetModels.Captain.new()
	c.captain_id            = int(row.get("CaptainID", 0))
	c.player_id             = int(row.get("PlayerID", 0))
	c.captain_name          = str(row.get("CaptainName", ""))
	c.experience_points     = int(row.get("ExperiencePoints", 0))
	c.level                 = int(row.get("Level", 1))
	c.specialization_class  = str(row.get("SpecializationClass", "General"))
	c.battles_participated  = int(row.get("BattlesParticipated", 0))
	c.created_date          = str(row.get("CreatedDate", ""))
	c.is_available          = int(row.get("IsAvailable", 1)) == 1
	c.accuracy_bonus        = float(row.get("AccuracyBonus", 0.0))
	return c


func _map_command_card(row: Dictionary) -> BattleFleetModels.CommandCard:
	var card := BattleFleetModels.CommandCard.new()
	card.card_id               = int(row.get("CardID", 0))
	card.card_name             = str(row.get("CardName", ""))
	card.description           = str(row.get("Description", ""))
	card.required_captain_level = int(row.get("RequiredCaptainLevel", 1))
	card.accuracy_bonus        = float(row.get("AccuracyBonus", 0.0))
	card.card_type             = str(row.get("CardType", "Tactical"))
	return card
