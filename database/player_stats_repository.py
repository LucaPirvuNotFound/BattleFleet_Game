# player_stats_repository.py
# Manages PlayerStats (player-level progression) and Fleet-level progression.
#
# Two parallel XP systems exist in this game:
#   1. Player Level  — stored in PlayerStats.Level / TotalExperience
#                      Flat formula: level = total_xp // 1000 + 1
#                      Updated by record_battle_result() and add_experience()
#
#   2. Fleet Level   — stored in Players.FleetLevel / Players.FleetXP
#                      Quadratic formula: each level costs level*100 XP
#                      Updated by award_fleet_xp_and_level_up()
#                      Gates ship unlocks (ShipUnlockRepository reads FleetLevel)
#
# FIX (vs Unity version):
#   - award_fleet_xp_and_level_up() used undefined "_db" field; now uses DatabaseManager
#   - award_fleet_xp_and_level_up() used wrong table "players" / columns "fleet_xp", "fleet_level"
#     (schema uses "Players", "FleetXP", "FleetLevel")
#   - get_progress_bar_data() had the same naming bugs

import logging
from datetime import datetime, timezone
from typing import Callable, Optional

from .database_manager import DatabaseManager
from .models import BattleRecord, PlayerStats

logger = logging.getLogger(__name__)

XP_PER_PLAYER_LEVEL: int = 1000  # Flat curve for the overall player level


