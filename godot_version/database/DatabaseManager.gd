# DatabaseManager.gd
# Autoload singleton — register in: Project > Project Settings > AutoLoad
# Name it "DatabaseManager" so all scripts can call DatabaseManager.execute_reader(...) etc.
#
# Requires: godot-sqlite plugin by 2shady4u
#   https://github.com/2shady4u/godot-sqlite
#   Install via the Godot Asset Library or copy the addons/ folder into your project.
#
# FIX (vs Unity version): Players table now correctly includes FleetLevel and FleetXP columns.

extends Node

var db: SQLite
var _is_initialized: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func initialize(database_path: String = "user://BattleFleetGame.db") -> void:
	db = SQLite.new()
	db.path = database_path
	db.verbosity_level = SQLite.QUIET

	if not db.open_db():
		push_error("DatabaseManager: Failed to open database at: " + database_path)
		return

	_is_initialized = true
	print("DatabaseManager: Initialized at " + database_path)
	_create_tables()


func close() -> void:
	if _is_initialized:
		db.close_db()
		_is_initialized = false
		print("DatabaseManager: Connection closed.")


func is_ready() -> bool:
	return _is_initialized


# ── Table creation ────────────────────────────────────────────────────────────

func _create_tables() -> void:
	var statements: Array = [
		# Players — FIX: FleetLevel and FleetXP were missing in the Unity DatabaseManager
		"""CREATE TABLE IF NOT EXISTS Players (
			PlayerID INTEGER PRIMARY KEY AUTOINCREMENT,
			PlayerName TEXT NOT NULL UNIQUE,
			CreatedDate TEXT DEFAULT (datetime('now')),
			LastPlayedDate TEXT,
			IsActive INTEGER DEFAULT 1,
			FleetLevel INTEGER NOT NULL DEFAULT 1,
			FleetXP INTEGER NOT NULL DEFAULT 0
		)""",

		"""CREATE TABLE IF NOT EXISTS PlayerStats (
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
		)""",

		"""CREATE TABLE IF NOT EXISTS Captains (
			CaptainID INTEGER PRIMARY KEY AUTOINCREMENT,
			PlayerID INTEGER NOT NULL,
			CaptainName TEXT NOT NULL,
			ExperiencePoints INTEGER DEFAULT 0,
			Level INTEGER DEFAULT 1,
			SpecializationClass TEXT DEFAULT 'General',
			BattlesParticipated INTEGER DEFAULT 0,
			CreatedDate TEXT DEFAULT (datetime('now')),
			IsAvailable INTEGER DEFAULT 1,
			AccuracyBonus REAL DEFAULT 0.0,
			FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
		)""",

		"""CREATE TABLE IF NOT EXISTS CommandCards (
			CardID INTEGER PRIMARY KEY AUTOINCREMENT,
			CardName TEXT NOT NULL UNIQUE,
			Description TEXT,
			RequiredCaptainLevel INTEGER NOT NULL DEFAULT 1,
			AccuracyBonus REAL DEFAULT 0.0,
			CardType TEXT DEFAULT 'Tactical'
		)""",

		"""CREATE TABLE IF NOT EXISTS CaptainCommandCards (
			ID INTEGER PRIMARY KEY AUTOINCREMENT,
			CaptainID INTEGER NOT NULL,
			CardID INTEGER NOT NULL,
			UnlockedDate TEXT DEFAULT (datetime('now')),
			UNIQUE(CaptainID, CardID),
			FOREIGN KEY (CaptainID) REFERENCES Captains(CaptainID) ON DELETE CASCADE,
			FOREIGN KEY (CardID) REFERENCES CommandCards(CardID) ON DELETE CASCADE
		)""",

		"""CREATE TABLE IF NOT EXISTS PlayerShips (
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
		)""",

		"""CREATE TABLE IF NOT EXISTS ShipWeapons (
			WeaponID INTEGER PRIMARY KEY AUTOINCREMENT,
			ShipID INTEGER NOT NULL,
			WeaponType TEXT NOT NULL,
			Quantity INTEGER DEFAULT 1,
			Accuracy INTEGER DEFAULT 75,
			Damage INTEGER DEFAULT 10,
			Range INTEGER DEFAULT 50,
			IsOperational INTEGER DEFAULT 1,
			FOREIGN KEY (ShipID) REFERENCES PlayerShips(ShipID) ON DELETE CASCADE
		)""",

		"""CREATE TABLE IF NOT EXISTS CampaignSaves (
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

		"""CREATE TABLE IF NOT EXISTS PlayerAchievements (
			AchievementID INTEGER PRIMARY KEY AUTOINCREMENT,
			PlayerID INTEGER NOT NULL,
			AchievementType TEXT NOT NULL,
			UnlockedDate TEXT DEFAULT (datetime('now')),
			FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
		)""",

		"""CREATE TABLE IF NOT EXISTS ShipUnlockRequirements (
			ShipType TEXT PRIMARY KEY,
			RequiredLevel INTEGER NOT NULL,
			DisplayName TEXT NOT NULL,
			Description TEXT
		)""",

		# Indexes
		"CREATE INDEX IF NOT EXISTS idx_players_name           ON Players(PlayerName)",
		"CREATE INDEX IF NOT EXISTS idx_playerstats_playerid   ON PlayerStats(PlayerID)",
		"CREATE INDEX IF NOT EXISTS idx_captains_playerid      ON Captains(PlayerID)",
		"CREATE INDEX IF NOT EXISTS idx_playerships_playerid   ON PlayerShips(PlayerID)",
		"CREATE INDEX IF NOT EXISTS idx_battlehistory_playerid ON BattleHistory(PlayerID)",
		"CREATE INDEX IF NOT EXISTS idx_achievements_playerid  ON PlayerAchievements(PlayerID)",
		"CREATE INDEX IF NOT EXISTS idx_captainccards_cid      ON CaptainCommandCards(CaptainID)",

		# Seed: CommandCards
		"INSERT OR IGNORE INTO CommandCards (CardName, Description, RequiredCaptainLevel, AccuracyBonus, CardType) VALUES ('Steady Aim', 'The captain steadies the crew''s aim, reducing spread. +3% accuracy.', 1, 3.0, 'Tactical')",
		"INSERT OR IGNORE INTO CommandCards (CardName, Description, RequiredCaptainLevel, AccuracyBonus, CardType) VALUES ('Broadside Volley', 'Orders all cannons to fire simultaneously for maximum impact.', 2, 0.0, 'Offensive')",
		"INSERT OR IGNORE INTO CommandCards (CardName, Description, RequiredCaptainLevel, AccuracyBonus, CardType) VALUES ('Evasive Maneuvers', 'Directs the ship to weave through fire, reducing incoming hit chance.', 3, 0.0, 'Defensive')",
		"INSERT OR IGNORE INTO CommandCards (CardName, Description, RequiredCaptainLevel, AccuracyBonus, CardType) VALUES ('Suppressing Fire', 'Sustained fire disrupts the enemy crew''s targeting for one turn.', 4, 0.0, 'Offensive')",
		"INSERT OR IGNORE INTO CommandCards (CardName, Description, RequiredCaptainLevel, AccuracyBonus, CardType) VALUES ('Admiral''s Command', 'A masterful tactical order that boosts the entire crew''s performance. +5% accuracy.', 5, 5.0, 'Tactical')",

		# Seed: ShipUnlockRequirements
		"INSERT OR IGNORE INTO ShipUnlockRequirements (ShipType, RequiredLevel, DisplayName, Description) VALUES ('Sloop',   1, 'Sloop',     'Available from the start')",
		"INSERT OR IGNORE INTO ShipUnlockRequirements (ShipType, RequiredLevel, DisplayName, Description) VALUES ('Brig',    1, 'Brig',      'Available from the start')",
		"INSERT OR IGNORE INTO ShipUnlockRequirements (ShipType, RequiredLevel, DisplayName, Description) VALUES ('Frigate', 3, 'Frigate',   'Unlock at Fleet Level 3')",
		"INSERT OR IGNORE INTO ShipUnlockRequirements (ShipType, RequiredLevel, DisplayName, Description) VALUES ('ManOWar', 5, 'Man-O-War', 'Unlock at Fleet Level 5')",
		"INSERT OR IGNORE INTO ShipUnlockRequirements (ShipType, RequiredLevel, DisplayName, Description) VALUES ('Ironclad',6, 'Ironclad',  'Unlock at Fleet Level 6')",
		"INSERT OR IGNORE INTO ShipUnlockRequirements (ShipType, RequiredLevel, DisplayName, Description) VALUES ('Carrier', 7, 'Carrier',   'Unlock at Fleet Level 7')",
	]

	for stmt in statements:
		if not db.query(stmt):
			push_error("DatabaseManager: Statement failed: " + str(stmt).substr(0, 60) + "...")

	print("DatabaseManager: All tables created/verified.")


# ── Query helpers ─────────────────────────────────────────────────────────────

## INSERT / UPDATE / DELETE. Returns affected_rows or -1 on failure.
func execute_non_query(query: String, params: Array = []) -> int:
	if not _is_initialized:
		push_error("DatabaseManager: Not initialized. Call initialize() first.")
		return -1
	var ok: bool = _run(query, params)
	return db.affected_rows if ok else -1


## Returns the first column of the first row, or null.
func execute_scalar(query: String, params: Array = []) -> Variant:
	if not _is_initialized:
		push_error("DatabaseManager: Not initialized.")
		return null
	if not _run(query, params):
		return null
	var rows: Array = db.query_result
	if rows.size() > 0 and rows[0].size() > 0:
		return rows[0].values()[0]
	return null


## Returns an Array of Dictionaries (one per row). Keys = column names.
func execute_reader(query: String, params: Array = []) -> Array:
	if not _is_initialized:
		push_error("DatabaseManager: Not initialized.")
		return []
	if not _run(query, params):
		return []
	return db.query_result


## Returns the rowid of the last INSERT.
func get_last_insert_id() -> int:
	return db.last_insert_rowid


func _run(query: String, params: Array) -> bool:
	if params.is_empty():
		return db.query(query)
	return db.query_with_bindings(query, params)
