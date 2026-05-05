# Battle Fleet 2 - Database System Setup Guide

## Overview

This database system provides a comprehensive SQLite-based persistence layer for your Battle Fleet 2 game. It manages player profiles, statistics, progression, and campaign data.

## Project Structure

```
mds_lore/
├── database_schema.sql          # SQLite schema definition
├── DatabaseModels.cs            # C# model classes
├── DatabaseManager.cs           # Core database connection and operations
├── PlayerRepository.cs          # Player CRUD operations
└── SETUP_GUIDE.md              # This file
```

## Components

### 1. **database_schema.sql**
- SQLite schema with 8 main tables
- Includes foreign key constraints for data integrity
- Indexes for optimized query performance

### 2. **DatabaseModels.cs**
Contains C# model classes:
- `Player` - Player profile information
- `PlayerStats` - Player progression and statistics
- `Captain` - Ship captain progression
- `BattleRecord` - Battle history and results
- `CampaignSave` - Campaign game state

### 3. **DatabaseManager.cs**
Singleton class managing:
- SQLite connection lifecycle
- Query execution methods (ExecuteNonQuery, ExecuteScalar, ExecuteReader)
- Automatic table creation on first run
- Transaction support

### 4. **PlayerRepository.cs**
CRUD operations for players:
- **CREATE**: `CreatePlayer(playerName)`
- **READ**: `GetPlayerByID()`, `GetPlayerByName()`, `GetAllActivePlayers()`
- **UPDATE**: `UpdatePlayer()`, `UpdateLastPlayedDate()`
- **DELETE**: `DeletePlayer()` (soft and hard delete)

## Installation Steps

### Step 1: Copy Files to Unity Project

Place the C# files in your Unity project Assets folder:
```
Assets/
├── Scripts/
│   ├── Database/
│   │   ├── DatabaseModels.cs
│   │   ├── DatabaseManager.cs
│   │   └── PlayerRepository.cs
```

### Step 2: Add Required Dependencies

Ensure your Unity project includes:
- **Mono.Data.Sqlite** (usually included with Unity)
- **System.Data** (for IDataReader, IDbConnection, etc.)

If missing, add via NuGet or Asset Store.

### Step 3: Create Database Initialization Script

Create a `GameManager.cs` or similar initialization script:

```csharp
using UnityEngine;
using BattleFleet.Database;

public class GameManager : MonoBehaviour
{
    private void Start()
    {
        // Initialize database (should be called once at game startup)
        DatabaseManager.Instance.Initialize("BattleFleetGame.db");
        
        Debug.Log("Game initialized successfully!");
    }

    private void OnApplicationQuit()
    {
        // Close database connection on exit
        DatabaseManager.Instance.Close();
    }
}
```

## Usage Examples

### Example 1: Create a New Player

```csharp
using BattleFleet.Database;

// Create player repository
PlayerRepository playerRepo = new PlayerRepository();

// Create a new player
Player newPlayer = playerRepo.CreatePlayer("CommanderAlex");

if (newPlayer != null)
{
    Debug.Log($"Player created: {newPlayer}");
}
```

### Example 2: Retrieve Player Information

```csharp
// Get player by name
Player player = playerRepo.GetPlayerByName("CommanderAlex");

if (player != null)
{
    Debug.Log($"Found player: {player.PlayerName} (ID: {player.PlayerID})");
}

// Get all active players
List<Player> allPlayers = playerRepo.GetAllActivePlayers();
Debug.Log($"Total active players: {allPlayers.Count}");
```

### Example 3: Update Player Last Played Date

```csharp
// Update when player starts a game session
playerRepo.UpdateLastPlayedDate(player.PlayerID);
```

### Example 4: Delete a Player

```csharp
// Soft delete (recommended - keeps data intact)
playerRepo.DeletePlayer(player.PlayerID, hardDelete: false);

// Hard delete (permanent removal - use with caution!)
// playerRepo.DeletePlayer(player.PlayerID, hardDelete: true);
```

