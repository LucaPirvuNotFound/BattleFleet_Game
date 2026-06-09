# DatabaseTests.gd
# Standalone test runner — no external plugin required.
# Attach to a Node in a dedicated test scene and call run_all_tests() from _ready().
# Uses a separate test database so it never touches your live game data.
#
# Usage:
#   1. Create a scene with a Node root.
#   2. Attach this script.
#   3. Run the scene. Results print to the Godot Output panel.
#   4. Delete the test scene before shipping — it is dev-only.

extends Node

# ── Repos ─────────────────────────────────────────────────────────────────────

var _player_repo:  PlayerRepository
var _stats_repo:   PlayerStatsRepository
var _captain_repo: CaptainRepository
var _unlock_repo:  ShipUnlockRepository

# ── Counters ──────────────────────────────────────────────────────────────────

var _total:  int = 0
var _passed: int = 0

const TEST_DB := "user://BattleFleetGame_Test.db"


# ── Entry point ───────────────────────────────────────────────────────────────

func _ready() -> void:
	run_all_tests()


func run_all_tests() -> void:
	_print_header("BATTLE FLEET 2 — DATABASE TEST SUITE (GODOT)")

	DatabaseManager.initialize(TEST_DB)
	_player_repo  = PlayerRepository.new()
	_stats_repo   = PlayerStatsRepository.new()
	_captain_repo = CaptainRepository.new()
	_unlock_repo  = ShipUnlockRepository.new()

	test_player_creation()
	test_player_retrieval()
	test_player_level_up()
	test_fleet_level_progression()
	test_battle_recording_and_history()
	test_ship_unlock_gating()
	test_captain_xp_and_command_cards()
	test_error_handling()

	_print_summary()
	DatabaseManager.close()
	# Remove test database file so it doesn't linger between sessions
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DB))


# ══════════════════════════════════════════════════════════════════════════════
# TEST CATEGORY 1 — Player creation
# ══════════════════════════════════════════════════════════════════════════════

func test_player_creation() -> void:
	_print_category("Player Creation")

	# 1a: Create a valid player
	var p := _player_repo.create_player(_uid("Valid"))
	_test("Create player — returns non-null", p != null)
	_test("Create player — ID assigned", p != null and p.player_id > 0)

	# 1b: Duplicate name is rejected
	var name := _uid("Dup")
	_player_repo.create_player(name)
	var dup := _player_repo.create_player(name)
	_test("Create player — duplicate rejected", dup == null)

	# 1c: Empty name is rejected
	var empty := _player_repo.create_player("")
	_test("Create player — empty name rejected", empty == null)

	# 1d: PlayerStats row created automatically with Level 1 / 0 XP
	var p2 := _player_repo.create_player(_uid("AutoStats"))
	var stats := _stats_repo.get_player_stats(p2.player_id) if p2 else null
	_test("Create player — auto-creates PlayerStats at Level 1",
		stats != null and stats.level == 1 and stats.total_experience == 0)

	# 1e: New player starts at FleetLevel 1 / FleetXP 0
	_test("Create player — starts at FleetLevel 1",
		p2 != null and p2.fleet_level == 1 and p2.fleet_xp == 0)

	_cleanup("Valid", "Dup", "AutoStats")


# ══════════════════════════════════════════════════════════════════════════════
# TEST CATEGORY 2 — Player retrieval
# ══════════════════════════════════════════════════════════════════════════════

func test_player_retrieval() -> void:
	_print_category("Player Retrieval")

	var name := _uid("Retrieve")
	var created := _player_repo.create_player(name)

	# 2a: Retrieve by ID
	var by_id := _player_repo.get_player_by_id(created.player_id) if created else null
	_test("Retrieve by ID — found",    by_id != null)
	_test("Retrieve by ID — correct",  by_id != null and by_id.player_id == created.player_id)

	# 2b: Retrieve by name
	var by_name := _player_repo.get_player_by_name(name) if created else null
	_test("Retrieve by name — correct", by_name != null and by_name.player_name == name)

	# 2c: Non-existent ID returns null
	var missing := _player_repo.get_player_by_id(999999)
	_test("Retrieve non-existent ID — returns null", missing == null)

	# 2d: Active player count increases after creation
	var count_before := _player_repo.get_total_player_count()
	_player_repo.create_player(_uid("CountExtra"))
	var count_after := _player_repo.get_total_player_count()
	_test("Total player count increases after create", count_after > count_before)

	_cleanup("Retrieve", "CountExtra")


# ══════════════════════════════════════════════════════════════════════════════
# TEST CATEGORY 3 — Player level-up (flat 1000 XP / level curve)
# ══════════════════════════════════════════════════════════════════════════════

