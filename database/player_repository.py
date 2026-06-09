# player_repository.py
# CRUD operations for the Players table.
# FIX (vs Unity version): get_player_by_id / get_player_by_name now read FleetLevel and FleetXP.

import logging
from datetime import datetime, timezone
from typing import Optional

from .database_manager import DatabaseManager
from .models import Player

logger = logging.getLogger(__name__)


class PlayerRepository:

    def __init__(self, db: DatabaseManager) -> None:
        # Dependency-injected instead of using an autoload singleton,
        # which is the standard Python pattern for testability.
        self._db = db

    # ── CREATE ─────────────────────────────────────────────────────────────────

    def create_player(self, player_name: str, email: str = "", password_hash: str = "") -> Optional[Player]:
        """Insert a new player and create an associated PlayerStats row.
        Returns the new Player object, or None on failure."""
        if not player_name.strip():
            logger.error("PlayerRepository: Player name cannot be empty.")
            return None

        if self.player_exists(player_name):
            logger.warning("PlayerRepository: Player '%s' already exists.", player_name)
            return None

        now = _now()
        rows_affected = self._db.execute_non_query(
            "INSERT INTO Players (PlayerName, Email, PasswordHash, CreatedDate, IsActive, ELO) "
            "VALUES (?, ?, ?, ?, 1, 0)",
            (player_name, email, password_hash, now),
        )

        if rows_affected <= 0:
            logger.error("PlayerRepository: Failed to insert player '%s'.", player_name)
            return None

        player_id = self._db.get_last_insert_id()
        self._create_player_stats(player_id, now)

        logger.info("PlayerRepository: Created player '%s' (ID: %d).", player_name, player_id)
        return self.get_player_by_id(player_id)

    # ── READ ───────────────────────────────────────────────────────────────────

    def get_player_by_id(self, player_id: int) -> Optional[Player]:
        """Returns a Player by primary key, or None if not found."""
        rows = self._db.execute_reader(
            "SELECT * FROM Players WHERE PlayerID = ?", (player_id,)
        )
        if not rows:
            return None
        return _map_player(rows[0])

    def get_player_by_name(self, player_name: str) -> Optional[Player]:
        """Returns a Player by name, or None if not found."""
        rows = self._db.execute_reader(
            "SELECT * FROM Players WHERE PlayerName = ?", (player_name,)
        )
        if not rows:
            return None
        return _map_player(rows[0])

    def get_all_active_players(self) -> list[Player]:
        """Returns all players with IsActive = 1, sorted by name."""
        rows = self._db.execute_reader(
            "SELECT * FROM Players WHERE IsActive = 1 ORDER BY PlayerName ASC"
        )
        return [_map_player(row) for row in rows]

    # ── UPDATE ─────────────────────────────────────────────────────────────────

    def update_player(self, player: Player) -> bool:
        """Updates PlayerName, LastPlayedDate and IsActive. Returns True on success."""
        if player is None or player.player_id <= 0:
            logger.error("PlayerRepository: Invalid player object.")
            return False

        result = self._db.execute_non_query(
            "UPDATE Players SET PlayerName = ?, LastPlayedDate = ?, IsActive = ? "
            "WHERE PlayerID = ?",
            (
                player.player_name,
                player.last_played_date,
                1 if player.is_active else 0,
                player.player_id,
            ),
        )
        return result > 0

    def update_last_played_date(self, player_id: int) -> bool:
        """Stamps LastPlayedDate with the current UTC time."""
        result = self._db.execute_non_query(
            "UPDATE Players SET LastPlayedDate = ? WHERE PlayerID = ?",
            (_now(), player_id),
        )
        return result > 0

    # ── DELETE ─────────────────────────────────────────────────────────────────

    def delete_player(self, player_id: int, hard_delete: bool = False) -> bool:
        """Soft delete (default) sets IsActive = 0. Hard delete removes the row."""
        if hard_delete:
            result = self._db.execute_non_query(
                "DELETE FROM Players WHERE PlayerID = ?", (player_id,)
            )
            if result > 0:
                logger.info("PlayerRepository: Player %d permanently deleted.", player_id)
        else:
            result = self._db.execute_non_query(
                "UPDATE Players SET IsActive = 0 WHERE PlayerID = ?", (player_id,)
            )
            if result > 0:
                logger.info("PlayerRepository: Player %d deactivated.", player_id)
        return result > 0

    # ── HELPERS ────────────────────────────────────────────────────────────────

    def player_exists(self, player_name: str) -> bool:
        count = self._db.execute_scalar(
            "SELECT COUNT(*) FROM Players WHERE PlayerName = ?", (player_name,)
        )
        return int(count or 0) > 0

    def get_player_id_by_name(self, player_name: str) -> int:
        result = self._db.execute_scalar(
            "SELECT PlayerID FROM Players WHERE PlayerName = ? LIMIT 1", (player_name,)
        )
        return int(result) if result is not None else -1

    def get_total_player_count(self, active_only: bool = True) -> int:
        query = (
            "SELECT COUNT(*) FROM Players WHERE IsActive = 1"
            if active_only
            else "SELECT COUNT(*) FROM Players"
        )
        result = self._db.execute_scalar(query)
        return int(result or 0)

    # ── Private ────────────────────────────────────────────────────────────────

    def _create_player_stats(self, player_id: int, now: str) -> None:
        self._db.execute_non_query(
            """INSERT INTO PlayerStats
               (PlayerID, TotalBattles,
                TotalWins, TotalLosses, TotalDraws, LastUpdated)
               VALUES (?, 0, 0, 0, 0, ?)""",
            (player_id, now),
        )


# ── Module-level helpers ───────────────────────────────────────────────────────

def _now() -> str:
    """ISO-8601 datetime string in UTC, matching SQLite's datetime('now')."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def _map_player(row: dict) -> Player:
    """FIX: reads FleetLevel and FleetXP which the Unity version omitted."""
    return Player(
        player_id=int(row.get("PlayerID", 0)),
        player_name=str(row.get("PlayerName", "")),
        email=str(row.get("Email", "")),
        password_hash=str(row.get("PasswordHash", "")),
        created_date=str(row.get("CreatedDate", "")),
        last_played_date=str(row.get("LastPlayedDate", "") or ""),
        is_active=int(row.get("IsActive", 1)) == 1,
        elo=int(row.get("ELO", 0)),
    )
