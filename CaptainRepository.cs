using System;
using System.Collections.Generic;
using System.Data;
using UnityEngine;

namespace BattleFleet.Database
{
    /// <summary>
    /// CaptainRepository - handles captain CRUD, XP progression, command card unlocking,
    /// and accuracy bonus calculation.
    /// </summary>
    public class CaptainRepository
    {
        private DatabaseManager dbManager;

        private const int    XP_VICTORY             = 150;
        private const int    XP_DEFEAT              = 50;
        private const int    XP_DRAW                = 75;
        private const int    XP_PER_SHIP_DESTROYED  = 25;
        // Accuracy bonus gained per captain level above 1 (in percentage points)
        private const double ACCURACY_BONUS_PER_LEVEL = 2.0;

        public CaptainRepository()
        {
            dbManager = DatabaseManager.Instance;
        }

        // ── READ ────────────────────────────────────────────────────────────────────

        public Captain GetCaptain(int captainId)
        {
            try
            {
                string query = "SELECT * FROM Captains WHERE CaptainID = @captainId";
                var parameters = new Dictionary<string, object> { { "@captainId", captainId } };
                IDataReader reader = dbManager.ExecuteReader(query, parameters);

                if (reader != null && reader.Read())
                {
                    Captain captain = MapCaptain(reader);
                    reader.Close();
                    return captain;
                }

                if (reader != null) reader.Close();
                return null;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error retrieving captain {captainId}: {e.Message}");
                return null;
            }
        }

        public List<Captain> GetCaptainsByPlayer(int playerId)
        {
            var captains = new List<Captain>();
            try
            {
                string query = "SELECT * FROM Captains WHERE PlayerID = @playerId AND IsAvailable = 1";
                var parameters = new Dictionary<string, object> { { "@playerId", playerId } };
                IDataReader reader = dbManager.ExecuteReader(query, parameters);

                if (reader != null)
                {
                    while (reader.Read())
                        captains.Add(MapCaptain(reader));
                    reader.Close();
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"Error retrieving captains for player {playerId}: {e.Message}");
            }

            return captains;
        }

        // ── CREATE ──────────────────────────────────────────────────────────────────

        /// <summary>
        /// Creates a new captain and automatically unlocks Level 1 command cards.
        /// Returns the new CaptainID, or -1 on failure.
        /// </summary>
        public int CreateCaptain(Captain captain)
        {
            try
            {
                string query = @"INSERT INTO Captains
                                     (PlayerID, CaptainName, ExperiencePoints, Level,
                                      SpecializationClass, BattlesParticipated, CreatedDate, IsAvailable, AccuracyBonus)
                                 VALUES
                                     (@playerId, @name, 0, 1, @spec, 0, @createdDate, 1, 0.0)";

                var parameters = new Dictionary<string, object>
                {
                    { "@playerId",    captain.PlayerID },
                    { "@name",        captain.CaptainName },
                    { "@spec",        captain.SpecializationClass },
                    { "@createdDate", DateTime.Now }
                };

                dbManager.ExecuteNonQuery(query, parameters);

                int captainId = Convert.ToInt32(dbManager.ExecuteScalar("SELECT last_insert_rowid()"));

                // Every new captain starts with Level 1 command cards unlocked
                UnlockEligibleCommandCards(captainId, 1);

                Debug.Log($"Captain '{captain.CaptainName}' created (ID: {captainId}).");
                return captainId;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error creating captain: {e.Message}");
                return -1;
            }
        }

        // ── XP & LEVELLING ──────────────────────────────────────────────────────────

        /// <summary>
        /// Awards XP to a captain after a battle, handles level-up, command card unlocks,
        /// and accuracy bonus update. Returns the captain's new level.
        /// XP awarded: Win=150, Loss=50, Draw=75, +25 per ship destroyed.
        /// </summary>
        public int AwardBattleXp(int captainId, BattleRecord battle)
        {
            try
            {
                Captain captain = GetCaptain(captainId);
                if (captain == null)
                {
                    Debug.LogError($"Captain {captainId} not found.");
                    return -1;
                }

                int xpGained     = CalculateBattleXp(battle);
                int previousLevel = captain.Level;

                captain.ExperiencePoints  += xpGained;
                captain.Level              = CalculateCaptainLevel(captain.ExperiencePoints);
                captain.BattlesParticipated++;
                // Accuracy bonus grows by ACCURACY_BONUS_PER_LEVEL for each level above 1
                captain.AccuracyBonus = (captain.Level - 1) * ACCURACY_BONUS_PER_LEVEL;

                UpdateCaptain(captain);

                if (captain.Level > previousLevel)
                {
                    Debug.Log($"Captain '{captain.CaptainName}' leveled up! {previousLevel} → {captain.Level}. New accuracy bonus: +{captain.AccuracyBonus:F1}%");
                    UnlockEligibleCommandCards(captainId, captain.Level);
                }
                else
                {
                    Debug.Log($"Captain '{captain.CaptainName}' gained {xpGained} XP (total: {captain.ExperiencePoints}). Accuracy bonus: +{captain.AccuracyBonus:F1}%");
                }

                return captain.Level;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error awarding XP to captain {captainId}: {e.Message}");
                return -1;
            }
        }

        // ── ACCURACY ────────────────────────────────────────────────────────────────

        /// <summary>
        /// Returns the current accuracy bonus (percentage points) for a captain.
        /// Formula: (captainLevel - 1) * 2.0%
        /// </summary>
        public double GetCaptainAccuracyBonus(int captainId)
        {
            Captain captain = GetCaptain(captainId);
            return captain?.AccuracyBonus ?? 0.0;
        }