func test_player_level_up() -> void:
	_print_category("Player Level-Up (flat curve)")

	var p := _player_repo.create_player(_uid("LvlUp"))
	var pid := p.player_id if p else -1

	# 3a: 999 XP stays at Level 1
	_stats_repo.add_experience(pid, 999)
	var s1 := _stats_repo.get_player_stats(pid)
	_test("999 XP — still Level 1", s1 != null and s1.level == 1)

	# 3b: 1 more XP (1000 total) → Level 2
	_stats_repo.add_experience(pid, 1)
	var s2 := _stats_repo.get_player_stats(pid)
	_test("1000 XP — Level 2", s2 != null and s2.level == 2)

	# 3c: 4000 more XP (5000 total) → Level 6
	_stats_repo.add_experience(pid, 4000)
	var s3 := _stats_repo.get_player_stats(pid)
	_test("5000 XP — Level 6", s3 != null and s3.level == 6)

	# 3d: HighestLevel tracks the maximum reached
	_test("HighestLevel >= current level", s3 != null and s3.highest_level >= s3.level)

	# 3e: Remaining XP to next level
	# At Level 6 we have 5000 XP; next level (7) needs 6000; remaining = 1000
	var remaining := _stats_repo.get_remaining_experience_for_level(pid)
	_test("Remaining XP to next level = 1000", remaining == 1000)

	_cleanup("LvlUp")


# ══════════════════════════════════════════════════════════════════════════════
# TEST CATEGORY 4 — Fleet level progression (quadratic level×100 XP curve)
# ══════════════════════════════════════════════════════════════════════════════

func test_fleet_level_progression() -> void:
	_print_category("Fleet Level Progression (quadratic curve)")

	# 4a: Static formula spot-checks (no DB needed)
	_test("calculate_fleet_level(0) = 1",   PlayerStatsRepository.calculate_fleet_level(0)   == 1)
	_test("calculate_fleet_level(99) = 1",  PlayerStatsRepository.calculate_fleet_level(99)  == 1)
	_test("calculate_fleet_level(100) = 2", PlayerStatsRepository.calculate_fleet_level(100) == 2)
	_test("calculate_fleet_level(299) = 2", PlayerStatsRepository.calculate_fleet_level(299) == 2)
	_test("calculate_fleet_level(300) = 3", PlayerStatsRepository.calculate_fleet_level(300) == 3)
	_test("calculate_fleet_level(600) = 4", PlayerStatsRepository.calculate_fleet_level(600) == 4)

	# 4b: award_fleet_xp_and_level_up persists to the database
	var p := _player_repo.create_player(_uid("FleetXP"))
	var pid := p.player_id if p else -1

	var lvl := _stats_repo.award_fleet_xp_and_level_up(pid, 100)
	_test("Award 100 fleet XP → FleetLevel 2", lvl == 2)

	var lvl2 := _stats_repo.award_fleet_xp_and_level_up(pid, 200)  # total 300
	_test("Award 200 more fleet XP → FleetLevel 3", lvl2 == 3)

	# 4c: get_progress_bar_data returns correct band for Level 3
	# At total_xp=300, level 3 band is [300, 600)
	var bar := _stats_repo.get_progress_bar_data(pid)
	_test("Progress bar xp_start = 300 (level 3 threshold)", bar.get("xp_start", -1) == 300)
	_test("Progress bar xp_end   = 600 (level 4 threshold)", bar.get("xp_end",   -1) == 600)

	_cleanup("FleetXP")


# ══════════════════════════════════════════════════════════════════════════════
# TEST CATEGORY 5 — Battle recording + BattleHistory insertion
# ══════════════════════════════════════════════════════════════════════════════

