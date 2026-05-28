# test_database.py
# Standalone test runner for the Battle Fleet 2 database layer (Python version).
#
# Usage:
#   python test_database.py
#
# Uses a separate in-memory (or file-based) test database so it never
# touches live game data.  The database is destroyed after every run.
#
# Tests are organised into the same categories as the original DatabaseTests.gd,
# with the following flow changes explained at the bottom of this file.

import os
import time
import math
from models import BattleRecord, Player, PlayerStats
from database_manager import DatabaseManager
from player_repository import PlayerRepository
from player_stats_repository import PlayerStatsRepository, calculate_fleet_level

TEST_DB = "BattleFleetGame_Test.db"


# ══════════════════════════════════════════════════════════════════════════════
# Test runner state
# ══════════════════════════════════════════════════════════════════════════════

_total:  int = 0
_passed: int = 0
_db:     DatabaseManager
_player_repo:  PlayerRepository
_stats_repo:   PlayerStatsRepository


def run_all_tests() -> None:
    global _db, _player_repo, _stats_repo

    _print_header("BATTLE FLEET 2 — DATABASE TEST SUITE (PYTHON)")

    _db = DatabaseManager(TEST_DB)
    _db.initialize()
    _player_repo = PlayerRepository(_db)
    _stats_repo  = PlayerStatsRepository(_db)

    test_player_creation()
    test_player_retrieval()
    test_battle_recording_and_history()
    test_fleet_level_progression()
    test_error_handling()

    _print_summary()
    _db.close()

    # Remove test database file so it doesn't linger between runs
    if os.path.exists(TEST_DB):
        os.remove(TEST_DB)


# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 1 — Player creation
# ══════════════════════════════════════════════════════════════════════════════

def test_player_creation() -> None:
    _print_category("Player Creation")

    # 1a: Create a valid player
    p = _player_repo.create_player(_uid("Valid"))
    _test("Create player — returns non-null",  p is not None)
    _test("Create player — ID assigned",       p is not None and p.player_id > 0)

    # 1b: Duplicate name is rejected
    name = _uid("Dup")
    _player_repo.create_player(name)
    dup = _player_repo.create_player(name)
    _test("Create player — duplicate rejected", dup is None)

    # 1c: Empty name is rejected
    empty = _player_repo.create_player("")
    _test("Create player — empty name rejected", empty is None)

    # 1d: PlayerStats row created automatically
    # NOTE: Python models have no Level / TotalExperience (schema-aligned),
    #       so we just verify the stats row exists and battles start at 0.
    p2    = _player_repo.create_player(_uid("AutoStats"))
    stats = _stats_repo.get_player_stats(p2.player_id) if p2 else None
    _test("Create player — auto-creates PlayerStats",
          stats is not None and stats.total_battles == 0)

    # 1e: New player has ELO 0 (stored on Players row, read back via get_player_by_id)
    p2_fresh = _player_repo.get_player_by_id(p2.player_id) if p2 else None
    _test("Create player — starts at ELO 0",
          p2_fresh is not None and p2_fresh.elo == 0)

    _cleanup("Valid", "Dup", "AutoStats")


# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 2 — Player retrieval
# ══════════════════════════════════════════════════════════════════════════════

def test_player_retrieval() -> None:
    _print_category("Player Retrieval")

    name    = _uid("Retrieve")
    created = _player_repo.create_player(name)

    # 2a: Retrieve by ID
    by_id = _player_repo.get_player_by_id(created.player_id) if created else None
    _test("Retrieve by ID — found",   by_id is not None)
    _test("Retrieve by ID — correct", by_id is not None and by_id.player_id == created.player_id)

    # 2b: Retrieve by name
    by_name = _player_repo.get_player_by_name(name) if created else None
    _test("Retrieve by name — correct",
          by_name is not None and by_name.player_name == name)

    # 2c: Non-existent ID returns None
    missing = _player_repo.get_player_by_id(999_999)
    _test("Retrieve non-existent ID — returns None", missing is None)

    # 2d: Active player count increases after creation
    count_before = _player_repo.get_total_player_count()
    _player_repo.create_player(_uid("CountExtra"))
    count_after = _player_repo.get_total_player_count()
    _test("Total player count increases after create", count_after > count_before)

    _cleanup("Retrieve", "CountExtra")


# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 3 — Battle recording + BattleHistory insertion
# ══════════════════════════════════════════════════════════════════════════════

