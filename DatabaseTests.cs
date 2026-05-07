// ============================================
// DATABASE TESTING CHECKLIST & UNIT TESTS
// ============================================
// Use this file to validate your database implementation
// Add these test methods to your testing framework

using System;
using System.Collections.Generic;
using UnityEngine;
using BattleFleet.Database;

namespace BattleFleet.Tests
{
    /// <summary>
    /// Database Unit Tests - Comprehensive validation of all database operations
    /// Run these tests to ensure the database system works correctly
    /// </summary>
    public class DatabaseTests : MonoBehaviour
    {
        private PlayerRepository playerRepo;
        private PlayerStatsRepository statsRepo;
        private int testRunCount = 0;
        private int testPassCount = 0;

        public void RunAllTests()
        {
            Debug.Log("\n╔════════════════════════════════════════════════════════╗");
            Debug.Log("║  BATTLE FLEET 2 - DATABASE SYSTEM TEST SUITE          ║");
            Debug.Log("╚════════════════════════════════════════════════════════╝\n");

            // Initialize
            if (!DatabaseManager.Instance.IsInitialized)
            {
                DatabaseManager.Instance.Initialize("BattleFleetGame_Test.db");
            }

            playerRepo = new PlayerRepository();
            statsRepo = new PlayerStatsRepository();

            // Run test categories
            TestPlayerCreation();
            TestPlayerRetrieval();
            TestPlayerUpdates();
            TestPlayerDeletion();
            TestStatisticsManagement();
            TestLevelingSystem();
            TestLeaderboards();
            TestBattleRecording();
            TestErrorHandling();

            // Summary
            PrintTestSummary();
        }

        // ==================== TEST METHODS ====================

