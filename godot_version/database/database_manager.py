# database_manager.py
# Central SQLite connection manager — Python equivalent of DatabaseManager.gd
#
# Usage:
#   db = DatabaseManager()
#   db.initialize()          # opens / creates the database
#   db.execute_non_query(...)
#   db.execute_scalar(...)
#   db.execute_reader(...)
#   db.close()
#
# The class is intentionally NOT a singleton here; pass the instance to every
# repository that needs it (constructor injection).  If you want a process-wide
# singleton you can wrap it with a module-level instance at the bottom.

import sqlite3
import logging
from typing import Any, Optional

logger = logging.getLogger(__name__)


class DatabaseManager:

    def __init__(self, database_path: str = "BattleFleetGame.db") -> None:
        self._database_path: str = database_path
        self._conn: Optional[sqlite3.Connection] = None
        self._is_initialized: bool = False

    # ── Lifecycle ──────────────────────────────────────────────────────────────

    def initialize(self) -> None:
        """Open (or create) the SQLite database and run schema migrations."""
        try:
            # isolation_level=None → autocommit mode, matching the godot-sqlite
            # plugin behaviour where every db.query() is its own implicit transaction.
            self._conn = sqlite3.connect(self._database_path, isolation_level=None)
            # Return rows as sqlite3.Row so columns are accessible by name,
            # mirroring the Dictionary results that GDScript received.
            self._conn.row_factory = sqlite3.Row
            # Enable foreign-key enforcement (SQLite has it OFF by default).
            self._conn.execute("PRAGMA foreign_keys = ON")
            self._is_initialized = True
            logger.info("DatabaseManager: Initialized at %s", self._database_path)
            self._create_tables()
        except sqlite3.Error as exc:
            logger.error("DatabaseManager: Failed to open database at %s — %s",
                         self._database_path, exc)

    def close(self) -> None:
        if self._is_initialized and self._conn is not None:
            self._conn.close()
            self._conn = None
            self._is_initialized = False
            logger.info("DatabaseManager: Connection closed.")

    def is_ready(self) -> bool:
        return self._is_initialized

    # ── Table creation ─────────────────────────────────────────────────────────

    def _create_tables(self) -> None:
        statements: list[str] = [
            # Players
            """CREATE TABLE IF NOT EXISTS Players (
                PlayerID INTEGER PRIMARY KEY AUTOINCREMENT,
                PlayerName TEXT NOT NULL UNIQUE,
                CreatedDate TEXT DEFAULT (datetime('now')),
                LastPlayedDate TEXT,
                IsActive INTEGER DEFAULT 1,
                ELO INTEGER NOT NULL DEFAULT 0
            )""",

            """CREATE TABLE IF NOT EXISTS PlayerStats (
                StatID INTEGER PRIMARY KEY AUTOINCREMENT,
                PlayerID INTEGER NOT NULL UNIQUE,
                TotalBattles INTEGER DEFAULT 0,
                TotalWins INTEGER DEFAULT 0,
                TotalLosses INTEGER DEFAULT 0,
                TotalDraws INTEGER DEFAULT 0,
                AverageAccuracy REAL DEFAULT 0.0,
                TotalShipsDestroyed INTEGER DEFAULT 0,
                TotalShipsLost INTEGER DEFAULT 0,
                BattleshipKills INTEGER DEFAULT 0,
                BattleshipDeaths INTEGER DEFAULT 0,
                BattleshipAccuracy INTEGER DEFAULT 0,
                CruiserKills INTEGER DEFAULT 0,
                CruiserDeaths INTEGER DEFAULT 0,
                CruiserAccuracy INTEGER DEFAULT 0,
                DestroyerKills INTEGER DEFAULT 0,
                DestroyerDeaths INTEGER DEFAULT 0,
                DestroyerAccuracy INTEGER DEFAULT 0,
                CorvetteKills INTEGER DEFAULT 0,
                CorvetteDeaths INTEGER DEFAULT 0,
                CorvetteAccuracy INTEGER DEFAULT 0,
                TorpedoBoatKills INTEGER DEFAULT 0,
                TorpedoBoatDeaths INTEGER DEFAULT 0,
                TorpedoBoatAccuracy INTEGER DEFAULT 0,
                LastUpdated TEXT DEFAULT (datetime('now')),
                FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
            )""",

            """CREATE TABLE IF NOT EXISTS BattleHistory (
                BattleID INTEGER PRIMARY KEY AUTOINCREMENT,
                PlayerID INTEGER NOT NULL,
                OpponentName TEXT NOT NULL,
                BattleDate TEXT DEFAULT (datetime('now')),
                Result TEXT NOT NULL,
                ShipsDestroyed INTEGER DEFAULT 0,
                ShipsLost INTEGER DEFAULT 0,
                ExperienceGained INTEGER DEFAULT 0,
                DifficultyLevel TEXT DEFAULT 'Normal',
                BattleMode TEXT DEFAULT 'SkirmishBattle',
                FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
            )""",

            """CREATE TABLE IF NOT EXISTS Move(
                MoveID INTEGER PRIMARY KEY AUTOINCREMENT,
                BattleID INTEGER NOT NULL,
                TurnNumber INTEGER NOT NULL,
                MatchID INTEGER NOT NULL,
                PlayerID INTEGER NOT NULL,
                Type TEXT NOT NULL,
                Distance REAL DEFAULT 0.0,
                Angle REAL NOT NULL,
                Position TEXT NOT NULL,
                FOREIGN KEY (BattleID) REFERENCES BattleHistory(BattleID) ON DELETE CASCADE
            )""",

            # Indexes
            "CREATE INDEX IF NOT EXISTS idx_players_name           ON Players(PlayerName)",
            "CREATE INDEX IF NOT EXISTS idx_playerstats_playerid   ON PlayerStats(PlayerID)",
            "CREATE INDEX IF NOT EXISTS idx_battlehistory_playerid ON BattleHistory(PlayerID)",
            "CREATE INDEX IF NOT EXISTS idx_move_battleid          ON Move(BattleID)",
        ]

        for stmt in statements:
            try:
                self._conn.execute(stmt)
            except sqlite3.Error as exc:
                logger.error("DatabaseManager: Statement failed (%s...): %s",
                             stmt[:60], exc)

        logger.info("DatabaseManager: All tables created/verified.")

    # ── Query helpers ──────────────────────────────────────────────────────────

    def execute_non_query(self, query: str, params: tuple | list = ()) -> int:
        """INSERT / UPDATE / DELETE.  Returns affected row count, or -1 on failure."""
        if not self._is_initialized:
            logger.error("DatabaseManager: Not initialized. Call initialize() first.")
            return -1
        try:
            cursor = self._conn.execute(query, params)
            return cursor.rowcount
        except sqlite3.Error as exc:
            logger.error("DatabaseManager: execute_non_query failed — %s", exc)
            return -1

    def execute_scalar(self, query: str, params: tuple | list = ()) -> Any:
        """Returns the first column of the first row, or None."""
        if not self._is_initialized:
            logger.error("DatabaseManager: Not initialized.")
            return None
        try:
            cursor = self._conn.execute(query, params)
            row = cursor.fetchone()
            if row and len(row) > 0:
                return row[0]
            return None
        except sqlite3.Error as exc:
            logger.error("DatabaseManager: execute_scalar failed — %s", exc)
            return None

    def execute_reader(self, query: str, params: tuple | list = ()) -> list[dict]:
        """Returns a list of dicts (one per row). Keys = column names."""
        if not self._is_initialized:
            logger.error("DatabaseManager: Not initialized.")
            return []
        try:
            cursor = self._conn.execute(query, params)
            # sqlite3.Row supports both index and key access; convert to plain
            # dict so callers can use row["ColumnName"] without extra imports.
            return [dict(row) for row in cursor.fetchall()]
        except sqlite3.Error as exc:
            logger.error("DatabaseManager: execute_reader failed — %s", exc)
            return []

    def get_last_insert_id(self) -> int:
        """Returns the rowid of the last INSERT."""
        if not self._is_initialized or self._conn is None:
            return -1
        # lastrowid is on the cursor, not the connection; we ask SQLite directly.
        result = self.execute_scalar("SELECT last_insert_rowid()")
        return int(result) if result is not None else -1