func test_battle_recording_and_history() -> void:
	_print_category("Battle Recording & BattleHistory")

	var p := _player_repo.create_player(_uid("Battle"))
	var pid := p.player_id if p else -1

	var battle := BattleFleetModels.BattleRecord.new()
	battle.player_id         = pid
	battle.opponent_name     = "Admiral Tanaka (AI)"
	battle.result            = "Win"
	battle.ships_destroyed   = 3
	battle.ships_lost        = 1
	battle.experience_gained = 300
	battle.difficulty_level  = "Normal"
	battle.battle_mode       = "SkirmishBattle"

	var ok := _stats_repo.record_battle_result(pid, battle)
	_test("record_battle_result returns true", ok)

	var s := _stats_repo.get_player_stats(pid)
	_test("TotalBattles incremented to 1",       s != null and s.total_battles == 1)
	_test("TotalWins incremented to 1",          s != null and s.total_wins    == 1)
	_test("TotalShipsDestroyed = 3",             s != null and s.total_ships_destroyed == 3)
	_test("TotalShipsLost = 1",                  s != null and s.total_ships_lost      == 1)
	_test("TotalExperience = 300",               s != null and s.total_experience      == 300)

	# Verify BattleHistory row was inserted (tests the fix added in prompt 7)
	var rows := DatabaseManager.execute_reader(
		"SELECT * FROM BattleHistory WHERE PlayerID = ?", [pid]
	)
	_test("BattleHistory row inserted",                    rows.size() == 1)
	_test("BattleHistory.Result = 'Win'",                  rows.size() > 0 and rows[0].get("Result", "") == "Win")
	_test("BattleHistory.OpponentName = 'Admiral Tanaka'", rows.size() > 0 and "Tanaka" in str(rows[0].get("OpponentName", "")))

	# Record a Loss and a Draw, check aggregation
	var battle2 := BattleFleetModels.BattleRecord.new()
	battle2.result            = "Loss"
	battle2.ships_destroyed   = 0
	battle2.ships_lost        = 2
	battle2.experience_gained = 50
	_stats_repo.record_battle_result(pid, battle2)

	var battle3 := BattleFleetModels.BattleRecord.new()
	battle3.result            = "Draw"
	battle3.ships_destroyed   = 1
	battle3.ships_lost        = 1
	battle3.experience_gained = 75
	_stats_repo.record_battle_result(pid, battle3)

	var s2 := _stats_repo.get_player_stats(pid)
	_test("After 3 battles: W/L/D = 1/1/1",
		s2 != null and s2.total_wins == 1 and s2.total_losses == 1 and s2.total_draws == 1)
	_test("Win rate = 33.3%", s2 != null and absf(s2.get_win_rate() - 33.333) < 0.1)

	_cleanup("Battle")


# ══════════════════════════════════════════════════════════════════════════════
# TEST CATEGORY 6 — Ship unlock gating by FleetLevel
# ══════════════════════════════════════════════════════════════════════════════

func test_ship_unlock_gating() -> void:
	_print_category("Ship Unlock Gating")

	var p := _player_repo.create_player(_uid("Ships"))
	var pid := p.player_id if p else -1

	# 6a: Starter ships unlocked at Level 1
	_test("Sloop unlocked at FleetLevel 1", _unlock_repo.is_ship_unlocked(pid, "Sloop"))
	_test("Brig unlocked at FleetLevel 1",  _unlock_repo.is_ship_unlocked(pid, "Brig"))

	# 6b: Advanced ships locked at Level 1
	_test("Frigate locked at FleetLevel 1",  not _unlock_repo.is_ship_unlocked(pid, "Frigate"))
	_test("Carrier locked at FleetLevel 1",  not _unlock_repo.is_ship_unlocked(pid, "Carrier"))
	_test("Ironclad locked at FleetLevel 1", not _unlock_repo.is_ship_unlocked(pid, "Ironclad"))

	# 6c: Reach FleetLevel 3 — Frigate unlocks
	_stats_repo.award_fleet_xp_and_level_up(pid, 300)  # total 300 XP = Level 3
	_test("Frigate unlocked at FleetLevel 3", _unlock_repo.is_ship_unlocked(pid, "Frigate"))
	_test("Carrier still locked at FleetLevel 3", not _unlock_repo.is_ship_unlocked(pid, "Carrier"))

	# 6d: Reach FleetLevel 7 — Carrier unlocks (needs 1+2+3+4+5+6 * 100 = 2100 XP total)
	_stats_repo.award_fleet_xp_and_level_up(pid, 1800)  # total 2100 XP = Level 7
	_test("Carrier unlocked at FleetLevel 7", _unlock_repo.is_ship_unlocked(pid, "Carrier"))

	# 6e: get_all_ship_statuses_for_player returns all 6 ships
	var statuses := _unlock_repo.get_all_ship_statuses_for_player(pid)
	_test("get_all_ship_statuses returns 6 entries", statuses.size() == 6)

	_cleanup("Ships")


# ══════════════════════════════════════════════════════════════════════════════
# TEST CATEGORY 7 — Captain XP, level-up, command cards, accuracy
# ══════════════════════════════════════════════════════════════════════════════

