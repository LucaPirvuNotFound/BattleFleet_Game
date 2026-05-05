using System;
using System.Collections.Generic;
using UnityEngine;
using BattleFleet.Database;

namespace BattleFleet.Examples
{
    /// <summary>
    /// Example usage of the Database system
    /// This demonstrates how to use all the database components together
    /// 
    /// Copy this script to your Unity project and adapt as needed
    /// </summary>
    public class DatabaseUsageExample : MonoBehaviour
    {
        private PlayerRepository playerRepo;
        private PlayerStatsRepository statsRepo;

        private void Start()
        {
            // Step 1: Initialize the database
            Debug.Log("=== Initializing Database ===");
            DatabaseManager.Instance.Initialize("BattleFleetGame.db");

            if (!DatabaseManager.Instance.IsInitialized)
            {
                Debug.LogError("Database failed to initialize!");
                return;
            }

            Debug.Log("Database initialized successfully!");

            // Step 2: Create repositories
            playerRepo = new PlayerRepository();
            statsRepo = new PlayerStatsRepository();

            // Run examples
            ExampleCreatePlayer();
            ExampleRetrievePlayer();
            ExampleUpdatePlayer();
            ExamplePlayerStatistics();
            ExampleLeaderboards();
            ExampleBattleSimulation();
        }

        /// <summary>
        /// Example 1: Create a new player
        /// </summary>
        private void ExampleCreatePlayer()
        {
            Debug.Log("\n=== EXAMPLE 1: Creating Players ===");

            // Create a new player
            Player player1 = playerRepo.CreatePlayer("CommanderAlex");
            if (player1 != null)
            {
                Debug.Log($"✓ Created player: {player1}");
            }

            // Try to create duplicate (should fail)
            Player duplicate = playerRepo.CreatePlayer("CommanderAlex");
            if (duplicate == null)
            {
                Debug.Log("✓ Correctly rejected duplicate player name");
            }

            // Create more players
            Player player2 = playerRepo.CreatePlayer("CaptainBlue");
            Player player3 = playerRepo.CreatePlayer("AdmiralRed");

            Debug.Log($"Total players created: {playerRepo.GetTotalPlayerCount()}");
        }

        /// <summary>
        /// Example 2: Retrieve player information
        /// </summary>
        private void ExampleRetrievePlayer()
        {
            Debug.Log("\n=== EXAMPLE 2: Retrieving Players ===");

            // Get player by name
            Player player = playerRepo.GetPlayerByName("CommanderAlex");
            if (player != null)
            {
                Debug.Log($"✓ Retrieved by name: {player.PlayerName} (ID: {player.PlayerID})");
            }

            // Get player by ID
            Player playerByID = playerRepo.GetPlayerByID(1);
            if (playerByID != null)
            {
                Debug.Log($"✓ Retrieved by ID: {playerByID.PlayerName}");
            }

            // Get all players
            List<Player> allPlayers = playerRepo.GetAllActivePlayers();
            Debug.Log($"✓ All active players: {allPlayers.Count}");
            foreach (Player p in allPlayers)
            {
                Debug.Log($"  - {p.PlayerName} (Created: {p.CreatedDate:yyyy-MM-dd})");
            }
        }

        /// <summary>
        /// Example 3: Update player information
        /// </summary>
        private void ExampleUpdatePlayer()
        {
            Debug.Log("\n=== EXAMPLE 3: Updating Players ===");

            Player player = playerRepo.GetPlayerByName("CommanderAlex");
            if (player != null)
            {
                // Update last played date
                bool updated = playerRepo.UpdateLastPlayedDate(player.PlayerID);
                Debug.Log($"✓ Updated last played date: {updated}");

                // Retrieve updated player
                Player updatedPlayer = playerRepo.GetPlayerByName("CommanderAlex");
                Debug.Log($"✓ Last played: {updatedPlayer.LastPlayedDate:yyyy-MM-dd HH:mm:ss}");
            }
        }

        /// <summary>
        /// Example 4: Work with player statistics and leveling
        /// </summary>
        private void ExamplePlayerStatistics()
        {
            Debug.Log("\n=== EXAMPLE 4: Player Statistics & Leveling ===");

            Player player = playerRepo.GetPlayerByName("CommanderAlex");
            if (player != null)
            {
                // Get player stats
                PlayerStats stats = statsRepo.GetPlayerStats(player.PlayerID);
                Debug.Log($"✓ Initial stats: {stats}");
                Debug.Log($"  Current level: {stats.Level}");
                Debug.Log($"  Experience: {stats.TotalExperience}/1000");

                // Add experience
                Debug.Log("\n  Adding 500 experience...");
                statsRepo.AddExperience(player.PlayerID, 500);

                stats = statsRepo.GetPlayerStats(player.PlayerID);
                Debug.Log($"  Updated - Exp: {stats.TotalExperience}, Level: {stats.Level}");

                // Add more experience to trigger level up
                Debug.Log("\n  Adding 750 more experience (should level up)...");
                statsRepo.AddExperience(player.PlayerID, 750);

                stats = statsRepo.GetPlayerStats(player.PlayerID);
                Debug.Log($"✓ After level up - Level: {stats.Level}, Exp: {stats.TotalExperience}");

                // Get remaining XP for next level
                int remainingXP = statsRepo.GetRemainingExperienceForLevel(player.PlayerID);
                Debug.Log($"  Remaining XP for next level: {remainingXP}");

                // Get player rank
                int rank = statsRepo.GetPlayerRank(player.PlayerID);
                Debug.Log($"  Player rank by level: #{rank}");
            }
        }