        // ── COMMAND CARDS ───────────────────────────────────────────────────────────

        /// <summary>Returns all command card definitions ordered by required level.</summary>
        public List<CommandCard> GetAllCommandCards()
        {
            var cards = new List<CommandCard>();
            try
            {
                IDataReader reader = dbManager.ExecuteReader(
                    "SELECT * FROM CommandCards ORDER BY RequiredCaptainLevel ASC");

                if (reader != null)
                {
                    while (reader.Read())
                        cards.Add(MapCommandCard(reader));
                    reader.Close();
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"Error retrieving command cards: {e.Message}");
            }
            return cards;
        }

        /// <summary>Returns command cards the captain has already unlocked.</summary>
        public List<CommandCard> GetUnlockedCommandCards(int captainId)
        {
            var cards = new List<CommandCard>();
            try
            {
                string query = @"SELECT cc.*
                                 FROM CommandCards cc
                                 INNER JOIN CaptainCommandCards ccc ON cc.CardID = ccc.CardID
                                 WHERE ccc.CaptainID = @captainId
                                 ORDER BY cc.RequiredCaptainLevel ASC";

                var parameters = new Dictionary<string, object> { { "@captainId", captainId } };
                IDataReader reader = dbManager.ExecuteReader(query, parameters);

                if (reader != null)
                {
                    while (reader.Read())
                        cards.Add(MapCommandCard(reader));
                    reader.Close();
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"Error retrieving unlocked command cards for captain {captainId}: {e.Message}");
            }
            return cards;
        }

        // ── HELPERS ─────────────────────────────────────────────────────────────────

        private int CalculateBattleXp(BattleRecord battle)
        {
            int xp;
            if      (battle.Result == "Win")  xp = XP_VICTORY;
            else if (battle.Result == "Loss") xp = XP_DEFEAT;
            else                              xp = XP_DRAW;

            xp += battle.ShipsDestroyed * XP_PER_SHIP_DESTROYED;
            return xp;
        }

        /// <summary>
        /// Quadratic XP curve: each level costs level*100 XP.
        /// Level 1=0 XP, Level 2=100, Level 3=300, Level 4=600 …
        /// Mirrors PlayerStatsRepository.CalculateLevel.
        /// </summary>
        public static int CalculateCaptainLevel(int totalXp)
        {
            int level    = 1;
            int xpNeeded = 0;
            while (totalXp >= xpNeeded + (level * 100))
            {
                xpNeeded += level * 100;
                level++;
            }
            return level;
        }

        /// <summary>
        /// Inserts all command cards whose required level <= captainLevel
        /// that the captain hasn't unlocked yet (INSERT OR IGNORE handles duplicates).
        /// </summary>
        private void UnlockEligibleCommandCards(int captainId, int captainLevel)
        {
            try
            {
                string query = @"INSERT OR IGNORE INTO CaptainCommandCards (CaptainID, CardID, UnlockedDate)
                                 SELECT @captainId, CardID, @now
                                 FROM CommandCards
                                 WHERE RequiredCaptainLevel <= @level";

                var parameters = new Dictionary<string, object>
                {
                    { "@captainId", captainId },
                    { "@level",     captainLevel },
                    { "@now",       DateTime.Now }
                };

                dbManager.ExecuteNonQuery(query, parameters);
            }
            catch (Exception e)
            {
                Debug.LogError($"Error unlocking command cards for captain {captainId}: {e.Message}");
            }
        }

        private bool UpdateCaptain(Captain captain)
        {
            try
            {
                string query = @"UPDATE Captains
                                 SET ExperiencePoints    = @xp,
                                     Level               = @level,
                                     BattlesParticipated = @battles,
                                     AccuracyBonus       = @accuracyBonus
                                 WHERE CaptainID = @captainId";

                var parameters = new Dictionary<string, object>
                {
                    { "@xp",           captain.ExperiencePoints },
                    { "@level",        captain.Level },
                    { "@battles",      captain.BattlesParticipated },
                    { "@accuracyBonus", captain.AccuracyBonus },
                    { "@captainId",    captain.CaptainID }
                };

                return dbManager.ExecuteNonQuery(query, parameters) > 0;
            }
            catch (Exception e)
            {
                Debug.LogError($"Error updating captain {captain.CaptainID}: {e.Message}");
                return false;
            }
        }

        private Captain MapCaptain(IDataReader reader)
        {
            return new Captain
            {
                CaptainID           = Convert.ToInt32(reader["CaptainID"]),
                PlayerID            = Convert.ToInt32(reader["PlayerID"]),
                CaptainName         = reader["CaptainName"].ToString(),
                ExperiencePoints    = Convert.ToInt32(reader["ExperiencePoints"]),
                Level               = Convert.ToInt32(reader["Level"]),
                SpecializationClass = reader["SpecializationClass"].ToString(),
                BattlesParticipated = Convert.ToInt32(reader["BattlesParticipated"]),
                CreatedDate         = Convert.ToDateTime(reader["CreatedDate"]),
                IsAvailable         = Convert.ToBoolean(reader["IsAvailable"]),
                AccuracyBonus       = Convert.ToDouble(reader["AccuracyBonus"])
            };
        }

        private CommandCard MapCommandCard(IDataReader reader)
        {
            return new CommandCard
            {
                CardID               = Convert.ToInt32(reader["CardID"]),
                CardName             = reader["CardName"].ToString(),
                Description          = reader["Description"].ToString(),
                RequiredCaptainLevel = Convert.ToInt32(reader["RequiredCaptainLevel"]),
                AccuracyBonus        = Convert.ToDouble(reader["AccuracyBonus"]),
                CardType             = reader["CardType"].ToString()
            };
        }
    }
}
