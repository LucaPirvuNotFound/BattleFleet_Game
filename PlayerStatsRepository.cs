using System;
using System.Collections.Generic;
using System.Data;
using UnityEngine;

namespace BattleFleet.Database
{
    /// <summary>
    /// PlayerStats Repository - CRUD and utility operations for PlayerStats table
    /// Handles all player statistics and progression management
    /// </summary>
    public class PlayerStatsRepository
    {
        private DatabaseManager dbManager;

        public PlayerStatsRepository()
        {
            dbManager = DatabaseManager.Instance;
        }

        /// <summary>
        /// READ - Get stats for a specific player
        /// </summary>
        public PlayerStats GetPlayerStats(int playerID)
        {
            try
            {
                string query = "SELECT * FROM PlayerStats WHERE PlayerID = @playerID";
                Dictionary<string, object> parameters = new Dictionary<string, object>
                {
                    { "@playerID", playerID }
                };

                IDataReader reader = dbManager.ExecuteReader(query, parameters);
                
                if (reader != null && reader.Read())
                {
                    PlayerStats stats = new PlayerStats
                    {
                        StatID = Convert.ToInt32(reader["StatID"]),
                        PlayerID = Convert.ToInt32(reader["PlayerID"]),
                        Level = Convert.ToInt32(reader["Level"]),
                        TotalExperience = Convert.ToInt32(reader["TotalExperience"]),
                        TotalBattles = Convert.ToInt32(reader["TotalBattles"]),
                        TotalWins = Convert.ToInt32(reader["TotalWins"]),
                        TotalLosses = Convert.ToInt32(reader["TotalLosses"]),
                        TotalDraws = Convert.ToInt32(reader["TotalDraws"]),
                        AverageAccuracy = Convert.ToDouble(reader["AverageAccuracy"]),
                        TotalShipsDestroyed = Convert.ToInt32(reader["TotalShipsDestroyed"]),
                        TotalShipsLost = Convert.ToInt32(reader["TotalShipsLost"]),
                        CampaignProgressPercentage = Convert.ToDouble(reader["CampaignProgressPercentage"]),
                        HighestLevel = Convert.ToInt32(reader["HighestLevel"]),
                        LastUpdated = Convert.ToDateTime(reader["LastUpdated"])
                    };

                    reader.Close();
                    return stats;
                }

                if (reader != null) reader.Close();
                return null;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error retrieving player stats: {e.Message}");
                return null;
            }
        }

