using System;
using System.Collections.Generic;
using System.Data;
using Mono.Data.Sqlite;
using UnityEngine;

namespace BattleFleet.Database
{
    /// <summary>
    /// Database manager - handles all SQLite database operations
    /// Manages connection lifecycle and query execution
    /// </summary>
    public class DatabaseManager
    {
        private string connectionString;
        private IDbConnection dbConnection;
        private bool isInitialized = false;

        // Static instance for singleton pattern
        private static DatabaseManager instance;
        
        public static DatabaseManager Instance
        {
            get
            {
                if (instance == null)
                {
                    instance = new DatabaseManager();
                }
                return instance;
            }
        }

        /// <summary>
        /// Initialize the database connection
        /// Call this once at game startup
        /// </summary>
        public void Initialize(string databasePath = "BattleFleetGame.db")
        {
            try
            {
                // Create connection string for SQLite
                connectionString = $"URI=file:{databasePath}";
                
                // Create and open connection
                dbConnection = new SqliteConnection(connectionString);
                dbConnection.Open();
                
                isInitialized = true;
                Debug.Log($"Database initialized successfully at: {databasePath}");
                
                // Create all tables from schema
                CreateTablesIfNotExist();
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to initialize database: {e.Message}");
                isInitialized = false;
                throw;
            }
        }

        /// <summary>
        /// Create all necessary tables if they don't already exist
        /// </summary>
        private void CreateTablesIfNotExist()
        {
            string[] createTableQueries = new string[]
            {
                // Players Table
                @"CREATE TABLE IF NOT EXISTS Players (
                    PlayerID INTEGER PRIMARY KEY AUTOINCREMENT,
                    PlayerName TEXT NOT NULL UNIQUE,
                    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
                    LastPlayedDate DATETIME,
                    IsActive INTEGER DEFAULT 1
                )",

                // Player Statistics Table
                @"CREATE TABLE IF NOT EXISTS PlayerStats (
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
                )",

                // Captains Progression Table
                @"CREATE TABLE IF NOT EXISTS Captains (
                    CaptainID INTEGER PRIMARY KEY AUTOINCREMENT,
                    PlayerID INTEGER NOT NULL,
                    CaptainName TEXT NOT NULL,
                    ExperiencePoints INTEGER DEFAULT 0,
                    Level INTEGER DEFAULT 1,
                    SpecializationClass TEXT DEFAULT 'General',
                    BattlesParticipated INTEGER DEFAULT 0,
                    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
                    IsAvailable INTEGER DEFAULT 1,
                    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
                )",