def test_battle_recording_and_history() -> None:
    _print_category("Battle Recording & BattleHistory")

    p   = _player_repo.create_player(_uid("Battle"))
    pid = p.player_id if p else -1

    # 3a: Record a Win
    battle = BattleRecord(
        opponent_name    = "Admiral Tanaka (AI)",
        result           = 1,          # 1 = player wins (matches GDScript model)
        ships_destroyed  = 3,
        ships_lost       = 1,
        difficulty_level = "Normal",
        battle_mode      = "SkirmishBattle",
    )
    ok = _stats_repo.record_battle_result(pid, battle)
    _test("record_battle_result returns True", ok)

    s = _stats_repo.get_player_stats(pid)
    _test("TotalBattles incremented to 1",  s is not None and s.total_battles        == 1)
    _test("TotalWins incremented to 1",     s is not None and s.total_wins           == 1)
    _test("TotalShipsDestroyed = 3",        s is not None and s.total_ships_destroyed == 3)
    _test("TotalShipsLost = 1",             s is not None and s.total_ships_lost      == 1)

    # 3b: Verify BattleHistory row was inserted
    rows = _db.execute_reader(
        "SELECT * FROM BattleHistory WHERE PlayerID = ?", (pid,)
    )
    _test("BattleHistory row inserted",                    len(rows) == 1)
    _test("BattleHistory.Result = 1 (player wins)",        len(rows) > 0 and rows[0].get("Result") == 1)
    _test("BattleHistory.OpponentName contains 'Tanaka'",
          len(rows) > 0 and "Tanaka" in str(rows[0].get("OpponentName", "")))

    # 3c: Record a Loss and a Draw — verify aggregation
    battle2 = BattleRecord(
        opponent_name   = "CPU",
        result          = 2,           # 2 = opponent wins
        ships_destroyed = 0,
        ships_lost      = 2,
    )
    _stats_repo.record_battle_result(pid, battle2)

    battle3 = BattleRecord(
        opponent_name   = "CPU",
        result          = 0,           # 0 = draw
        ships_destroyed = 1,
        ships_lost      = 1,
    )
    _stats_repo.record_battle_result(pid, battle3)

    s2 = _stats_repo.get_player_stats(pid)
    _test("After 3 battles — TotalBattles = 3",
          s2 is not None and s2.total_battles == 3)
    _test("After 3 battles — W/L/D = 1/1/1",
          s2 is not None
          and s2.total_wins   == 1
          and s2.total_losses == 1
          and s2.total_draws  == 1)
    # Win-rate: 1 win out of 3 battles = 33.3%
    win_rate = (s2.total_wins / s2.total_battles * 100.0) if s2 and s2.total_battles > 0 else 0.0
    _test("Win rate ≈ 33.3%", math.isclose(win_rate, 33.333, abs_tol=0.1))

    _cleanup("Battle")


# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 4 — Fleet level progression (quadratic level×100 XP curve)
# ══════════════════════════════════════════════════════════════════════════════

def test_fleet_level_progression() -> None:
    _print_category("Fleet Level Progression (quadratic curve)")

    # 4a: Static formula spot-checks — no DB needed
    _test("calculate_fleet_level(0)   = 1", calculate_fleet_level(0)   == 1)
    _test("calculate_fleet_level(99)  = 1", calculate_fleet_level(99)  == 1)
    _test("calculate_fleet_level(100) = 2", calculate_fleet_level(100) == 2)
    _test("calculate_fleet_level(299) = 2", calculate_fleet_level(299) == 2)
    _test("calculate_fleet_level(300) = 3", calculate_fleet_level(300) == 3)
    _test("calculate_fleet_level(600) = 4", calculate_fleet_level(600) == 4)

    # 4b: award_fleet_xp_and_level_up persists to the database
    p   = _player_repo.create_player(_uid("FleetXP"))
    pid = p.player_id if p else -1

    lvl = _stats_repo.award_fleet_xp_and_level_up(pid, 100)
    _test("Award 100 fleet XP → FleetLevel 2", lvl == 2)

    lvl2 = _stats_repo.award_fleet_xp_and_level_up(pid, 200)  # total 300
    _test("Award 200 more fleet XP → FleetLevel 3", lvl2 == 3)

    # 4c: get_progress_bar_data returns correct band for Level 3
    # At total_xp=300, Level 3 band is [300, 600)
    bar = _stats_repo.get_progress_bar_data(pid)
    _test("Progress bar xp_start = 300 (Level 3 threshold)", bar.get("xp_start") == 300)
    _test("Progress bar xp_end   = 600 (Level 4 threshold)", bar.get("xp_end")   == 600)

    _cleanup("FleetXP")


# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 5 — Error handling
# ══════════════════════════════════════════════════════════════════════════════