        /// <summary>
        /// UPDATE - Add experience to player
        /// Handles level-up logic automatically
        /// </summary>
        public bool AddExperience(int playerID, int experiencePoints)
        {
            try
            {
                PlayerStats stats = GetPlayerStats(playerID);
                if (stats == null)
                {
                    Debug.LogError($"Player stats not found for player {playerID}");
                    return false;
                }

                stats.TotalExperience += experiencePoints;

                // Level up logic: 1000 XP per level
                int previousLevel = stats.Level;
                int experiencePerLevel = 1000;
                stats.Level = (stats.TotalExperience / experiencePerLevel) + 1;

                // Track highest level reached
                if (stats.Level > stats.HighestLevel)
                {
                    stats.HighestLevel = stats.Level;
                }

                // If leveled up, log it
                if (stats.Level > previousLevel)
                {
                    Debug.Log($"Player {playerID} leveled up! Level: {previousLevel} → {stats.Level}");
                }

                return UpdatePlayerStats(stats);
            }
            catch (Exception e)
            {
                Debug.LogError($"Error adding experience: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// UPDATE - Record a battle result and update stats accordingly
        /// </summary>
        public bool RecordBattleResult(int playerID, BattleRecord battle)
        {
            try
            {
                PlayerStats stats = GetPlayerStats(playerID);
                if (stats == null)
                {
                    Debug.LogError($"Player stats not found for player {playerID}");
                    return false;
                }

                // Update battle records
                stats.TotalBattles++;

                if (battle.Result == "Win")
                {
                    stats.TotalWins++;
                }
                else if (battle.Result == "Loss")
                {
                    stats.TotalLosses++;
                }
                else if (battle.Result == "Draw")
                {
                    stats.TotalDraws++;
                }

                // Update ship statistics
                stats.TotalShipsDestroyed += battle.ShipsDestroyed;
                stats.TotalShipsLost += battle.ShipsLost;

                // Add experience gained from battle
                stats.TotalExperience += battle.ExperienceGained;

                // Recalculate level
                int experiencePerLevel = 1000;
                int previousLevel = stats.Level;
                stats.Level = (stats.TotalExperience / experiencePerLevel) + 1;

                if (stats.Level > stats.HighestLevel)
                {
                    stats.HighestLevel = stats.Level;
                }

                if (stats.Level > previousLevel)
                {
                    Debug.Log($"Player {playerID} leveled up! Level: {previousLevel} → {stats.Level}");
                }

                // Update last modified time
                stats.LastUpdated = DateTime.Now;

                return UpdatePlayerStats(stats);
            }
            catch (Exception e)
            {
                Debug.LogError($"Error recording battle result: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// UPDATE - Update accuracy statistics
        /// </summary>
        public bool UpdateAccuracy(int playerID, int totalShots, int successfulShots)
        {
            try
            {
                if (totalShots <= 0)
                {
                    Debug.LogWarning("Total shots must be greater than 0");
                    return false;
                }

                PlayerStats stats = GetPlayerStats(playerID);
                if (stats == null)
                {
                    Debug.LogError($"Player stats not found for player {playerID}");
                    return false;
                }

                // Calculate cumulative accuracy
                double currentAccuracyBase = stats.AverageAccuracy * (stats.TotalBattles - 1);
                double newAccuracy = successfulShots / (double)totalShots;
                stats.AverageAccuracy = (currentAccuracyBase + newAccuracy) / stats.TotalBattles;

                return UpdatePlayerStats(stats);
            }
            catch (Exception e)
            {
                Debug.LogError($"Error updating accuracy: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// UPDATE - Update campaign progress
        /// </summary>
        public bool UpdateCampaignProgress(int playerID, double progressPercentage)
        {
            try
            {
                if (progressPercentage < 0 || progressPercentage > 100)
                {
                    Debug.LogWarning("Progress percentage must be between 0 and 100");
                    return false;
                }

                PlayerStats stats = GetPlayerStats(playerID);
                if (stats == null)
                {
                    Debug.LogError($"Player stats not found for player {playerID}");
                    return false;
                }

                stats.CampaignProgressPercentage = progressPercentage;
                return UpdatePlayerStats(stats);
            }
            catch (Exception e)
            {
                Debug.LogError($"Error updating campaign progress: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// UPDATE - Update all player stats
        /// </summary>
        private bool UpdatePlayerStats(PlayerStats stats)
        {
            try
            {
                string query = @"UPDATE PlayerStats 
                                SET Level = @level,
                                    TotalExperience = @totalExp,
                                    TotalBattles = @totalBattles,
                                    TotalWins = @totalWins,
                                    TotalLosses = @totalLosses,
                                    TotalDraws = @totalDraws,
                                    AverageAccuracy = @avgAccuracy,
                                    TotalShipsDestroyed = @shipsDestroyed,
                                    TotalShipsLost = @shipsLost,
                                    CampaignProgressPercentage = @campaignProgress,
                                    HighestLevel = @highestLevel,
                                    LastUpdated = @lastUpdated
                                WHERE PlayerID = @playerID";

                Dictionary<string, object> parameters = new Dictionary<string, object>
                {
                    { "@level", stats.Level },
                    { "@totalExp", stats.TotalExperience },
                    { "@totalBattles", stats.TotalBattles },
                    { "@totalWins", stats.TotalWins },
                    { "@totalLosses", stats.TotalLosses },
                    { "@totalDraws", stats.TotalDraws },
                    { "@avgAccuracy", stats.AverageAccuracy },
                    { "@shipsDestroyed", stats.TotalShipsDestroyed },
                    { "@shipsLost", stats.TotalShipsLost },
                    { "@campaignProgress", stats.CampaignProgressPercentage },
                    { "@highestLevel", stats.HighestLevel },
                    { "@lastUpdated", DateTime.Now },
                    { "@playerID", stats.PlayerID }
                };

                int result = dbManager.ExecuteNonQuery(query, parameters);
                return result > 0;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error updating player stats: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// READ - Get top N players by level
        /// </summary>
        public List<PlayerStats> GetTopPlayersByLevel(int topCount = 10)
        {
            List<PlayerStats> topPlayers = new List<PlayerStats>();

            try
            {
                string query = $"SELECT * FROM PlayerStats ORDER BY Level DESC, TotalExperience DESC LIMIT {topCount}";
                IDataReader reader = dbManager.ExecuteReader(query);

                if (reader != null)
                {
                    while (reader.Read())
                    {
                        PlayerStats stats = new PlayerStats
                        {
                            StatID = Convert.ToInt32(reader["StatID"]),
                            PlayerID = Convert.ToInt32(reader["PlayerID"]),
                            Level = Convert.ToInt32(reader["Level"]),
                            TotalExperience = Convert.ToInt32(reader["TotalExperience"]),
                            TotalBattles = Convert.ToInt32(reader["TotalBattles"]),
                            TotalWins = Convert.ToInt32(reader["TotalWins"]),
                            TotalLosses = Convert.ToInt32(reader["TotalLosses"]),
                            TotalDraws = Convert.ToInt32(reader["TotalDraws"]),
                            AverageAccuracy = Convert.ToDouble(reader["AverageAccuracy"]),
                            TotalShipsDestroyed = Convert.ToInt32(reader["TotalShipsDestroyed"]),
                            TotalShipsLost = Convert.ToInt32(reader["TotalShipsLost"]),
                            HighestLevel = Convert.ToInt32(reader["HighestLevel"])
                        };
                        topPlayers.Add(stats);
                    }
                    reader.Close();
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"Error retrieving top players: {e.Message}");
            }

            return topPlayers;
        }

        /// <summary>
        /// READ - Get top N players by win rate
        /// </summary>
        public List<PlayerStats> GetTopPlayersByWinRate(int topCount = 10)
        {
            List<PlayerStats> topPlayers = new List<PlayerStats>();

            try
            {
                string query = $@"SELECT * FROM PlayerStats 
                                WHERE TotalBattles > 0 
                                ORDER BY (CAST(TotalWins AS FLOAT) / TotalBattles) DESC, TotalBattles DESC 
                                LIMIT {topCount}";
                
                IDataReader reader = dbManager.ExecuteReader(query);

                if (reader != null)
                {
                    while (reader.Read())
                    {
                        PlayerStats stats = new PlayerStats
                        {
                            StatID = Convert.ToInt32(reader["StatID"]),
                            PlayerID = Convert.ToInt32(reader["PlayerID"]),
                            Level = Convert.ToInt32(reader["Level"]),
                            TotalExperience = Convert.ToInt32(reader["TotalExperience"]),
                            TotalBattles = Convert.ToInt32(reader["TotalBattles"]),
                            TotalWins = Convert.ToInt32(reader["TotalWins"]),
                            TotalLosses = Convert.ToInt32(reader["TotalLosses"]),
                            TotalDraws = Convert.ToInt32(reader["TotalDraws"]),
                            AverageAccuracy = Convert.ToDouble(reader["AverageAccuracy"]),
                            TotalShipsDestroyed = Convert.ToInt32(reader["TotalShipsDestroyed"]),
                            TotalShipsLost = Convert.ToInt32(reader["TotalShipsLost"]),
                            HighestLevel = Convert.ToInt32(reader["HighestLevel"])
                        };
                        topPlayers.Add(stats);
                    }
                    reader.Close();
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"Error retrieving top players by win rate: {e.Message}");
            }

            return topPlayers;
        }

        /// <summary>
        /// READ - Get player rank by level
        /// </summary>
        public int GetPlayerRank(int playerID, bool byWinRate = false)
        {
            try
            {
                string query;
                if (byWinRate)
                {
                    query = $@"SELECT COUNT(*) FROM PlayerStats 
                            WHERE (CAST(TotalWins AS FLOAT) / NULLIF(TotalBattles, 0)) > 
                                  (SELECT CAST(TotalWins AS FLOAT) / NULLIF(TotalBattles, 0) FROM PlayerStats WHERE PlayerID = @playerID)";
                }
                else
                {
                    query = $@"SELECT COUNT(*) FROM PlayerStats 
                            WHERE Level > (SELECT Level FROM PlayerStats WHERE PlayerID = @playerID)
                            OR (Level = (SELECT Level FROM PlayerStats WHERE PlayerID = @playerID) 
                                AND TotalExperience > (SELECT TotalExperience FROM PlayerStats WHERE PlayerID = @playerID))";
                }

                Dictionary<string, object> parameters = new Dictionary<string, object>
                {
                    { "@playerID", playerID }
                };

                object result = dbManager.ExecuteScalar(query, parameters);
                return Convert.ToInt32(result) + 1; // +1 because rank is 1-indexed
            }
            catch (Exception e)
            {
                Debug.LogError($"Error getting player rank: {e.Message}");
                return -1;
            }
        }

        /// <summary>
        /// READ - Get experience required for next level
        /// </summary>
        public int GetExperienceForNextLevel(int currentLevel)
        {
            int experiencePerLevel = 1000;
            return (currentLevel) * experiencePerLevel;
        }

        /// <summary>
        /// READ - Calculate remaining experience to next level
        /// </summary>
        public int GetRemainingExperienceForLevel(int playerID)
        {
            try
            {
                PlayerStats stats = GetPlayerStats(playerID);
                if (stats == null) return 0;

                int nextLevelXP = GetExperienceForNextLevel(stats.Level);
                int remaining = nextLevelXP - stats.TotalExperience;
                
                return remaining > 0 ? remaining : 0;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error calculating remaining experience: {e.Message}");
                return 0;
            }
        }

        /// <summary>
        /// RESET - Reset all stats for a player (admin/debug use)
        /// </summary>
        public bool ResetPlayerStats(int playerID)
        {
            try
            {
                string query = @"UPDATE PlayerStats 
                                SET Level = 1,
                                    TotalExperience = 0,
                                    TotalBattles = 0,
                                    TotalWins = 0,
                                    TotalLosses = 0,
                                    TotalDraws = 0,
                                    AverageAccuracy = 0.0,
                                    TotalShipsDestroyed = 0,
                                    TotalShipsLost = 0,
                                    CampaignProgressPercentage = 0.0,
                                    LastUpdated = @lastUpdated
                                WHERE PlayerID = @playerID";

                Dictionary<string, object> parameters = new Dictionary<string, object>
                {
                    { "@playerID", playerID },
                    { "@lastUpdated", DateTime.Now }
                };

                int result = dbManager.ExecuteNonQuery(query, parameters);
                
                if (result > 0)
                {
                    Debug.Log($"Player {playerID} stats reset to default.");
                    return true;
                }

                return false;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error resetting player stats: {e.Message}");
                return false;
            }
        }

        // ── XP & Levelling ─────────────────────────────────────────────────────────
        /// <summary>
        /// Awards XP to a player after a match and handles level-up automatically.
        /// Call this at the end of every game.
        /// Returns the new level (useful to trigger a level-up animation in Unity).
        /// </summary>
        public int AwardXpAndLevelUp(int playerId, int xpGained)
        {
            using var conn = _db.GetConnection();
            conn.Open();

            // 1. Read current state
            using var selectCmd = conn.CreateCommand();
            selectCmd.CommandText = "SELECT fleet_level, fleet_xp FROM players WHERE id = @id;";
            selectCmd.Parameters.AddWithValue("@id", playerId);

            int currentLevel, currentXp;
            using (var reader = selectCmd.ExecuteReader())
            {
                reader.Read();
                currentLevel = reader.GetInt32(0);
                currentXp    = reader.GetInt32(1);
            }

            // 2. Calculate new XP and level
            int newXp    = currentXp + xpGained;
            int newLevel = CalculateLevel(newXp);     // see formula below

            // 3. Persist
            using var updateCmd = conn.CreateCommand();
            updateCmd.CommandText = @"
                UPDATE players
                SET fleet_xp    = @xp,
                    fleet_level = @level
                WHERE id = @id;";
            updateCmd.Parameters.AddWithValue("@xp",    newXp);
            updateCmd.Parameters.AddWithValue("@level",  newLevel);
            updateCmd.Parameters.AddWithValue("@id",     playerId);
            updateCmd.ExecuteNonQuery();

            return newLevel;
        }

        /// <summary>
        /// XP formula: each level requires 100 * level XP on top of the previous.
        /// Level 1 = 0 XP, Level 2 = 100, Level 3 = 300, Level 4 = 600 …
        /// Easy to swap out for any curve you like.
        /// </summary>
        public static int CalculateLevel(int totalXp)
        {
            int level = 1;
            int xpNeeded = 0;
            while (totalXp >= xpNeeded + (level * 100))
            {
                xpNeeded += level * 100;
                level++;
            }
            return level;
        }

        /// <summary>Returns XP needed to reach the next level (for the progress bar).</summary>
        public (int currentXp, int xpForCurrentLevel, int xpForNextLevel) GetProgressBarData(int playerId)
        {
            using var conn = _db.GetConnection();
            conn.Open();

            using var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT fleet_xp, fleet_level FROM players WHERE id = @id;";
            cmd.Parameters.AddWithValue("@id", playerId);

            using var reader = cmd.ExecuteReader();
            reader.Read();
            int totalXp = reader.GetInt32(0);
            int level   = reader.GetInt32(1);

            // XP thresholds for current level band
            int xpStart = 0;
            for (int l = 1; l < level; l++) xpStart += l * 100;
            int xpEnd = xpStart + level * 100;

            return (totalXp, xpStart, xpEnd);
        }
    }
}
