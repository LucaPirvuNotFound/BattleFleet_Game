# Battle Fleet 2 - Database System
## Complete SQLite Integration for Unity

A comprehensive, production-ready database system for managing players, statistics, progression, and campaign data in your Battle Fleet 2 game.

---

## 📋 Project Overview

Your role is to implement the database layer for the Battle Fleet 2 game. This includes:
- ✅ **Player Management** - Create, retrieve, update, delete players
- ✅ **Statistics Tracking** - Track wins, losses, experience, accuracy, ship count
- ✅ **Leveling System** - Experience-based progression with automatic level calculation
- ✅ **Battle Recording** - Log and analyze battles for AI training
- ✅ **Leaderboards** - Rank players by level, win rate, and achievements

---

## 📁 Files Included

### Core Database Files
| File | Purpose |
|------|---------|
| `database_schema.sql` | SQLite schema with 8 tables and indexes |
| `DatabaseManager.cs` | Connection management and query execution |
| `DatabaseModels.cs` | C# model classes for all entities |
| `PlayerRepository.cs` | CRUD operations for players |
| `PlayerStatsRepository.cs` | Statistics management and leveling |

### Documentation & Examples
| File | Purpose |
|------|---------|
| `SETUP_GUIDE.md` | Complete installation and integration guide |
| `DatabaseUsageExample.cs` | 6 detailed usage examples |
| `README.md` | This file |

---

## 🚀 Quick Start

### Step 1: Copy Files to Unity Project
```
Assets/Scripts/Database/
├── DatabaseModels.cs
├── DatabaseManager.cs
├── PlayerRepository.cs
└── PlayerStatsRepository.cs
```

### Step 2: Initialize Database
```csharp
// In your GameManager or startup script
DatabaseManager.Instance.Initialize("BattleFleetGame.db");
```

### Step 3: Create a Player
```csharp
PlayerRepository playerRepo = new PlayerRepository();
Player newPlayer = playerRepo.CreatePlayer("CommanderAlex");
```

### Step 4: Save Game State
```csharp
// On game exit
DatabaseManager.Instance.Close();
```

---

## 🗄️ Database Schema

### 8 Core Tables

```sql
Players
├── PlayerID (PK)
├── PlayerName (UNIQUE)
├── CreatedDate
├── LastPlayedDate
└── IsActive

PlayerStats
├── StatID (PK)
├── PlayerID (FK)
├── Level
├── TotalExperience
├── TotalBattles
├── TotalWins/Losses/Draws
├── AverageAccuracy
├── TotalShipsDestroyed/Lost
├── CampaignProgressPercentage
└── HighestLevel

Captains (for ship captain progression)
├── CaptainID (PK)
├── PlayerID (FK)
├── CaptainName
├── ExperiencePoints
├── Level
├── SpecializationClass
├── BattlesParticipated
└── IsAvailable

PlayerShips (fleet management)
├── ShipID (PK)
├── PlayerID (FK)
├── ShipName
├── ShipClass
├── HullHealth
├── Level
├── ExperiencePoints
└── IsAlive

ShipWeapons (weapon configuration)
├── WeaponID (PK)
├── ShipID (FK)
├── WeaponType
├── Quantity
├── Accuracy
├── Damage
├── Range
└── IsOperational

CampaignSaves (campaign state)
├── SaveID (PK)
├── PlayerID (FK)
├── CampaignName
├── CurrentTurn
├── TerritoryControlled
├── ResourcePoints
├── EnemyFaction
├── DifficultyLevel
└── SaveDate

BattleHistory (battle records)
├── BattleID (PK)
├── PlayerID (FK)
├── OpponentName
├── BattleDate
├── Result (Win/Loss/Draw)
├── ShipsDestroyed/Lost
├── ExperienceGained
├── DifficultyLevel
└── BattleMode

PlayerAchievements (unlockables)
├── AchievementID (PK)
├── PlayerID (FK)
├── AchievementType
└── UnlockedDate
```

---

## 📊 Leveling System

### Experience Formula
- **Base XP per level**: 1000
- **Current Level**: `TotalExperience / 1000 + 1`
- **Example**: 
  - 0 XP = Level 1
  - 1000 XP = Level 2
  - 2500 XP = Level 3
  - 5000 XP = Level 6

### Experience Gains
- Victory: +300 XP
- Defeat: +100 XP
- Battle Achievements: +50-200 XP bonus
- Campaign progression: +50 XP per turn

---

## 💻 Code Examples

### Create a New Player
```csharp
PlayerRepository playerRepo = new PlayerRepository();
Player newPlayer = playerRepo.CreatePlayer("CommanderAlex");

if (newPlayer != null)
{
    Debug.Log($"Player created: {newPlayer.PlayerName} (ID: {newPlayer.PlayerID})");
}
```

### Get Player Stats
```csharp
PlayerStatsRepository statsRepo = new PlayerStatsRepository();
PlayerStats stats = statsRepo.GetPlayerStats(playerId);

Debug.Log($"Level: {stats.Level}");
Debug.Log($"Experience: {stats.TotalExperience}");
Debug.Log($"Win Rate: {stats.GetWinRate():F1}%");
```

### Record Battle Result
```csharp
BattleRecord battle = new BattleRecord
{
    Result = "Win",
    ShipsDestroyed = 4,
    ShipsLost = 1,
    ExperienceGained = 300,
    DifficultyLevel = "Normal"
};

statsRepo.RecordBattleResult(playerId, battle);
```

