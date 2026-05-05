using System;
using System.Collections.Generic;
using System.Data;
using UnityEngine;

namespace BattleFleet.Database
{
    /// <summary>
    /// Player Repository - CRUD operations for Player table
    /// Handles all player-related database operations
    /// </summary>
    public class PlayerRepository
    {
        private DatabaseManager dbManager;

        public PlayerRepository()
        {
            dbManager = DatabaseManager.Instance;
        }

        /// <summary>
        /// CREATE - Insert a new player into the database
        /// </summary>
        public Player CreatePlayer(string playerName)
        {
            if (string.IsNullOrWhiteSpace(playerName))
            {
                Debug.LogError("Player name cannot be empty.");
                return null;
            }

            try
            {
                // Check if player already exists
                if (PlayerExists(playerName))
                {
                    Debug.LogWarning($"Player '{playerName}' already exists.");
                    return null;
                }

                // Insert player
                string insertPlayerQuery = @"INSERT INTO Players (PlayerName, CreatedDate, IsActive) 
                                            VALUES (@playerName, @createdDate, 1)";
                
                Dictionary<string, object> playerParams = new Dictionary<string, object>
                {
                    { "@playerName", playerName },
                    { "@createdDate", DateTime.Now }
                };

                int result = dbManager.ExecuteNonQuery(insertPlayerQuery, playerParams);
                
                if (result <= 0)
                {
                    Debug.LogError("Failed to create player.");
                    return null;
                }

                // Get the newly created player ID
                int playerID = GetPlayerIDByName(playerName);
                
                // Create associated PlayerStats record
                CreatePlayerStats(playerID);

                // Retrieve and return the created player
                Player newPlayer = GetPlayerByID(playerID);
                Debug.Log($"Player '{playerName}' created successfully with ID: {playerID}");
                
                return newPlayer;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error creating player: {e.Message}");
                return null;
            }
        }

        /// <summary>
        /// READ - Get player by ID
        /// </summary>
        public Player GetPlayerByID(int playerID)
        {
            try
            {
                string query = "SELECT * FROM Players WHERE PlayerID = @playerID";
                Dictionary<string, object> parameters = new Dictionary<string, object>
                {
                    { "@playerID", playerID }
                };

                IDataReader reader = dbManager.ExecuteReader(query, parameters);
                
                if (reader != null && reader.Read())
                {
                    Player player = new Player
                    {
                        PlayerID = Convert.ToInt32(reader["PlayerID"]),
                        PlayerName = reader["PlayerName"].ToString(),
                        CreatedDate = Convert.ToDateTime(reader["CreatedDate"]),
                        IsActive = Convert.ToInt32(reader["IsActive"]) == 1
                    };

                    if (reader["LastPlayedDate"] != DBNull.Value)
                    {
                        player.LastPlayedDate = Convert.ToDateTime(reader["LastPlayedDate"]);
                    }

                    reader.Close();
                    return player;
                }

                if (reader != null) reader.Close();
                return null;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error retrieving player by ID: {e.Message}");
                return null;
            }
        }

        /// <summary>
        /// READ - Get player by name
        /// </summary>
        public Player GetPlayerByName(string playerName)
        {
            try
            {
                string query = "SELECT * FROM Players WHERE PlayerName = @playerName";
                Dictionary<string, object> parameters = new Dictionary<string, object>
                {
                    { "@playerName", playerName }
                };

                IDataReader reader = dbManager.ExecuteReader(query, parameters);
                
                if (reader != null && reader.Read())
                {
                    Player player = new Player
                    {
                        PlayerID = Convert.ToInt32(reader["PlayerID"]),
                        PlayerName = reader["PlayerName"].ToString(),
                        CreatedDate = Convert.ToDateTime(reader["CreatedDate"]),
                        IsActive = Convert.ToInt32(reader["IsActive"]) == 1
                    };

                    if (reader["LastPlayedDate"] != DBNull.Value)
                    {
                        player.LastPlayedDate = Convert.ToDateTime(reader["LastPlayedDate"]);
                    }

                    reader.Close();
                    return player;
                }

                if (reader != null) reader.Close();
                return null;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error retrieving player by name: {e.Message}");
                return null;
            }
        }

        /// <summary>
        /// READ - Get all active players
        /// </summary>
        public List<Player> GetAllActivePlayers()
        {
            List<Player> players = new List<Player>();

            try
            {
                string query = "SELECT * FROM Players WHERE IsActive = 1 ORDER BY PlayerName ASC";
                IDataReader reader = dbManager.ExecuteReader(query);

                if (reader != null)
                {
                    while (reader.Read())
                    {
                        Player player = new Player
                        {
                            PlayerID = Convert.ToInt32(reader["PlayerID"]),
                            PlayerName = reader["PlayerName"].ToString(),
                            CreatedDate = Convert.ToDateTime(reader["CreatedDate"]),
                            IsActive = Convert.ToInt32(reader["IsActive"]) == 1
                        };

                        if (reader["LastPlayedDate"] != DBNull.Value)
                        {
                            player.LastPlayedDate = Convert.ToDateTime(reader["LastPlayedDate"]);
                        }

                        players.Add(player);
                    }
                    reader.Close();
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"Error retrieving all players: {e.Message}");
            }

            return players;
        }

