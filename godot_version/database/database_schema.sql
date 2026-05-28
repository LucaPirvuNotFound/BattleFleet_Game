-- Battle Fleet 2 Game - SQLite Database Schema
-- Godot Version: engine-agnostic SQLite, used via godot-sqlite plugin
-- Column names use PascalCase throughout — keep consistent with GDScript repositories

-- Main Players Table
CREATE TABLE IF NOT EXISTS Players (
    PlayerID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerName TEXT NOT NULL UNIQUE,
    CreatedDate TEXT DEFAULT (datetime('now')),
    LastPlayedDate TEXT,
    IsActive INTEGER DEFAULT 1,
    ELO INTEGER NOT NULL DEFAULT 0
);

-- Player Statistics Table
CREATE TABLE IF NOT EXISTS PlayerStats (
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
);


-- Battle History
CREATE TABLE IF NOT EXISTS BattleHistory (
    BattleID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerID INTEGER NOT NULL,
    OpponentName TEXT NOT NULL,
    BattleDate TEXT DEFAULT (datetime('now')),
    Result INTEGER NOT NULL, 
    ShipsDestroyed INTEGER DEFAULT 0,
    ShipsLost INTEGER DEFAULT 0,
    DifficultyLevel TEXT DEFAULT 'Normal',
    BattleMode TEXT DEFAULT 'SkirmishBattle',
    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Move(
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
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_players_name              ON Players(PlayerName);
CREATE INDEX IF NOT EXISTS idx_playerstats_playerid      ON PlayerStats(PlayerID);
CREATE INDEX IF NOT EXISTS idx_battlehistory_playerid    ON BattleHistory(PlayerID);
CREATE INDEX IF NOT EXISTS idx_move_battleid             ON Move(BattleID)