        /// <summary>
        /// Example 5: Leaderboards
        /// </summary>
        private void ExampleLeaderboards()
        {
            Debug.Log("\n=== EXAMPLE 5: Leaderboards ===");

            // Get top players by level
            List<PlayerStats> topByLevel = statsRepo.GetTopPlayersByLevel(5);
            Debug.Log("✓ Top 5 Players by Level:");
            int rank = 1;
            foreach (PlayerStats stats in topByLevel)
            {
                Player player = playerRepo.GetPlayerByID(stats.PlayerID);
                Debug.Log($"  #{rank}: {player.PlayerName} - Level {stats.Level} ({stats.TotalExperience} XP)");
                rank++;
            }

            // Get top players by win rate
            List<PlayerStats> topByWinRate = statsRepo.GetTopPlayersByWinRate(5);
            Debug.Log("\n✓ Top 5 Players by Win Rate:");
            rank = 1;
            foreach (PlayerStats stats in topByWinRate)
            {
                if (stats.TotalBattles > 0)
                {
                    Player player = playerRepo.GetPlayerByID(stats.PlayerID);
                    double winRate = stats.GetWinRate();
                    Debug.Log($"  #{rank}: {player.PlayerName} - {winRate:F1}% ({stats.TotalWins}W-{stats.TotalLosses}L)");
                    rank++;
                }
            }
        }

        /// <summary>
        /// Example 6: Battle simulation and recording results
        /// </summary>
        private void ExampleBattleSimulation()
        {
            Debug.Log("\n=== EXAMPLE 6: Battle Results & Recording ===");

            Player player1 = playerRepo.GetPlayerByName("CommanderAlex");
            Player player2 = playerRepo.GetPlayerByName("CaptainBlue");

            if (player1 != null && player2 != null)
            {
                // Create a battle record for Player 1 (they won)
                BattleRecord battle = new BattleRecord
                {
                    PlayerID = player1.PlayerID,
                    OpponentName = player2.PlayerName,
                    Result = "Win",
                    ShipsDestroyed = 4,
                    ShipsLost = 1,
                    ExperienceGained = 300,
                    DifficultyLevel = "Normal",
                    BattleMode = "SkirmishBattle"
                };

                Debug.Log($"✓ Recording battle: {player1.PlayerName} vs {player2.PlayerName}");
                PlayerStats statsBeforeBattle = statsRepo.GetPlayerStats(player1.PlayerID);
                Debug.Log($"  Stats before: Level {statsBeforeBattle.Level}, W-L-D: {statsBeforeBattle.TotalWins}-{statsBeforeBattle.TotalLosses}-{statsBeforeBattle.TotalDraws}");

                // Record the battle
                statsRepo.RecordBattleResult(player1.PlayerID, battle);

                PlayerStats statsAfterBattle = statsRepo.GetPlayerStats(player1.PlayerID);
                Debug.Log($"  Stats after: Level {statsAfterBattle.Level}, W-L-D: {statsAfterBattle.TotalWins}-{statsAfterBattle.TotalLosses}-{statsAfterBattle.TotalDraws}");
                Debug.Log($"  Experience: +{battle.ExperienceGained}, Total: {statsAfterBattle.TotalExperience}");

                // Record battle for Player 2 (they lost)
                BattleRecord battle2 = new BattleRecord
                {
                    PlayerID = player2.PlayerID,
                    OpponentName = player1.PlayerName,
                    Result = "Loss",
                    ShipsDestroyed = 1,
                    ShipsLost = 4,
                    ExperienceGained = 100,
                    DifficultyLevel = "Normal",
                    BattleMode = "SkirmishBattle"
                };

                statsRepo.RecordBattleResult(player2.PlayerID, battle2);
                Debug.Log($"✓ Battle results recorded for both players");
            }
        }

        private void OnApplicationQuit()
        {
            // IMPORTANT: Close database connection on exit
            Debug.Log("Closing database connection...");
            DatabaseManager.Instance.Close();
        }
    }
}