        private void TestPlayerCreation()
        {
            Debug.Log("\n[TEST CATEGORY] Player Creation");
            
            // Test 1: Create valid player
            Test("Create Player - Valid", () =>
            {
                Player player = playerRepo.CreatePlayer("TestPlayer_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                return player != null && player.PlayerID > 0;
            });

            // Test 2: Reject duplicate player
            Test("Create Player - Reject Duplicate", () =>
            {
                string testName = "UniqueTestPlayer_" + System.Guid.NewGuid().ToString().Substring(0, 8);
                playerRepo.CreatePlayer(testName);
                Player duplicate = playerRepo.CreatePlayer(testName);
                return duplicate == null;
            });

            // Test 3: Reject empty name
            Test("Create Player - Reject Empty Name", () =>
            {
                Player player = playerRepo.CreatePlayer("");
                return player == null;
            });

            // Test 4: Auto-create stats record
            Test("Create Player - Auto Create Stats", () =>
            {
                Player player = playerRepo.CreatePlayer("StatsTestPlayer_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;
                
                PlayerStats stats = statsRepo.GetPlayerStats(player.PlayerID);
                return stats != null && stats.Level == 1 && stats.TotalExperience == 0;
            });
        }

        private void TestPlayerRetrieval()
        {
            Debug.Log("\n[TEST CATEGORY] Player Retrieval");

            // Test 1: Get player by ID
            Test("Retrieve Player - By ID", () =>
            {
                Player created = playerRepo.CreatePlayer("RetrieveTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (created == null) return false;
                
                Player retrieved = playerRepo.GetPlayerByID(created.PlayerID);
                return retrieved != null && retrieved.PlayerID == created.PlayerID;
            });

            // Test 2: Get player by name
            Test("Retrieve Player - By Name", () =>
            {
                string testName = "NameRetrieveTest_" + System.Guid.NewGuid().ToString().Substring(0, 8);
                Player created = playerRepo.CreatePlayer(testName);
                if (created == null) return false;
                
                Player retrieved = playerRepo.GetPlayerByName(testName);
                return retrieved != null && retrieved.PlayerName == testName;
            });

            // Test 3: Get all active players
            Test("Retrieve Players - Get All Active", () =>
            {
                int countBefore = playerRepo.GetTotalPlayerCount();
                playerRepo.CreatePlayer("ActiveTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                int countAfter = playerRepo.GetTotalPlayerCount();
                return countAfter > countBefore;
            });

            // Test 4: Player not found returns null
            Test("Retrieve Player - Not Found Returns Null", () =>
            {
                Player player = playerRepo.GetPlayerByID(99999);
                return player == null;
            });
        }

        private void TestPlayerUpdates()
        {
            Debug.Log("\n[TEST CATEGORY] Player Updates");

            // Test 1: Update player
            Test("Update Player - Modified Successfully", () =>
            {
                Player player = playerRepo.CreatePlayer("UpdateTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                player.IsActive = false;
                bool updated = playerRepo.UpdatePlayer(player);
                
                Player retrieved = playerRepo.GetPlayerByID(player.PlayerID);
                return updated && !retrieved.IsActive;
            });

            // Test 2: Update last played date
            Test("Update Player - Last Played Date", () =>
            {
                Player player = playerRepo.CreatePlayer("LastPlayedTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                bool updated = playerRepo.UpdateLastPlayedDate(player.PlayerID);
                Player retrieved = playerRepo.GetPlayerByID(player.PlayerID);
                
                return updated && retrieved.LastPlayedDate.HasValue;
            });
        }

        private void TestPlayerDeletion()
        {
            Debug.Log("\n[TEST CATEGORY] Player Deletion");

            // Test 1: Soft delete player
            Test("Delete Player - Soft Delete", () =>
            {
                Player player = playerRepo.CreatePlayer("SoftDeleteTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                bool deleted = playerRepo.DeletePlayer(player.PlayerID, hardDelete: false);
                Player retrieved = playerRepo.GetPlayerByID(player.PlayerID);
                
                return deleted && retrieved != null && !retrieved.IsActive;
            });

            // Test 2: Verify player exists check
            Test("Delete Player - Exist Check After Soft Delete", () =>
            {
                Player player = playerRepo.CreatePlayer("ExistCheckTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                playerRepo.DeletePlayer(player.PlayerID, hardDelete: false);
                return !playerRepo.PlayerExists(player.PlayerName);
            });
        }

        private void TestStatisticsManagement()
        {
            Debug.Log("\n[TEST CATEGORY] Statistics Management");

            // Test 1: Get player stats
            Test("Stats - Retrieve Stats", () =>
            {
                Player player = playerRepo.CreatePlayer("StatsGetTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                PlayerStats stats = statsRepo.GetPlayerStats(player.PlayerID);
                return stats != null && stats.PlayerID == player.PlayerID;
            });

            // Test 2: Add experience
            Test("Stats - Add Experience", () =>
            {
                Player player = playerRepo.CreatePlayer("ExpTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                bool added = statsRepo.AddExperience(player.PlayerID, 500);
                PlayerStats stats = statsRepo.GetPlayerStats(player.PlayerID);
                
                return added && stats.TotalExperience == 500;
            });

            // Test 3: Win rate calculation
            Test("Stats - Win Rate Calculation", () =>
            {
                Player player = playerRepo.CreatePlayer("WinRateTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                PlayerStats stats = statsRepo.GetPlayerStats(player.PlayerID);
                double winRate = stats.GetWinRate();
                
                return winRate == 0.0; // No battles yet
            });

            // Test 4: Update accuracy
            Test("Stats - Update Accuracy", () =>
            {
                Player player = playerRepo.CreatePlayer("AccuracyTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                bool updated = statsRepo.UpdateAccuracy(player.PlayerID, 10, 8); // 80% accuracy
                PlayerStats stats = statsRepo.GetPlayerStats(player.PlayerID);
                
                return updated && stats.AverageAccuracy > 0;
            });

            // Test 5: Update campaign progress
            Test("Stats - Update Campaign Progress", () =>
            {
                Player player = playerRepo.CreatePlayer("CampaignTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                bool updated = statsRepo.UpdateCampaignProgress(player.PlayerID, 50.0);
                PlayerStats stats = statsRepo.GetPlayerStats(player.PlayerID);
                
                return updated && stats.CampaignProgressPercentage == 50.0;
            });
        }

        private void TestLevelingSystem()
        {
            Debug.Log("\n[TEST CATEGORY] Leveling System");

            // Test 1: Level up on experience
            Test("Leveling - Level Up Trigger", () =>
            {
                Player player = playerRepo.CreatePlayer("LevelUpTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                statsRepo.AddExperience(player.PlayerID, 1000);
                PlayerStats stats = statsRepo.GetPlayerStats(player.PlayerID);
                
                return stats.Level == 2;
            });

            // Test 2: Multiple level ups
            Test("Leveling - Multiple Level Ups", () =>
            {
                Player player = playerRepo.CreatePlayer("MultiLevelTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                statsRepo.AddExperience(player.PlayerID, 5000);
                PlayerStats stats = statsRepo.GetPlayerStats(player.PlayerID);
                
                return stats.Level >= 5;
            });

            // Test 3: Remaining XP calculation
            Test("Leveling - Remaining XP Calculation", () =>
            {
                Player player = playerRepo.CreatePlayer("RemainingXpTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                statsRepo.AddExperience(player.PlayerID, 500);
                int remaining = statsRepo.GetRemainingExperienceForLevel(player.PlayerID);
                
                return remaining == 500; // 1000 - 500
            });

            // Test 4: Highest level tracking
            Test("Leveling - Track Highest Level", () =>
            {
                Player player = playerRepo.CreatePlayer("HighestLevelTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                statsRepo.AddExperience(player.PlayerID, 3000);
                PlayerStats stats = statsRepo.GetPlayerStats(player.PlayerID);
                
                return stats.HighestLevel >= stats.Level;
            });
        }

        private void TestLeaderboards()
        {
            Debug.Log("\n[TEST CATEGORY] Leaderboards");

            // Test 1: Top players by level
            Test("Leaderboard - Top by Level", () =>
            {
                List<PlayerStats> topPlayers = statsRepo.GetTopPlayersByLevel(5);
                return topPlayers != null && topPlayers.Count >= 0;
            });

            // Test 2: Player ranking
            Test("Leaderboard - Player Rank", () =>
            {
                Player player = playerRepo.CreatePlayer("RankTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                int rank = statsRepo.GetPlayerRank(player.PlayerID);
                return rank > 0;
            });

            // Test 3: Win rate leaderboard
            Test("Leaderboard - Top by Win Rate", () =>
            {
                List<PlayerStats> topPlayers = statsRepo.GetTopPlayersByWinRate(5);
                return topPlayers != null;
            });
        }

        private void TestBattleRecording()
        {
            Debug.Log("\n[TEST CATEGORY] Battle Recording");

            // Test 1: Record battle result
            Test("Battle - Record Result", () =>
            {
                Player player = playerRepo.CreatePlayer("BattleTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                BattleRecord battle = new BattleRecord
                {
                    OpponentName = "TestOpponent",
                    Result = "Win",
                    ShipsDestroyed = 5,
                    ShipsLost = 2,
                    ExperienceGained = 300
                };

                bool recorded = statsRepo.RecordBattleResult(player.PlayerID, battle);
                PlayerStats stats = statsRepo.GetPlayerStats(player.PlayerID);
                
                return recorded && stats.TotalBattles == 1 && stats.TotalWins == 1;
            });

            // Test 2: Battle stats aggregation
            Test("Battle - Stats Aggregation", () =>
            {
                Player player = playerRepo.CreatePlayer("BattleAggTest_" + System.Guid.NewGuid().ToString().Substring(0, 8));
                if (player == null) return false;

                BattleRecord battle = new BattleRecord
                {
                    Result = "Win",
                    ShipsDestroyed = 3,
                    ShipsLost = 1,
                    ExperienceGained = 200
                };

                statsRepo.RecordBattleResult(player.PlayerID, battle);
                PlayerStats stats = statsRepo.GetPlayerStats(player.PlayerID);
                
                return stats.TotalShipsDestroyed == 3 && stats.TotalShipsLost == 1;
            });
        }

        private void TestErrorHandling()
        {
            Debug.Log("\n[TEST CATEGORY] Error Handling");

            // Test 1: Database not initialized
            Test("Error Handling - Invalid Operations", () =>
            {
                // This should handle gracefully
                PlayerStats stats = statsRepo.GetPlayerStats(-1);
                return stats == null;
            });

            // Test 2: Invalid parameters
            Test("Error Handling - Invalid Parameters", () =>
            {
                bool result = statsRepo.UpdateCampaignProgress(-1, 150.0); // Invalid percentage
                return !result;
            });
        }

        // ==================== TEST UTILITIES ====================

        private void Test(string testName, System.Func<bool> testFunc)
        {
            testRunCount++;
            try
            {
                bool passed = testFunc();
                
                if (passed)
                {
                    testPassCount++;
                    Debug.Log($"  ✓ PASS: {testName}");
                }
                else
                {
                    Debug.Log($"  ✗ FAIL: {testName}");
                }
            }
            catch (System.Exception e)
            {
                Debug.LogError($"  ✗ ERROR: {testName} - {e.Message}");
            }
        }

        private void PrintTestSummary()
        {
            Debug.Log("\n╔════════════════════════════════════════════════════════╗");
            Debug.Log("║  TEST SUMMARY                                          ║");
            Debug.Log("╚════════════════════════════════════════════════════════╝");
            Debug.Log($"Total Tests: {testRunCount}");
            Debug.Log($"Passed: {testPassCount}");
            Debug.Log($"Failed: {testRunCount - testPassCount}");
            Debug.Log($"Success Rate: {(testPassCount / (float)testRunCount * 100):F1}%");
            
            if (testPassCount == testRunCount)
            {
                Debug.Log("\n✓ ALL TESTS PASSED! Database system is ready for integration.");
            }
            else
            {
                Debug.Log($"\n✗ {testRunCount - testPassCount} tests failed. Review the log above.");
            }
        }

        // ── Ship Unlock Tests ──────────────────────────────────────────────────────

        [Test]
        public void ShipUnlock_StarterShipsAvailableAtLevel1()
        {
            var repo     = new ShipUnlockRepository(_db);
            int playerId = CreateTestPlayerAtLevel(1);

            Assert.IsTrue(repo.IsShipUnlocked(playerId, "Sloop"),   "Sloop should be unlocked at level 1");
            Assert.IsTrue(repo.IsShipUnlocked(playerId, "Brig"),    "Brig should be unlocked at level 1");
            Assert.IsFalse(repo.IsShipUnlocked(playerId, "Carrier"),"Carrier should NOT be unlocked at level 1");
        }

        [Test]
        public void ShipUnlock_CarrierUnlocksAtLevel7()
        {
            var repo     = new ShipUnlockRepository(_db);
            int playerId = CreateTestPlayerAtLevel(6);
            Assert.IsFalse(repo.IsShipUnlocked(playerId, "Carrier"), "Carrier locked at level 6");

            SetPlayerLevel(playerId, 7);
            Assert.IsTrue(repo.IsShipUnlocked(playerId, "Carrier"),  "Carrier unlocked at level 7");
        }

        [Test]
        public void Progression_XpAwardIncreasesLevel()
        {
            var statsRepo = new PlayerStatsRepository(_db);
            int playerId  = CreateTestPlayerAtLevel(1);

            // Level 2 requires 100 XP total
            int newLevel = statsRepo.AwardXpAndLevelUp(playerId, 100);
            Assert.AreEqual(2, newLevel, "Should be level 2 after 100 XP");
        }

        // helpers
        private int CreateTestPlayerAtLevel(int level)
        {
            // insert a test player row with fleet_level = level, fleet_xp = 0
            // adapt to your existing player creation method
            throw new System.NotImplementedException("Wire up to your PlayerRepository");
        }

        private void SetPlayerLevel(int playerId, int level)
        {
            using var conn = _db.GetConnection();
            conn.Open();
            using var cmd = conn.CreateCommand();
            cmd.CommandText = "UPDATE players SET fleet_level = @l WHERE id = @id;";
            cmd.Parameters.AddWithValue("@l",  level);
            cmd.Parameters.AddWithValue("@id", playerId);
            cmd.ExecuteNonQuery();
        }
    }

    // ==================== MANUAL TESTING CHECKLIST ====================
    /*
    
    MANUAL TEST CHECKLIST - Run these manually in the editor:
    
    ✓ DATABASE INITIALIZATION
      □ Create new database file on first run
      □ Tables created successfully
      □ Database persists between game sessions
      □ Connection closes properly on app exit
    
    ✓ PLAYER MANAGEMENT
      □ Create new player successfully
      □ Player name appears in UI player select
      □ Cannot create duplicate player names
      □ View all players in list
      □ Delete player (soft delete)
      □ Update player name
    
    ✓ STATISTICS TRACKING
      □ Player starts at Level 1, 0 XP
      □ Battle victory adds experience
      □ Battle defeat adds experience
      □ Level increases at 1000 XP thresholds
      □ Win/Loss/Draw counts update correctly
      □ Win rate displayed correctly
    
    ✓ LEVELING SYSTEM
      □ Gain 1000 XP → Level 2
      □ Gain 2000 XP more → Level 3
      □ Highest level tracked separately
      □ Remaining XP to next level calculated
    
    ✓ LEADERBOARDS
      □ Top 10 players by level displays
      □ Leaderboard updates after battle
      □ Player rank shown in profile
      □ Win rate leaderboard works
    
    ✓ BATTLE RECORDING
      □ Battle result saved after match
      □ Ships destroyed/lost counted
      □ Experience reward applied
      □ Battle history accessible
    
    ✓ ERROR HANDLING
      □ Game doesn't crash on database error
      □ Error messages logged to console
      □ Invalid operations handled gracefully
    
    */
}