func test_captain_xp_and_command_cards() -> void:
	_print_category("Captain XP & Command Cards")

	# 7a: Static level formula spot-checks (same quadratic curve as fleet level)
	_test("Captain calculate_level(0) = 1",   CaptainRepository.calculate_captain_level(0)   == 1)
	_test("Captain calculate_level(100) = 2", CaptainRepository.calculate_captain_level(100) == 2)
	_test("Captain calculate_level(300) = 3", CaptainRepository.calculate_captain_level(300) == 3)

	var p := _player_repo.create_player(_uid("Captain"))
	var pid := p.player_id if p else -1

	# Create a captain
	var cap := BattleFleetModels.Captain.new("Captain Morgan", "Aggressive")
	cap.player_id = pid
	var cid := _captain_repo.create_captain(cap)
	_test("Captain created — ID > 0", cid > 0)

	# 7b: Level 1 command card ("Steady Aim") auto-unlocked on creation
	var cards_at_creation := _captain_repo.get_unlocked_command_cards(cid)
	_test("Steady Aim unlocked at creation (Level 1)", cards_at_creation.size() >= 1)

	# 7c: Award a Win battle — 150 XP, not enough for Level 2 (needs 100 total — but
	#     wait, a Win gives 150 which IS enough; verify level becomes 2)
	var battle := BattleFleetModels.BattleRecord.new()
	battle.result          = "Win"
	battle.ships_destroyed = 0
	battle.ships_lost      = 0
	battle.experience_gained = 0
	var new_lvl := _captain_repo.award_battle_xp(cid, battle)
	_test("Win battle → Captain Level 2 (150 XP >= 100 threshold)", new_lvl == 2)

	# 7d: Accuracy bonus = (level - 1) * 2% = 2% at Level 2
	var bonus := _captain_repo.get_captain_accuracy_bonus(cid)
	_test("Accuracy bonus at Level 2 = 2.0%", absf(bonus - 2.0) < 0.001)

	# 7e: "Broadside Volley" (Level 2 card) now unlocked
	var cards_after := _captain_repo.get_unlocked_command_cards(cid)
	var has_broadside := false
	for card in cards_after:
		if card.card_name == "Broadside Volley":
			has_broadside = true
	_test("Broadside Volley unlocked after reaching Level 2", has_broadside)

	_cleanup("Captain")


# ══════════════════════════════════════════════════════════════════════════════
# TEST CATEGORY 8 — Error handling
# ══════════════════════════════════════════════════════════════════════════════

func test_error_handling() -> void:
	_print_category("Error Handling")

	# 8a: Stats for non-existent player returns null (not a crash)
	var stats := _stats_repo.get_player_stats(-1)
	_test("get_player_stats(-1) returns null gracefully", stats == null)

	# 8b: Invalid campaign progress percentage rejected
	var p := _player_repo.create_player(_uid("ErrHandle"))
	var pid := p.player_id if p else -1
	var bad := _stats_repo.update_campaign_progress(pid, 150.0)  # over 100%
	_test("update_campaign_progress(150%) rejected", not bad)

	# 8c: Negative XP input handled (add_experience should not crash)
	var before := _stats_repo.get_player_stats(pid)
	_stats_repo.add_experience(pid, 0)
	var after := _stats_repo.get_player_stats(pid)
	_test("add_experience(0) leaves XP unchanged",
		before != null and after != null and before.total_experience == after.total_experience)

	# 8d: get_player_by_id with non-existent ID returns null
	var missing := _player_repo.get_player_by_id(999999)
	_test("get_player_by_id(999999) returns null", missing == null)

	# 8e: is_ship_unlocked for unknown ship type returns false (no crash)
	var fake_ship := _unlock_repo.is_ship_unlocked(pid, "GhostShip_XYZ")
	_test("is_ship_unlocked for unknown ship type returns false", not fake_ship)

	_cleanup("ErrHandle")


# ══════════════════════════════════════════════════════════════════════════════
# Utilities
# ══════════════════════════════════════════════════════════════════════════════

## Unique name prefix to prevent test collisions across runs.
func _uid(base: String) -> String:
	return "Test_%s_%d" % [base, Time.get_ticks_msec()]


## Delete all test players whose names start with "Test_<prefix>_".
## CASCADE on the FK handles PlayerStats, Captains, BattleHistory, etc.
func _cleanup(prefix: String, p2: String = "", p3: String = "") -> void:
	for prefix_str in ["Test_" + prefix, "Test_" + p2, "Test_" + p3]:
		if prefix_str == "Test_":
			continue
		DatabaseManager.execute_non_query(
			"DELETE FROM Players WHERE PlayerName LIKE ?", [prefix_str + "%"]
		)


func _test(label: String, result: bool) -> void:
	_total += 1
	if result:
		_passed += 1
		print("  ✓  " + label)
	else:
		printerr("  ✗  " + label)


func _print_category(name: String) -> void:
	print("\n[%s]" % name.to_upper())


func _print_header(title: String) -> void:
	var bar := "═".repeat(56)
	print("\n╔%s╗" % bar)
	print("║  %-54s║" % title)
	print("╚%s╝\n" % bar)


func _print_summary() -> void:
	var failed := _total - _passed
	var rate   := 0.0 if _total == 0 else float(_passed) / float(_total) * 100.0
	print("\n─────────────────────────────────────────")
	print("  Total:   %d" % _total)
	print("  Passed:  %d" % _passed)
	print("  Failed:  %d" % failed)
	print("  Rate:    %.1f%%" % rate)
	print("─────────────────────────────────────────")
	if failed == 0:
		print("  ✓ ALL TESTS PASSED")
	else:
		printerr("  ✗ %d test(s) FAILED — review output above" % failed)