## Database Location

The SQLite database file (`BattleFleetGame.db`) is created in:

- **Development**: Project root or where the .exe runs
- **Built Game**: Same directory as the executable

For persistent storage, consider using:
```csharp
string dbPath = Application.persistentDataPath + "/BattleFleetGame.db";
DatabaseManager.Instance.Initialize(dbPath);
```

## Key Features

✅ **Automatic Table Creation** - Tables created on first database connection  
✅ **Soft Delete Support** - Players can be deactivated without data loss  
✅ **Singleton Pattern** - One database connection throughout the game  
✅ **Transaction Support** - For multi-step operations (see `BeginTransaction()`)  
✅ **Error Handling** - Comprehensive logging and exception handling  
✅ **Parameterized Queries** - Protection against SQL injection  
✅ **Foreign Key Constraints** - Maintain referential integrity  

## Extension Guide

### Adding More Repositories

Create additional repositories following the `PlayerRepository` pattern:

```csharp
public class CaptainRepository
{
    private DatabaseManager dbManager;

    public CaptainRepository()
    {
        dbManager = DatabaseManager.Instance;
    }

    public Captain CreateCaptain(int playerID, string captainName, string specialization)
    {
        // Implementation similar to PlayerRepository.CreatePlayer()
    }
    
    // Add more CRUD methods...
}
```

### Adding Tables to Schema

1. Add SQL definition to `database_schema.sql`
2. Add CREATE TABLE query to `DatabaseManager.CreateTablesIfNotExist()`
3. Create corresponding model class in `DatabaseModels.cs`
4. Create repository class for CRUD operations

## Performance Considerations

- **Indexes**: Already created on foreign keys and frequently queried columns
- **Query Optimization**: Use indexes for WHERE clauses on PlayerID, PlayerName
- **Batch Operations**: Use transactions for multiple inserts/updates
- **Connection Pooling**: Singleton pattern reuses single connection

## Best Practices

1. **Always call `Initialize()` on game startup**
   ```csharp
   DatabaseManager.Instance.Initialize();
   ```

2. **Always call `Close()` on game exit**
   ```csharp
   DatabaseManager.Instance.Close();
   ```

3. **Use soft delete for user data**
   - Preserves game history and statistics

4. **Check `IsInitialized` before operations**
   ```csharp
   if (DatabaseManager.Instance.IsInitialized)
   {
       // Safe to use database
   }
   ```

5. **Use transactions for critical multi-step operations**
   ```csharp
   IDbTransaction transaction = DatabaseManager.Instance.BeginTransaction();
   try
   {
       // Multiple operations
       transaction.Commit();
   }
   catch
   {
       transaction.Rollback();
   }
   ```

## Troubleshooting

### Database File Not Found
- Check database path permissions
- Ensure `persistentDataPath` is used for built games

### "Table already exists" warnings
- These are normal - the system uses `IF NOT EXISTS`
- Safe to ignore

### Connection timeouts
- Increase timeout in connection string if needed:
  ```csharp
  connectionString = $"URI=file:{databasePath}?timeout=30";
  ```

### Mono.Data.Sqlite not found
- Add via NuGet Package Manager: `Install-Package Mono.Data.Sqlite`
- Restart Unity after installation

## Next Steps

1. ✅ Create game UI for player login/registration
2. ✅ Extend with `CaptainRepository` for captain progression
3. ✅ Extend with `BattleRepository` for battle history tracking
4. ✅ Add leaderboard queries to `PlayerRepository`
5. ✅ Implement save/load campaign functionality
6. ✅ Add achievement/unlock system

## Team Collaboration Notes

- This database system is independent of game logic
- Each team member working on different game features can query player/stats data
- AI agents will read stats to determine difficulty levels
- UI team can use `GetAllActivePlayers()` for player selection screens
- Balance/design team can analyze `BattleHistory` to tune game difficulty

---

**For questions or issues, refer to the C# code comments and inline documentation.**