                // Ships Table
                @"CREATE TABLE IF NOT EXISTS PlayerShips (
                    ShipID INTEGER PRIMARY KEY AUTOINCREMENT,
                    PlayerID INTEGER NOT NULL,
                    ShipName TEXT NOT NULL,
                    ShipClass TEXT NOT NULL,
                    HullHealth INTEGER DEFAULT 100,
                    MaxHullHealth INTEGER DEFAULT 100,
                    Level INTEGER DEFAULT 1,
                    ExperiencePoints INTEGER DEFAULT 0,
                    IsAlive INTEGER DEFAULT 1,
                    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
                )",

                // Ship Weapons Table
                @"CREATE TABLE IF NOT EXISTS ShipWeapons (
                    WeaponID INTEGER PRIMARY KEY AUTOINCREMENT,
                    ShipID INTEGER NOT NULL,
                    WeaponType TEXT NOT NULL,
                    Quantity INTEGER DEFAULT 1,
                    Accuracy INTEGER DEFAULT 75,
                    Damage INTEGER DEFAULT 10,
                    Range INTEGER DEFAULT 50,
                    IsOperational INTEGER DEFAULT 1,
                    FOREIGN KEY (ShipID) REFERENCES PlayerShips(ShipID) ON DELETE CASCADE
                )",

                // Campaign Saves Table
                @"CREATE TABLE IF NOT EXISTS CampaignSaves (
                    SaveID INTEGER PRIMARY KEY AUTOINCREMENT,
                    PlayerID INTEGER NOT NULL,
                    CampaignName TEXT NOT NULL,
                    CurrentTurn INTEGER DEFAULT 1,
                    TerritoryControlled INTEGER DEFAULT 0,
                    ResourcePoints INTEGER DEFAULT 0,
                    EnemyFaction TEXT DEFAULT 'Japan',
                    DifficultyLevel TEXT DEFAULT 'Normal',
                    SaveDate DATETIME DEFAULT CURRENT_TIMESTAMP,
                    LastLoadedDate DATETIME,
                    IsActive INTEGER DEFAULT 1,
                    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
                )",

                // Battle History Table
                @"CREATE TABLE IF NOT EXISTS BattleHistory (
                    BattleID INTEGER PRIMARY KEY AUTOINCREMENT,
                    PlayerID INTEGER NOT NULL,
                    OpponentName TEXT NOT NULL,
                    BattleDate DATETIME DEFAULT CURRENT_TIMESTAMP,
                    Result TEXT NOT NULL,
                    ShipsDestroyed INTEGER DEFAULT 0,
                    ShipsLost INTEGER DEFAULT 0,
                    ExperienceGained INTEGER DEFAULT 0,
                    DifficultyLevel TEXT DEFAULT 'Normal',
                    BattleMode TEXT DEFAULT 'SkirmishBattle',
                    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
                )",

                // Achievements Table
                @"CREATE TABLE IF NOT EXISTS PlayerAchievements (
                    AchievementID INTEGER PRIMARY KEY AUTOINCREMENT,
                    PlayerID INTEGER NOT NULL,
                    AchievementType TEXT NOT NULL,
                    UnlockedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID) ON DELETE CASCADE
                )"
            };

            foreach (string query in createTableQueries)
            {
                ExecuteNonQuery(query);
            }

            Debug.Log("All database tables created/verified successfully.");
        }

        /// <summary>
        /// Execute a non-query command (INSERT, UPDATE, DELETE)
        /// </summary>
        public int ExecuteNonQuery(string query, Dictionary<string, object> parameters = null)
        {
            if (!isInitialized)
            {
                Debug.LogError("Database not initialized. Call Initialize() first.");
                return -1;
            }

            try
            {
                using (IDbCommand command = dbConnection.CreateCommand())
                {
                    command.CommandText = query;

                    if (parameters != null)
                    {
                        foreach (var param in parameters)
                        {
                            IDbDataParameter dbParam = command.CreateParameter();
                            dbParam.ParameterName = param.Key;
                            dbParam.Value = param.Value ?? DBNull.Value;
                            command.Parameters.Add(dbParam);
                        }
                    }

                    return command.ExecuteNonQuery();
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"Database ExecuteNonQuery error: {e.Message}\nQuery: {query}");
                return -1;
            }
        }

        /// <summary>
        /// Execute a query that returns a single scalar value
        /// </summary>
        public object ExecuteScalar(string query, Dictionary<string, object> parameters = null)
        {
            if (!isInitialized)
            {
                Debug.LogError("Database not initialized. Call Initialize() first.");
                return null;
            }

            try
            {
                using (IDbCommand command = dbConnection.CreateCommand())
                {
                    command.CommandText = query;

                    if (parameters != null)
                    {
                        foreach (var param in parameters)
                        {
                            IDbDataParameter dbParam = command.CreateParameter();
                            dbParam.ParameterName = param.Key;
                            dbParam.Value = param.Value ?? DBNull.Value;
                            command.Parameters.Add(dbParam);
                        }
                    }

                    return command.ExecuteScalar();
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"Database ExecuteScalar error: {e.Message}\nQuery: {query}");
                return null;
            }
        }

        /// <summary>
        /// Execute a query that returns multiple rows
        /// </summary>
        public IDataReader ExecuteReader(string query, Dictionary<string, object> parameters = null)
        {
            if (!isInitialized)
            {
                Debug.LogError("Database not initialized. Call Initialize() first.");
                return null;
            }

            try
            {
                IDbCommand command = dbConnection.CreateCommand();
                command.CommandText = query;

                if (parameters != null)
                {
                    foreach (var param in parameters)
                    {
                        IDbDataParameter dbParam = command.CreateParameter();
                        dbParam.ParameterName = param.Key;
                        dbParam.Value = param.Value ?? DBNull.Value;
                        command.Parameters.Add(dbParam);
                    }
                }

                return command.ExecuteReader(CommandBehavior.CloseConnection);
            }
            catch (Exception e)
            {
                Debug.LogError($"Database ExecuteReader error: {e.Message}\nQuery: {query}");
                return null;
            }
        }

        /// <summary>
        /// Close and dispose of the database connection
        /// Call this when the game closes
        /// </summary>
        public void Close()
        {
            if (dbConnection != null && dbConnection.State == ConnectionState.Open)
            {
                dbConnection.Close();
                dbConnection.Dispose();
                isInitialized = false;
                Debug.Log("Database connection closed.");
            }
        }

        /// <summary>
        /// Check if database is properly initialized
        /// </summary>
        public bool IsInitialized
        {
            get { return isInitialized && dbConnection != null && dbConnection.State == ConnectionState.Open; }
        }

        /// <summary>
        /// Begin a transaction for atomic operations
        /// </summary>
        public IDbTransaction BeginTransaction()
        {
            if (!isInitialized)
            {
                Debug.LogError("Database not initialized.");
                return null;
            }
            return dbConnection.BeginTransaction();
        }
    }
}