        /// <summary>
        /// UPDATE - Update player information
        /// </summary>
        public bool UpdatePlayer(Player player)
        {
            if (player == null || player.PlayerID <= 0)
            {
                Debug.LogError("Invalid player object.");
                return false;
            }

            try
            {
                string query = @"UPDATE Players 
                                SET PlayerName = @playerName, 
                                    LastPlayedDate = @lastPlayedDate,
                                    IsActive = @isActive
                                WHERE PlayerID = @playerID";

                Dictionary<string, object> parameters = new Dictionary<string, object>
                {
                    { "@playerName", player.PlayerName },
                    { "@lastPlayedDate", player.LastPlayedDate ?? (object)DBNull.Value },
                    { "@isActive", player.IsActive ? 1 : 0 },
                    { "@playerID", player.PlayerID }
                };

                int result = dbManager.ExecuteNonQuery(query, parameters);
                
                if (result > 0)
                {
                    Debug.Log($"Player '{player.PlayerName}' updated successfully.");
                    return true;
                }
                
                return false;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error updating player: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// UPDATE - Update last played date for a player
        /// </summary>
        public bool UpdateLastPlayedDate(int playerID)
        {
            try
            {
                string query = "UPDATE Players SET LastPlayedDate = @lastPlayedDate WHERE PlayerID = @playerID";
                Dictionary<string, object> parameters = new Dictionary<string, object>
                {
                    { "@lastPlayedDate", DateTime.Now },
                    { "@playerID", playerID }
                };

                int result = dbManager.ExecuteNonQuery(query, parameters);
                return result > 0;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error updating last played date: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// DELETE - Delete a player (soft delete - sets IsActive to 0)
        /// </summary>
        public bool DeletePlayer(int playerID, bool hardDelete = false)
        {
            try
            {
                if (hardDelete)
                {
                    // Hard delete - remove from database completely
                    string query = "DELETE FROM Players WHERE PlayerID = @playerID";
                    Dictionary<string, object> parameters = new Dictionary<string, object>
                    {
                        { "@playerID", playerID }
                    };

                    int result = dbManager.ExecuteNonQuery(query, parameters);
                    
                    if (result > 0)
                    {
                        Debug.Log($"Player with ID {playerID} permanently deleted.");
                        return true;
                    }
                }
                else
                {
                    // Soft delete - just mark as inactive
                    string query = "UPDATE Players SET IsActive = 0 WHERE PlayerID = @playerID";
                    Dictionary<string, object> parameters = new Dictionary<string, object>
                    {
                        { "@playerID", playerID }
                    };

                    int result = dbManager.ExecuteNonQuery(query, parameters);
                    
                    if (result > 0)
                    {
                        Debug.Log($"Player with ID {playerID} deactivated.");
                        return true;
                    }
                }

                return false;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error deleting player: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// Helper - Check if player exists by name
        /// </summary>
        public bool PlayerExists(string playerName)
        {
            try
            {
                string query = "SELECT COUNT(*) FROM Players WHERE PlayerName = @playerName";
                Dictionary<string, object> parameters = new Dictionary<string, object>
                {
                    { "@playerName", playerName }
                };

                object result = dbManager.ExecuteScalar(query, parameters);
                return Convert.ToInt32(result) > 0;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error checking if player exists: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// Helper - Get player ID by name
        /// </summary>
        public int GetPlayerIDByName(string playerName)
        {
            try
            {
                string query = "SELECT PlayerID FROM Players WHERE PlayerName = @playerName LIMIT 1";
                Dictionary<string, object> parameters = new Dictionary<string, object>
                {
                    { "@playerName", playerName }
                };

                object result = dbManager.ExecuteScalar(query, parameters);
                
                if (result != null && result != DBNull.Value)
                {
                    return Convert.ToInt32(result);
                }

                return -1;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error retrieving player ID: {e.Message}");
                return -1;
            }
        }

        /// <summary>
        /// Helper - Get total player count
        /// </summary>
        public int GetTotalPlayerCount(bool activeOnly = true)
        {
            try
            {
                string query = activeOnly ? 
                    "SELECT COUNT(*) FROM Players WHERE IsActive = 1" :
                    "SELECT COUNT(*) FROM Players";

                object result = dbManager.ExecuteScalar(query);
                return Convert.ToInt32(result);
            }
            catch (Exception e)
            {
                Debug.LogError($"Error counting players: {e.Message}");
                return 0;
            }
        }

        /// <summary>
        /// Helper - Create associated PlayerStats when creating a new player
        /// </summary>
        private bool CreatePlayerStats(int playerID)
        {
            try
            {
                string query = @"INSERT INTO PlayerStats (PlayerID, Level, TotalExperience, TotalBattles, 
                                TotalWins, TotalLosses, TotalDraws, LastUpdated) 
                                VALUES (@playerID, 1, 0, 0, 0, 0, 0, @lastUpdated)";

                Dictionary<string, object> parameters = new Dictionary<string, object>
                {
                    { "@playerID", playerID },
                    { "@lastUpdated", DateTime.Now }
                };

                int result = dbManager.ExecuteNonQuery(query, parameters);
                return result > 0;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error creating player stats: {e.Message}");
                return false;
            }
        }
    }
}
