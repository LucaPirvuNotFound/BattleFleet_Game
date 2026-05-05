-- Battle Fleet 2 Game - SQLite Database Schema
-- Database for player management, stats tracking, and progression system

-- Main Players Table
CREATE TABLE IF NOT EXISTS Players (
    PlayerID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerName TEXT NOT NULL UNIQUE,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    LastPlayedDate DATETIME,
    IsActive INTEGER DEFAULT 1
);

-- Player Statistics Table
CREATE TABLE IF NOT EXISTS PlayerStats (
    StatID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerID INTEGER NOT NULL UNIQUE,
    Level INTEGER DEFAULT 1,
    TotalExperience INTEGER DEFAULT 0,
    TotalBattles INTEGER DEFAULT 0,
    TotalWins INTEGER DEFAULT 0,
    TotalLosses INTEGER DEFAULT 0,
    TotalDraws INTEGER DEFAULT 0,
    AverageAccuracy REAL DEFAULT 0.0,
    TotalShipsDestroyed INTEGER DEFAULT 0,
    TotalShipsLost INTEGER DEFAULT 0,
    CampaignProgressPercentage REAL DEFAULT 0.0,
    HighestLevel INTEGER DEFAULT 1,
    LastUpdated DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
);

-- Captains Progression Table
CREATE TABLE IF NOT EXISTS Captains (
    CaptainID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerID INTEGER NOT NULL,
    CaptainName TEXT NOT NULL,
    ExperiencePoints INTEGER DEFAULT 0,
    Level INTEGER DEFAULT 1,
    SpecializationClass TEXT DEFAULT 'General', -- General, Aggressive, Defensive, Scout
    BattlesParticipated INTEGER DEFAULT 0,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    IsAvailable INTEGER DEFAULT 1,
    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
);

-- Ships Owned by Player Table
CREATE TABLE IF NOT EXISTS PlayerShips (
    ShipID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerID INTEGER NOT NULL,
    ShipName TEXT NOT NULL,
    ShipClass TEXT NOT NULL, -- Battleship, Cruiser, Destroyer, Frigate, Submarine, Carrier, etc.
    HullHealth INTEGER DEFAULT 100,
    MaxHullHealth INTEGER DEFAULT 100,
    Level INTEGER DEFAULT 1,
    ExperiencePoints INTEGER DEFAULT 0,
    IsAlive INTEGER DEFAULT 1,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
);

-- Ship Weapons Configuration Table
CREATE TABLE IF NOT EXISTS ShipWeapons (
    WeaponID INTEGER PRIMARY KEY AUTOINCREMENT,
    ShipID INTEGER NOT NULL,
    WeaponType TEXT NOT NULL, -- AAGun, Torpedo, NavalArtillery, etc.
    Quantity INTEGER DEFAULT 1,
    Accuracy INTEGER DEFAULT 75,
    Damage INTEGER DEFAULT 10,
    Range INTEGER DEFAULT 50,
    IsOperational INTEGER DEFAULT 1,
    FOREIGN KEY (ShipID) REFERENCES PlayerShips(ShipID) ON DELETE CASCADE
);

-- Campaign Save Data Table
CREATE TABLE IF NOT EXISTS CampaignSaves (
    SaveID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerID INTEGER NOT NULL,
    CampaignName TEXT NOT NULL,
    CurrentTurn INTEGER DEFAULT 1,
    TerritoryControlled INTEGER DEFAULT 0,
    ResourcePoints INTEGER DEFAULT 0,
    EnemyFaction TEXT DEFAULT 'Japan',
    DifficultyLevel TEXT DEFAULT 'Normal', -- Easy, Normal, Hard, Expert
    SaveDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    LastLoadedDate DATETIME,
    IsActive INTEGER DEFAULT 1,
    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
);

-- Battle History Table
CREATE TABLE IF NOT EXISTS BattleHistory (
    BattleID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerID INTEGER NOT NULL,
    OpponentName TEXT NOT NULL,
    BattleDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    Result TEXT NOT NULL, -- Win, Loss, Draw
    ShipsDestroyed INTEGER DEFAULT 0,
    ShipsLost INTEGER DEFAULT 0,
    ExperienceGained INTEGER DEFAULT 0,
    DifficultyLevel TEXT DEFAULT 'Normal',
    BattleMode TEXT DEFAULT 'SkirmishBattle', -- SkirmishBattle, Campaign, Multiplayer
    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
);

-- Achievements/Unlockables Table
CREATE TABLE IF NOT EXISTS PlayerAchievements (
    AchievementID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerID INTEGER NOT NULL,
    AchievementType TEXT NOT NULL, -- FirstVictory, MasterClass, FleetCommander, etc.
    UnlockedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
);

-- Create Indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_players_name ON Players(PlayerName);
CREATE INDEX IF NOT EXISTS idx_playerstats_playerid ON PlayerStats(PlayerID);
CREATE INDEX IF NOT EXISTS idx_captains_playerid ON Captains(PlayerID);
CREATE INDEX IF NOT EXISTS idx_playerships_playerid ON PlayerShips(PlayerID);
CREATE INDEX IF NOT EXISTS idx_shipweapons_shipid ON ShipWeapons(ShipID);
CREATE INDEX IF NOT EXISTS idx_campaignsaves_playerid ON CampaignSaves(PlayerID);
CREATE INDEX IF NOT EXISTS idx_battlehistory_playerid ON BattleHistory(PlayerID);
CREATE INDEX IF NOT EXISTS idx_achievements_playerid ON PlayerAchievements(PlayerID);
