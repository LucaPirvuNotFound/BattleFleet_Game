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
    FleetLevel INTEGER NOT NULL DEFAULT 1,
    FleetXP INTEGER NOT NULL DEFAULT 0
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
    LastUpdated TEXT DEFAULT (datetime('now')),
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
    CreatedDate TEXT DEFAULT (datetime('now')),
    IsAvailable INTEGER DEFAULT 1,
    AccuracyBonus REAL DEFAULT 0.0,
    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
);

-- Command Cards Table (static reference data)
CREATE TABLE IF NOT EXISTS CommandCards (
    CardID INTEGER PRIMARY KEY AUTOINCREMENT,
    CardName TEXT NOT NULL UNIQUE,
    Description TEXT,
    RequiredCaptainLevel INTEGER NOT NULL DEFAULT 1,
    AccuracyBonus REAL DEFAULT 0.0,
    CardType TEXT DEFAULT 'Tactical' -- Tactical, Offensive, Defensive
);

-- Seed command cards (one card per captain level)
INSERT OR IGNORE INTO CommandCards (CardName, Description, RequiredCaptainLevel, AccuracyBonus, CardType) VALUES
    ('Steady Aim',         'The captain steadies the crew''s aim, reducing spread. +3% accuracy.',                  1, 3.0, 'Tactical'),
    ('Broadside Volley',   'Orders all cannons to fire simultaneously for maximum impact.',                         2, 0.0, 'Offensive'),
    ('Evasive Maneuvers',  'Directs the ship to weave through fire, reducing incoming hit chance.',                 3, 0.0, 'Defensive'),
    ('Suppressing Fire',   'Sustained fire disrupts the enemy crew''s targeting for one turn.',                     4, 0.0, 'Offensive'),
    ('Admiral''s Command', 'A masterful tactical order that boosts the entire crew''s performance. +5% accuracy.',  5, 5.0, 'Tactical');

-- Captain Command Cards Junction Table
CREATE TABLE IF NOT EXISTS CaptainCommandCards (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    CaptainID INTEGER NOT NULL,
    CardID INTEGER NOT NULL,
    UnlockedDate TEXT DEFAULT (datetime('now')),
    UNIQUE(CaptainID, CardID),
    FOREIGN KEY (CaptainID) REFERENCES Captains(CaptainID) ON DELETE CASCADE,
    FOREIGN KEY (CardID) REFERENCES CommandCards(CardID) ON DELETE CASCADE
);

-- Ships Owned by Player
CREATE TABLE IF NOT EXISTS PlayerShips (
    ShipID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerID INTEGER NOT NULL,
    ShipName TEXT NOT NULL,
    ShipClass TEXT NOT NULL,
    HullHealth INTEGER DEFAULT 100,
    MaxHullHealth INTEGER DEFAULT 100,
    Level INTEGER DEFAULT 1,
    ExperiencePoints INTEGER DEFAULT 0,
    IsAlive INTEGER DEFAULT 1,
    CreatedDate TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
);

-- Ship Weapons Configuration
CREATE TABLE IF NOT EXISTS ShipWeapons (
    WeaponID INTEGER PRIMARY KEY AUTOINCREMENT,
    ShipID INTEGER NOT NULL,
    WeaponType TEXT NOT NULL,
    Quantity INTEGER DEFAULT 1,
    Accuracy INTEGER DEFAULT 75,
    Damage INTEGER DEFAULT 10,
    Range INTEGER DEFAULT 50,
    IsOperational INTEGER DEFAULT 1,
    FOREIGN KEY (ShipID) REFERENCES PlayerShips(ShipID) ON DELETE CASCADE
);

-- Campaign Save Data
CREATE TABLE IF NOT EXISTS CampaignSaves (
    SaveID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerID INTEGER NOT NULL,
    CampaignName TEXT NOT NULL,
    CurrentTurn INTEGER DEFAULT 1,
    TerritoryControlled INTEGER DEFAULT 0,
    ResourcePoints INTEGER DEFAULT 0,
    EnemyFaction TEXT DEFAULT 'Japan',
    DifficultyLevel TEXT DEFAULT 'Normal',
    SaveDate TEXT DEFAULT (datetime('now')),
    LastLoadedDate TEXT,
    IsActive INTEGER DEFAULT 1,
    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
);

-- Battle History
CREATE TABLE IF NOT EXISTS BattleHistory (
    BattleID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerID INTEGER NOT NULL,
    OpponentName TEXT NOT NULL,
    BattleDate TEXT DEFAULT (datetime('now')),
    Result TEXT NOT NULL, -- Win, Loss, Draw
    ShipsDestroyed INTEGER DEFAULT 0,
    ShipsLost INTEGER DEFAULT 0,
    ExperienceGained INTEGER DEFAULT 0,
    DifficultyLevel TEXT DEFAULT 'Normal',
    BattleMode TEXT DEFAULT 'SkirmishBattle',
    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
);

-- Achievements
CREATE TABLE IF NOT EXISTS PlayerAchievements (
    AchievementID INTEGER PRIMARY KEY AUTOINCREMENT,
    PlayerID INTEGER NOT NULL,
    AchievementType TEXT NOT NULL,
    UnlockedDate TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
);

-- Ship Unlock Requirements (fleet-level gating)
CREATE TABLE IF NOT EXISTS ShipUnlockRequirements (
    ShipType TEXT PRIMARY KEY,
    RequiredLevel INTEGER NOT NULL,
    DisplayName TEXT NOT NULL,
    Description TEXT
);

-- Seed ship unlock thresholds
INSERT OR IGNORE INTO ShipUnlockRequirements (ShipType, RequiredLevel, DisplayName, Description) VALUES
    ('Sloop',   1, 'Sloop',       'Available from the start'),
    ('Brig',    1, 'Brig',        'Available from the start'),
    ('Frigate', 3, 'Frigate',     'Unlock at Fleet Level 3'),
    ('ManOWar', 5, 'Man-O-War',   'Unlock at Fleet Level 5'),
    ('Ironclad',6, 'Ironclad',    'Unlock at Fleet Level 6'),
    ('Carrier', 7, 'Carrier',     'Unlock at Fleet Level 7');

-- Indexes
CREATE INDEX IF NOT EXISTS idx_players_name              ON Players(PlayerName);
CREATE INDEX IF NOT EXISTS idx_playerstats_playerid      ON PlayerStats(PlayerID);
CREATE INDEX IF NOT EXISTS idx_captains_playerid         ON Captains(PlayerID);
CREATE INDEX IF NOT EXISTS idx_playerships_playerid      ON PlayerShips(PlayerID);
CREATE INDEX IF NOT EXISTS idx_shipweapons_shipid        ON ShipWeapons(ShipID);
CREATE INDEX IF NOT EXISTS idx_campaignsaves_playerid    ON CampaignSaves(PlayerID);
CREATE INDEX IF NOT EXISTS idx_battlehistory_playerid    ON BattleHistory(PlayerID);
CREATE INDEX IF NOT EXISTS idx_achievements_playerid     ON PlayerAchievements(PlayerID);
CREATE INDEX IF NOT EXISTS idx_captaincommandcards_cid   ON CaptainCommandCards(CaptainID);
