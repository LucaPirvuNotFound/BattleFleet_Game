# DatabaseUsageExample.gd
# Practical integration examples for the Battle Fleet 2 Godot database system.
# Attach to any Node and call run_all_examples() from _ready() to test.
# Remove this script from production builds — it is for developer reference only.

extends Node

var _player_repo: PlayerRepository
var _stats_repo: PlayerStatsRepository
var _captain_repo: CaptainRepository
var _unlock_repo: ShipUnlockRepository


func _ready() -> void:
	# DatabaseManager must be initialized before any repository call.
	# In production, do this in your main GameManager scene's _ready().
	DatabaseManager.initialize()

	_player_repo  = PlayerRepository.new()
	_stats_repo   = PlayerStatsRepository.new()
	_captain_repo = CaptainRepository.new()
	_unlock_repo  = ShipUnlockRepository.new()

	# Connect signals for level-up events
	_stats_repo.player_leveled_up.connect(_on_player_leveled_up)
	_stats_repo.fleet_leveled_up.connect(_on_fleet_leveled_up)
	_captain_repo.captain_leveled_up.connect(_on_captain_leveled_up)

	run_all_examples()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		DatabaseManager.close()


# ── Example 1: Create a player ────────────────────────────────────────────────

func example_create_player() -> void:
	print("\n=== Example 1: Create Player ===")

	# Prevent duplicate names — safe to call multiple times
	if _player_repo.player_exists("CommanderAlex"):
		print("Player 'CommanderAlex' already exists — skipping creation.")
	else:
		var player: BattleFleetModels.Player = _player_repo.create_player("CommanderAlex")
		if player:
			print("Created: ", player)


# ── Example 2: Retrieve players ───────────────────────────────────────────────

func example_retrieve_players() -> void:
	print("\n=== Example 2: Retrieve Players ===")

	var player: BattleFleetModels.Player = _player_repo.get_player_by_name("CommanderAlex")
	if player:
		print("Found by name: ", player)

	var all_players: Array = _player_repo.get_all_active_players()
	print("Total active players: %d" % all_players.size())
	for p in all_players:
		print("  - ", p)


# ── Example 3: Update player ──────────────────────────────────────────────────

func example_update_player() -> void:
	print("\n=== Example 3: Update Player ===")

	var player: BattleFleetModels.Player = _player_repo.get_player_by_name("CommanderAlex")
	if player:
		_player_repo.update_last_played_date(player.player_id)
		print("Updated last_played_date for player %d." % player.player_id)


# ── Example 4: Player stats & levelling ───────────────────────────────────────

func example_stats_and_levelling() -> void:
	print("\n=== Example 4: Stats & Levelling ===")

	var player: BattleFleetModels.Player = _player_repo.get_player_by_name("CommanderAlex")
	if player == null:
		return

	var pid := player.player_id
	var stats: BattleFleetModels.PlayerStats = _stats_repo.get_player_stats(pid)
	print("Before: ", stats)

	# Award fleet XP (quadratic curve — gates ship unlocks)
	var new_fleet_level: int = _stats_repo.award_fleet_xp_and_level_up(pid, 250)
	print("Fleet level after +250 XP: %d" % new_fleet_level)

	# Add overall player XP (flat 1000 XP/level)
	_stats_repo.add_experience(pid, 1500)

	stats = _stats_repo.get_player_stats(pid)
	print("After:  ", stats)

	# Progress bar data for fleet level UI
	var bar_data: Dictionary = _stats_repo.get_progress_bar_data(pid)
	print("Fleet XP bar — current: %d, level start: %d, level end: %d" % [
		bar_data["total_xp"], bar_data["xp_start"], bar_data["xp_end"]
	])


# ── Example 5: Leaderboard ────────────────────────────────────────────────────

