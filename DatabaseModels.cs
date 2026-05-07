using System;
using System.Collections.Generic;

namespace BattleFleet.Database
{
    /// <summary>
    /// Player model class - represents a player in the game
    /// </summary>
    [System.Serializable]
    public class Player
    {
        public int PlayerID { get; set; }
        public string PlayerName { get; set; }
        public DateTime CreatedDate { get; set; }
        public DateTime? LastPlayedDate { get; set; }
        public bool IsActive { get; set; }
        public int FleetLevel { get; set;}
        public int FleetXP { get; set;}

        public Player()
        {
            IsActive = true;
            CreatedDate = DateTime.Now;
        }

        public Player(string playerName)
        {
            PlayerName = playerName;
            IsActive = true;
            CreatedDate = DateTime.Now;
        }

        public override string ToString()
        {
            return $"Player: {PlayerName} (ID: {PlayerID}) - Created: {CreatedDate:yyyy-MM-dd}";
        }
    }

    /// <summary>
    /// Player statistics model - tracks player performance and progression
    /// </summary>
    [System.Serializable]
    public class PlayerStats
    {
        public int StatID { get; set; }
        public int PlayerID { get; set; }
        public int Level { get; set; }
        public int TotalExperience { get; set; }
        public int TotalBattles { get; set; }
        public int TotalWins { get; set; }
        public int TotalLosses { get; set; }
        public int TotalDraws { get; set; }
        public double AverageAccuracy { get; set; }
        public int TotalShipsDestroyed { get; set; }
        public int TotalShipsLost { get; set; }
        public double CampaignProgressPercentage { get; set; }
        public int HighestLevel { get; set; }
        public DateTime LastUpdated { get; set; }

        public PlayerStats()
        {
            Level = 1;
            HighestLevel = 1;
            LastUpdated = DateTime.Now;
        }

        public double GetWinRate()
        {
            if (TotalBattles == 0) return 0.0;
            return (double)TotalWins / TotalBattles * 100.0;
        }

        public override string ToString()
        {
            return $"Stats - Level: {Level}, Exp: {TotalExperience}, W-L-D: {TotalWins}-{TotalLosses}-{TotalDraws}, WinRate: {GetWinRate():F1}%";
        }
    }

    /// <summary>
    /// Captain model - represents ship captains with progression
    /// </summary>
    [System.Serializable]
    public class Captain
    {
        public int CaptainID { get; set; }
        public int PlayerID { get; set; }
        public string CaptainName { get; set; }
        public int ExperiencePoints { get; set; }
        public int Level { get; set; }
        public string SpecializationClass { get; set; } // General, Aggressive, Defensive, Scout
        public int BattlesParticipated { get; set; }
        public DateTime CreatedDate { get; set; }
        public bool IsAvailable { get; set; }

        public Captain()
        {
            Level = 1;
            IsAvailable = true;
            CreatedDate = DateTime.Now;
            SpecializationClass = "General";
        }

        public Captain(string captainName, string specialization = "General")
        {
            CaptainName = captainName;
            Level = 1;
            IsAvailable = true;
            CreatedDate = DateTime.Now;
            SpecializationClass = specialization;
        }
    }

    /// <summary>
    /// Battle history model - tracks individual battles
    /// </summary>
    [System.Serializable]
    public class BattleRecord
    {
        public int BattleID { get; set; }
        public int PlayerID { get; set; }
        public string OpponentName { get; set; }
        public DateTime BattleDate { get; set; }
        public string Result { get; set; } // Win, Loss, Draw
        public int ShipsDestroyed { get; set; }
        public int ShipsLost { get; set; }
        public int ExperienceGained { get; set; }
        public string DifficultyLevel { get; set; }
        public string BattleMode { get; set; } // SkirmishBattle, Campaign, Multiplayer

        public BattleRecord()
        {
            BattleDate = DateTime.Now;
            DifficultyLevel = "Normal";
            BattleMode = "SkirmishBattle";
        }

        public override string ToString()
        {
            return $"Battle vs {OpponentName} ({BattleDate:yyyy-MM-dd}) - {Result} | Exp: +{ExperienceGained}";
        }
    }

    /// <summary>
    /// Campaign save model - represents an active campaign game
    /// </summary>
    [System.Serializable]
    public class CampaignSave
    {
        public int SaveID { get; set; }
        public int PlayerID { get; set; }
        public string CampaignName { get; set; }
        public int CurrentTurn { get; set; }
        public int TerritoryControlled { get; set; }
        public int ResourcePoints { get; set; }
        public string EnemyFaction { get; set; }
        public string DifficultyLevel { get; set; }
        public DateTime SaveDate { get; set; }
        public DateTime? LastLoadedDate { get; set; }
        public bool IsActive { get; set; }

        public CampaignSave()
        {
            CurrentTurn = 1;
            ResourcePoints = 0;
            EnemyFaction = "Japan";
            DifficultyLevel = "Normal";
            SaveDate = DateTime.Now;
            IsActive = true;
        }

        public CampaignSave(string campaignName, string difficulty = "Normal")
        {
            CampaignName = campaignName;
            CurrentTurn = 1;
            ResourcePoints = 0;
            EnemyFaction = "Japan";
            DifficultyLevel = difficulty;
            SaveDate = DateTime.Now;
            IsActive = true;
        }
    }

    // Represents a row in ship_unlock_requirements
    [System.Serializable]
    public class ShipUnlockRequirement
    {
        public string ShipType       { get; set; }
        public int    RequiredLevel  { get; set; }
        public string DisplayName    { get; set; }
        public string Description    { get; set; }
    }

    // Lightweight result used by UI to check unlock status
    [System.Serializable]
    public class ShipUnlockStatus
    {
        public string ShipType      { get; set; }
        public string DisplayName   { get; set; }
        public int    RequiredLevel { get; set; }
        public bool   IsUnlocked    { get; set; }
        public string Description   { get; set; }

        // Convenience string for UI display
        public string UnlockLabel =>
            IsUnlocked ? "Unlocked" : $"Requires Fleet Level {RequiredLevel}";
    }
}