### Get Leaderboard
```csharp
List<PlayerStats> topPlayers = statsRepo.GetTopPlayersByLevel(10);
foreach (PlayerStats stats in topPlayers)
{
    Player p = playerRepo.GetPlayerByID(stats.PlayerID);
    Debug.Log($"{p.PlayerName} - Level {stats.Level}");
}
```

### Update Last Played
```csharp
playerRepo.UpdateLastPlayedDate(playerId);
```

### Delete Player
```csharp
// Soft delete (recommended)
playerRepo.DeletePlayer(playerId, hardDelete: false);

// Hard delete
playerRepo.DeletePlayer(playerId, hardDelete: true);
```

---

## 🎯 Integration Points

### For AI Agents
```csharp
// Get player difficulty level
PlayerStats opponentStats = statsRepo.GetPlayerStats(playerId);
string difficulty = GetDifficultyFromStats(opponentStats.Level);
// Easy: Level 1-5, Normal: 6-15, Hard: 16-25, Expert: 26+
```

### For UI/Menu System
```csharp
// Player selection screen
List<Player> allPlayers = playerRepo.GetAllActivePlayers();
foreach (Player p in allPlayers)
{
    // Display player name and level
    PlayerStats stats = statsRepo.GetPlayerStats(p.PlayerID);
    Debug.Log($"{p.PlayerName} (Level {stats.Level})");
}
```

### For Campaign System
```csharp
// Save campaign progress
statsRepo.UpdateCampaignProgress(playerId, 45.5); // 45.5% complete

// Track campaign saves
CampaignSave save = new CampaignSave("Pacific War", "Normal");
// Store to database when needed
```

### For Battle/Gameplay
```csharp
// After each battle
BattleRecord result = new BattleRecord
{
    OpponentName = aiAgentName,
    Result = playerWon ? "Win" : "Loss",
    ShipsDestroyed = destroyedCount,
    ShipsLost = lostCount,
    ExperienceGained = expReward
};
statsRepo.RecordBattleResult(playerId, result);
```

---

## 🔧 Configuration

### Database File Location
**Development**:
```csharp
DatabaseManager.Instance.Initialize("BattleFleetGame.db");
```

**Published Game (Recommended)**:
```csharp
string dbPath = Application.persistentDataPath + "/BattleFleetGame.db";
DatabaseManager.Instance.Initialize(dbPath);
```

### Experience Per Level (Customizable)
In `PlayerStatsRepository.cs`, modify:
```csharp
int experiencePerLevel = 1000; // Change this value
```

---

## ⚙️ Advanced Features

### Transactions (for atomic operations)
```csharp
IDbTransaction transaction = DatabaseManager.Instance.BeginTransaction();
try
{
    // Multiple database operations
    transaction.Commit();
}
catch
{
    transaction.Rollback();
}
```

### Custom Queries
```csharp
// Execute custom SQL
string query = "SELECT * FROM Players WHERE PlayerName LIKE @pattern";
Dictionary<string, object> parameters = new Dictionary<string, object>
{
    { "@pattern", "%Commander%" }
};
IDataReader reader = DatabaseManager.Instance.ExecuteReader(query, parameters);
```

### Backup Database
```csharp
// Create backup before each major update
File.Copy("BattleFleetGame.db", "BattleFleetGame_backup.db", true);
```

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Table already exists" | Normal - use `IF NOT EXISTS` |
| Connection timeout | Increase timeout in connection string |
| Mono.Data.Sqlite not found | Install via NuGet: `Install-Package Mono.Data.Sqlite` |
| Database file not found | Check permissions and use `persistentDataPath` |
| Player creation fails | Check for duplicate names or database not initialized |

---

## 📈 Performance Tips

- ✅ Database file stored locally (no network latency)
- ✅ Indexes on foreign keys and frequently queried columns
- ✅ Parameterized queries prevent SQL injection
- ✅ Batch operations using transactions
- ✅ Soft delete preserves data integrity

---

## 🔐 Data Integrity

- ✅ Foreign key constraints prevent orphaned records
- ✅ UNIQUE constraint on PlayerName prevents duplicates
- ✅ AUTOINCREMENT IDs ensure uniqueness
- ✅ Timestamps track creation and modifications
- ✅ Soft delete preserves historical data

---

## 📞 Next Steps for Team

1. **UI Developer**: Use `GetAllActivePlayers()` for player selection screens
2. **AI Developer**: Use `GetPlayerStats()` to determine AI difficulty
3. **Game Designer**: Adjust experience rates in `PlayerStatsRepository`
4. **QA/Testing**: Use `DatabaseUsageExample.cs` for integration testing
5. **Analytics**: Query `BattleHistory` table for game data analysis

---

## 📝 Notes

- All queries use parameterized statements for security
- Timestamps are in UTC/ISO 8601 format
- Win rate calculated as: `(Wins / TotalBattles) * 100`
- Level calculated automatically from experience
- All error messages logged to Unity console
- Soft delete recommended for historical data preservation

---

## ✅ Checklist for Integration

- [ ] Copy all C# files to Assets/Scripts/Database/
- [ ] Add Mono.Data.Sqlite NuGet package
- [ ] Call `DatabaseManager.Instance.Initialize()` on game start
- [ ] Call `DatabaseManager.Instance.Close()` on game exit
- [ ] Test player creation with `DatabaseUsageExample.cs`
- [ ] Integrate with player selection UI
- [ ] Integrate with AI difficulty selection
- [ ] Test battle recording and stats updates
- [ ] Set up leaderboard UI queries
- [ ] Create backup routine for database

---

**Created for: Battle Fleet 2 - University Software Developer Project**  
**Database System: SQLite with Unity Integration**  
**Status: Production Ready**