func example_leaderboard() -> void:
	print("\n=== Example 5: Leaderboard ===")

	var top_by_level: Array = _stats_repo.get_top_players_by_level(5)
	print("Top 5 by level:")
	for stats in top_by_level:
		var p: BattleFleetModels.Player = _player_repo.get_player_by_id(stats.player_id)
		var name_str := p.player_name if p else "Unknown"
		print("  %s — Level %d (XP: %d)" % [name_str, stats.level, stats.total_experience])

	var top_by_wr: Array = _stats_repo.get_top_players_by_win_rate(5)
	print("Top 5 by win rate:")
	for stats in top_by_wr:
		var p: BattleFleetModels.Player = _player_repo.get_player_by_id(stats.player_id)
		var name_str := p.player_name if p else "Unknown"
		print("  %s — %.1f%% win rate (%d battles)" % [name_str, stats.get_win_rate(), stats.total_battles])


# ── Example 6: Battle simulation ─────────────────────────────────────────────

func example_battle_simulation() -> void:
	print("\n=== Example 6: Battle Simulation ===")

	var player: BattleFleetModels.Player = _player_repo.get_player_by_name("CommanderAlex")
	if player == null:
		return

	# Simulate a won battle
	var battle := BattleFleetModels.BattleRecord.new()
	battle.player_id         = player.player_id
	battle.opponent_name     = "Admiral Tanaka (AI)"
	battle.result            = "Win"
	battle.ships_destroyed   = 3
	battle.ships_lost        = 1
	battle.experience_gained = 300
	battle.difficulty_level  = "Normal"
	battle.battle_mode       = "SkirmishBattle"

	# Update player stats
	_stats_repo.record_battle_result(player.player_id, battle)

	# Award fleet XP for the win
	_stats_repo.award_fleet_xp_and_level_up(player.player_id, 150)

	# Award captain XP
	var captains: Array = _captain_repo.get_captains_by_player(player.player_id)
	if captains.is_empty():
		# Create a captain if none exist
		var new_captain := BattleFleetModels.Captain.new("Captain Morgan", "Aggressive")
		new_captain.player_id = player.player_id
		var cid := _captain_repo.create_captain(new_captain)
		print("Created captain ID: %d" % cid)
		captains = _captain_repo.get_captains_by_player(player.player_id)

	if not captains.is_empty():
		var captain: BattleFleetModels.Captain = captains[0]
		var new_level: int = _captain_repo.award_battle_xp(captain.captain_id, battle)
		print("Captain '%s' new level: %d" % [captain.captain_name, new_level])

		var unlocked_cards: Array = _captain_repo.get_unlocked_command_cards(captain.captain_id)
		print("Unlocked command cards (%d):" % unlocked_cards.size())
		for card in unlocked_cards:
			print("  ", card)

	# Check ship unlock status
	print("Ship unlock status after battle:")
	var ship_statuses: Array = _unlock_repo.get_all_ship_statuses_for_player(player.player_id)
	for s in ship_statuses:
		print("  [%s] %s" % ["✓" if s.is_unlocked else "✗", s.display_name + "  " + s.get_unlock_label()])


# ── Run all ───────────────────────────────────────────────────────────────────

func run_all_examples() -> void:
	example_create_player()
	example_retrieve_players()
	example_update_player()
	example_stats_and_levelling()
	example_leaderboard()
	example_battle_simulation()
	print("\n=== All examples completed ===")


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_player_leveled_up(player_id: int, old_level: int, new_level: int) -> void:
	print("[SIGNAL] Player %d leveled up: %d → %d" % [player_id, old_level, new_level])
	# TODO: trigger level-up animation / UI notification here

func _on_fleet_leveled_up(player_id: int, old_level: int, new_level: int) -> void:
	print("[SIGNAL] Player %d fleet leveled up: %d → %d — check for new ship unlocks!" % [
		player_id, old_level, new_level])
	# TODO: show ship-unlock popup, refresh ProgressionBarUI

func _on_captain_leveled_up(captain_id: int, old_level: int, new_level: int, accuracy_bonus: float) -> void:
	print("[SIGNAL] Captain %d leveled up: %d → %d | Accuracy bonus: +%.1f%%" % [
		captain_id, old_level, new_level, accuracy_bonus])
	# TODO: show captain level-up animation, display newly unlocked command card