def test_error_handling() -> None:
    _print_category("Error Handling")

    # 5a: Stats for non-existent player returns None (not a crash)
    stats = _stats_repo.get_player_stats(-1)
    _test("get_player_stats(-1) returns None gracefully", stats is None)

    # 5b: get_player_by_id with non-existent ID returns None
    missing = _player_repo.get_player_by_id(999_999)
    _test("get_player_by_id(999999) returns None", missing is None)

    # 5c: add_experience(0) leaves stats unchanged
    p      = _player_repo.create_player(_uid("ErrHandle"))
    pid    = p.player_id if p else -1
    before = _stats_repo.get_player_stats(pid)
    _stats_repo.add_experience(pid, 0)
    after  = _stats_repo.get_player_stats(pid)
    _test("add_experience(0) leaves stats unchanged",
          before is not None and after is not None
          and before.total_battles == after.total_battles)

    # 5d: Empty player name rejected
    bad_player = _player_repo.create_player("   ")
    _test("create_player with whitespace-only name rejected", bad_player is None)

    # 5e: award_fleet_xp for non-existent player returns -1
    bad_fleet = _stats_repo.award_fleet_xp_and_level_up(-99, 100)
    _test("award_fleet_xp for non-existent player returns -1", bad_fleet == -1)

    _cleanup("ErrHandle")


# ══════════════════════════════════════════════════════════════════════════════
# Utilities
# ══════════════════════════════════════════════════════════════════════════════

def _uid(base: str) -> str:
    """Unique name prefix to prevent test collisions across runs."""
    return f"Test_{base}_{int(time.time() * 1000)}"


def _cleanup(*prefixes: str) -> None:
    """Delete all test players whose names start with 'Test_<prefix>_'.
    CASCADE on the FK handles PlayerStats, BattleHistory, etc."""
    for prefix in prefixes:
        if prefix:
            _db.execute_non_query(
                "DELETE FROM Players WHERE PlayerName LIKE ?",
                (f"Test_{prefix}%",),
            )


def _test(label: str, result: bool) -> None:
    global _total, _passed
    _total += 1
    if result:
        _passed += 1
        print(f"  ✓  {label}")
    else:
        print(f"  ✗  {label}")


def _print_category(name: str) -> None:
    print(f"\n[{name.upper()}]")


def _print_header(title: str) -> None:
    bar = "═" * 56
    print(f"\n╔{bar}╗")
    print(f"║  {title:<54}║")
    print(f"╚{bar}╝\n")


def _print_summary() -> None:
    failed = _total - _passed
    rate   = 0.0 if _total == 0 else _passed / _total * 100.0
    print("\n─────────────────────────────────────────")
    print(f"  Total:   {_total}")
    print(f"  Passed:  {_passed}")
    print(f"  Failed:  {failed}")
    print(f"  Rate:    {rate:.1f}%")
    print("─────────────────────────────────────────")
    if failed == 0:
        print("  ✓ ALL TESTS PASSED")
    else:
        print(f"  ✗ {failed} test(s) FAILED — review output above")


# ══════════════════════════════════════════════════════════════════════════════
# Entry point
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    run_all_tests()


# ══════════════════════════════════════════════════════════════════════════════
# FLOW CHANGES vs DatabaseTests.gd — explained
# ══════════════════════════════════════════════════════════════════════════════
#
# 1. CaptainRepository / ShipUnlockRepository tests REMOVED (categories 6 & 7).
#    These repositories haven't been converted to Python yet.  Once they are,
#    re-add the corresponding test functions here.
#
# 2. Player model has no FleetLevel / FleetXP fields (schema-aligned).
#    Test 1e checks ELO = 0 instead of FleetLevel = 1, because ELO is the
#    only extra column that exists on the Python Player dataclass.
#
# 3. Player model has no Level / TotalExperience (removed in the schema-aligned
#    rewrite).  Tests 3a/3d from the GDScript (999 XP → Level 1, etc.) are
#    replaced by battle-count and win/loss/draw aggregation checks, which are
#    what the current schema actually stores.
#
# 4. BattleRecord.result is int (1 = player wins, 2 = opponent wins, 0 = draw),
#    not a string ("Win"/"Loss"/"Draw") — matching the GDScript model exactly.
#    The record_battle_result() comparisons in player_stats_repository.py must
#    use integer values accordingly (update that method if needed).
#
# 5. _cleanup() now passes prefixes as *args instead of up to 3 positional
#    params — cleaner and handles any number of prefixes.
#
# 6. printerr() replaced with plain print() — Python has no separate error
#    stream distinction needed here; failures are clearly marked with ✗.