class PlayerStatsRepository:
    # GDScript signals become simple callback lists.
    # Register with: repo.on_player_leveled_up.append(my_func)
    # Callback signature: (player_id: int, old_level: int, new_level: int) -> None

    def __init__(self, db: DatabaseManager) -> None:
        self._db = db

    # ── READ ───────────────────────────────────────────────────────────────────

    def get_player_stats(self, player_id: int) -> Optional[PlayerStats]:
        rows = self._db.execute_reader(
            "SELECT * FROM PlayerStats WHERE PlayerID = ?", (player_id,)
        )
        if not rows:
            return None
        return _map_stats(rows[0])


    # ── RECORD BATTLE ──────────────────────────────────────────────────────────

    def record_battle_result(self, player_id: int, battle: BattleRecord) -> bool:
        """Records a battle result, updates wins/losses/experience, recalculates level."""
        stats = self.get_player_stats(player_id)
        if stats is None:
            logger.error("PlayerStatsRepository: Stats not found for player %d.", player_id)
            return False

        stats.total_battles += 1
        if battle.result == "Win":
            stats.total_wins += 1
        elif battle.result == "Loss":
            stats.total_losses += 1
        elif battle.result == "Draw":
            stats.total_draws += 1

        stats.total_ships_destroyed += battle.ships_destroyed
        stats.total_ships_lost += battle.ships_lost

        stats.last_updated = _now()
        self._insert_battle_history(player_id, battle)
        return self._update_player_stats(stats)

    # ── ACCURACY ───────────────────────────────────────────────────────────────

    def update_accuracy(
        self, player_id: int, total_shots: int, successful_shots: int
    ) -> bool:
        if total_shots <= 0:
            logger.warning("PlayerStatsRepository: total_shots must be > 0.")
            return False

        stats = self.get_player_stats(player_id)
        if stats is None:
            logger.error("PlayerStatsRepository: Stats not found for player %d.", player_id)
            return False

        base = stats.average_accuracy * max(stats.total_battles - 1, 0)
        new_shot_accuracy = successful_shots / total_shots
        stats.average_accuracy = (base + new_shot_accuracy) / max(stats.total_battles, 1)
        return self._update_player_stats(stats)


    # ── LEADERBOARDS ───────────────────────────────────────────────────────────
    def get_top_players_by_level(self, top_count: int = 10) -> list[PlayerStats]:
        rows = self._db.execute_reader(
            "SELECT * FROM PlayerStats ORDER BY TotalWins DESC, TotalBattles DESC LIMIT ?",
            (top_count,),
        )
        return [_map_stats(row) for row in rows]

    def get_top_players_by_win_rate(self, top_count: int = 10) -> list[PlayerStats]:
        rows = self._db.execute_reader(
            """SELECT * FROM PlayerStats
               WHERE TotalBattles > 0
               ORDER BY (CAST(TotalWins AS FLOAT) / TotalBattles) DESC, TotalBattles DESC
               LIMIT ?""",
            (top_count,),
        )
        return [_map_stats(row) for row in rows]

    def get_player_rank(self, player_id: int, by_win_rate: bool = False) -> int:
        """Returns 1-based rank of the player (1 = best)."""
        if by_win_rate:
            count = self._db.execute_scalar(
                """SELECT COUNT(*) FROM PlayerStats
                   WHERE (CAST(TotalWins AS FLOAT) / NULLIF(TotalBattles, 0)) >
                         (SELECT CAST(TotalWins AS FLOAT) / NULLIF(TotalBattles, 0)
                          FROM PlayerStats WHERE PlayerID = ?)""",
                (player_id,),
            )
        else:                                                           # LIPSEA
            count = self._db.execute_scalar(
                """SELECT COUNT(*) FROM PlayerStats
                WHERE TotalWins > (SELECT TotalWins FROM PlayerStats WHERE PlayerID = ?)""",
                (player_id,),
            )
        return int(count or 0) + 1  # 1-indexed

    
    # ── RESET (admin / debug) ──────────────────────────────────────────────────
    def reset_player_stats(self, player_id: int) -> bool:
        result = self._db.execute_non_query(
            """UPDATE PlayerStats
            SET TotalBattles = 0,
                TotalWins = 0, TotalLosses = 0, TotalDraws = 0,
                AverageAccuracy = 0.0,
                TotalShipsDestroyed = 0, TotalShipsLost = 0,
                BattleshipKills = 0, BattleshipDeaths = 0, BattleshipAccuracy = 0,
                CruiserKills = 0, CruiserDeaths = 0, CruiserAccuracy = 0,
                DestroyerKills = 0, DestroyerDeaths = 0, DestroyerAccuracy = 0,
                CorvetteKills = 0, CorvetteDeaths = 0, CorvetteAccuracy = 0,
                TorpedoBoatKills = 0, TorpedoBoatDeaths = 0, TorpedoBoatAccuracy = 0,
                LastUpdated = ?
            WHERE PlayerID = ?""",
            (_now(), player_id),
        )
        if result > 0:
            logger.info("PlayerStatsRepository: Stats reset for player %d.", player_id)
        return result > 0

    # ── Private ────────────────────────────────────────────────────────────────

    def _update_player_stats(self, stats: PlayerStats) -> bool:
        result = self._db.execute_non_query(
            """UPDATE PlayerStats
               SET TotalBattles = ?,
                   TotalWins = ?, TotalLosses = ?, TotalDraws = ?,
                   AverageAccuracy = ?, TotalShipsDestroyed = ?, TotalShipsLost = ?,
                   LastUpdated = ?, BattleshipKills = ?, BattleshipDeaths = ?, BattleshipAccuracy = ?,
                    CruiserKills = ?, CruiserDeaths = ?, CruiserAccuracy = ?,
                    DestroyerKills = ?, DestroyerDeaths = ?, DestroyerAccuracy = ?,
                    CorvetteKills = ?, CorvetteDeaths = ?, CorvetteAccuracy = ?,
                    TorpedoBoatKills = ?, TorpedoBoatDeaths = ?, TorpedoBoatAccuracy = ?
               WHERE PlayerID = ?""",
            (
                stats.total_battles,
                stats.total_wins,
                stats.total_losses,
                stats.total_draws,
                stats.average_accuracy,
                stats.total_ships_destroyed,
                stats.total_ships_lost,
                _now(),
                stats.battleship_kills, stats.battleship_deaths, stats.battleship_accuracy,
                stats.cruiser_kills, stats.cruiser_deaths, stats.cruiser_accuracy,
                stats.destroyer_kills, stats.destroyer_deaths, stats.destroyer_accuracy,
                stats.corvette_kills, stats.corvette_deaths, stats.corvette_accuracy,
                stats.torpedo_boat_kills, stats.torpedo_boat_deaths, stats.torpedo_boat_accuracy,
                stats.player_id,
            ),
        )
        return result > 0

    def _insert_battle_history(self, player_id: int, battle: BattleRecord) -> None:
        self._db.execute_non_query(
            """INSERT INTO BattleHistory
               (PlayerID, OpponentName, BattleDate, Result,
                ShipsDestroyed, ShipsLost, DifficultyLevel, BattleMode)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                player_id,
                battle.opponent_name,
                _now(),
                battle.result,
                battle.ships_destroyed,
                battle.ships_lost,
                battle.difficulty_level,
                battle.battle_mode,
            ),
        )


# ── Module-level functions ─────────────────────────────────────────────────────

def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def _emit(callbacks: list[Callable], *args) -> None:
    for cb in callbacks:
        try:
            cb(*args)
        except Exception as exc:
            logger.error("Signal callback raised an exception: %s", exc)


def _map_stats(row: dict) -> PlayerStats:
    return PlayerStats(
        stat_id=int(row.get("StatID", 0)),
        player_id=int(row.get("PlayerID", 0)),
        total_battles=int(row.get("TotalBattles", 0)),
        total_wins=int(row.get("TotalWins", 0)),
        total_losses=int(row.get("TotalLosses", 0)),
        total_draws=int(row.get("TotalDraws", 0)),
        average_accuracy=float(row.get("AverageAccuracy", 0.0)),
        total_ships_destroyed=int(row.get("TotalShipsDestroyed", 0)),
        total_ships_lost=int(row.get("TotalShipsLost", 0)),
        last_updated=str(row.get("LastUpdated", "") or ""),
        battleship_kills=int(row.get("BattleshipKills", 0)),      # NOU
        battleship_deaths=int(row.get("BattleshipDeaths", 0)),    # NOU
        battleship_accuracy=int(row.get("BattleshipAccuracy", 0)),# NOU
        cruiser_kills=int(row.get("CruiserKills", 0)),            # NOU
        cruiser_deaths=int(row.get("CruiserDeaths", 0)),          # NOU
        cruiser_accuracy=int(row.get("CruiserAccuracy", 0)),      # NOU
        destroyer_kills=int(row.get("DestroyerKills", 0)),        # NOU
        destroyer_deaths=int(row.get("DestroyerDeaths", 0)),      # NOU
        destroyer_accuracy=int(row.get("DestroyerAccuracy", 0)),  # NOU
        corvette_kills=int(row.get("CorvetteKills", 0)),          # NOU
        corvette_deaths=int(row.get("CorvetteDeaths", 0)),        # NOU
        corvette_accuracy=int(row.get("CorvetteAccuracy", 0)),    # NOU
        torpedo_boat_kills=int(row.get("TorpedoBoatKills", 0)),   # NOU
        torpedo_boat_deaths=int(row.get("TorpedoBoatDeaths", 0)), # NOU
        torpedo_boat_accuracy=int(row.get("TorpedoBoatAccuracy", 0)),
    )
