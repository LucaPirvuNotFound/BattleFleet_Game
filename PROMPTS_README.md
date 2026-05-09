Prompt History & Assistant Response Summary

Date: May 5, 2026

**Purpose**: Record the user prompts given during this session and a short, clear summary of how the assistant responded (what was created, added, or suggested).

---

**Prompt 1 (original project request)**
"I am a student in my second year. I have gathered another 4 colleagues for a uni project for the Software Developer class. We have to create an application that uses at least 2 AI agents.

We have decided to create a game based on the game Battle Fleet 2 (the naval, turn-based game).  The game will be played locally. The other ships will be either AI agents with different levels of intelligence (preferably to be able to choose the difficulty) or other ships that also you can control (so multiple people can play from the same device).

There should be an option to run a game with only AI agents involved and the possibility to watch their gameplay and see their strategy (via voice or text on screen)

The gameplay should be very similar to the original game, Battle Fleet 2, so most of the logic should be implemented the same way.  In order to help you, I will give you a description of the original game: [long description omitted for brevity here]

My role is to work on the database connection, storyng player users and their stats, the leveling up logic. I'll user SQLLite and unity and my first task is the following. create the databases in sqlite locally and write the queries (CRUD) for creati8ng a new player  and save their name, independently from the game. Think deeply and gtenerate the task in this folder, and make sure you create a meaningful and efficient structure"

Assistant response summary:
- **Action**: Designed a complete SQLite schema and generated Unity-ready C# code for database integration.
- **Files created** (workspace root):
  - [database_schema.sql](database_schema.sql)
  - [DatabaseModels.cs](DatabaseModels.cs)
  - [DatabaseManager.cs](DatabaseManager.cs)
  - [PlayerRepository.cs](PlayerRepository.cs)
  - [PlayerStatsRepository.cs](PlayerStatsRepository.cs)
  - [DatabaseUsageExample.cs](DatabaseUsageExample.cs)
  - [DatabaseTests.cs](DatabaseTests.cs)
  - [SETUP_GUIDE.md](SETUP_GUIDE.md)
  - [README.md](README.md)
  - [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)
- **Notes**: Implemented parameterized queries, automatic table creation, a singleton `DatabaseManager`, CRUD for player creation and stats, leveling logic (1000 XP per level), and example usage and tests to validate integration. Recommendations for Unity `Application.persistentDataPath` were included.

---

**Prompt 2 (follow-up request)**
"add a readme file  that includes the prompts that i am giving you and a short but understandable resume on how you responded after each prompt (what you created, added, suggested etc.)"

Assistant response summary:
- **Action**: Created this README file `PROMPTS_README.md` in the project root summarizing the key prompts and concise responses.
- **Notes**: Updated a small todo list for the task and saved the file to `c:\Users\User\mds_lore\PROMPTS_README.md`.

---

If you want a more detailed transcript (including exact verbatim text of every assistant message and every intermediate status update), say so and I will append the full conversation log below this summary.

Files referenced above are in the workspace root `c:\Users\User\mds_lore`. To open the main integration guide, see [SETUP_GUIDE.md](SETUP_GUIDE.md).

---

**Prompt 5 (Claude)**
"in the current project, the following task is the following: levelling up: as a player when i engage in battles, i want my captain to gain xp so that they can unlock 'command cards' or improve their accuracy. this issue relates to the gameplay mechanics of a battle system. players want to enhance their captains abilities through experience points gained in battles. Acceptance criteria: captain should gain xp after each battle. xp should contribute towards unlocking command cards. improved accuracy should be a measurable outcome of gained xp. I want you to edit the files in order to respect the task, but keep the structure. take notice that i had a task progression bar in which i might have already implemented some levelling logic. add the prompt in the prompts readme"

Assistant response summary:
- **Action**: Implemented the full captain levelling feature across the database layer, keeping the existing project structure intact.
- **Files modified**:
  - [database_schema.sql](database_schema.sql) — Added `AccuracyBonus` column to `Captains` table; added `CommandCards` table (seeded with 5 cards, one per level); added `CaptainCommandCards` junction table and its index.
  - [DatabaseModels.cs](DatabaseModels.cs) — Added `AccuracyBonus` property to `Captain`; added `CommandCard` model; added `CaptainCommandCard` model.
- **Files created**:
  - [CaptainRepository.cs](CaptainRepository.cs) — New repository following the existing `PlayerStatsRepository` pattern with: `GetCaptain`, `GetCaptainsByPlayer`, `CreateCaptain`, `AwardBattleXp` (Win +150 XP, Loss +50, Draw +75, +25 per ship destroyed), `GetCaptainAccuracyBonus`, `GetAllCommandCards`, `GetUnlockedCommandCards`.
- **Key design decisions**:
  - XP curve mirrors `PlayerStatsRepository.CalculateLevel`: each level costs `level * 100` XP (Level 2 = 100 XP, Level 3 = 300, Level 4 = 600 …).
  - Accuracy bonus formula: `(captainLevel - 1) * 2%` (measurable, persisted in DB as `AccuracyBonus`).
  - One command card unlocks per captain level (Steady Aim at L1, Broadside Volley at L2, Evasive Maneuvers at L3, Suppressing Fire at L4, Admiral's Command at L5).
  - `UnlockEligibleCommandCards` uses `INSERT OR IGNORE` so it is safe to call on every level-up without creating duplicates.
  - All queries use parameterized statements (no SQL injection risk).

**Prompt 3 (Gemini)**
"Vreau sa imi dai un prompt detaliat, pe care un ai pentru generarea diagramelor UML ar putea sa il parcurga cu precizie, in engleza, fara sa omiti niciun detaliu pe care ti l-am dat de- a lungul conversatiei. Vreau sa folosesc mermaid.ai pentru generarea celor 3 tipuri de diagrame UML. te rog sa ai grija sa incluzi: toate cele 5 modele precizate in partea de databases, toate navele care s-ar deriva din Ship cu echipamentul corespunzator, conform listei, tot ce se afla in schemas.py si modalitatea prin care vrem noi sa functioneze legatura intre Unity si python, exact cum a descris-o colegul meu prin folosirea fisierelor de tip json"

Assistant response summary:
- **Action**: Created the requested prompt: 
"The Mermaid.ai Master Prompt
Role: You are an expert Software Architect and Mermaid.js specialist.
Task: Generate three distinct Mermaid.js diagrams (Class, Sequence, and Activity) for a turn-based naval game project ("Battle Fleet 2" style) developed in Unity (C#), Python (FastAPI), and SQLite.

1. Class Diagram Specifications:
Include the following three logical modules:

Database Models (C# / SQLite):

Player: int PlayerID, string PlayerName, DateTime CreatedDate, DateTime? LastPlayedDate, bool IsActive.

PlayerStats: int StatID, int PlayerID, int Level, int TotalExperience, int TotalBattles, int TotalWins, int TotalLosses, int TotalDraws, double AverageAccuracy, int TotalShipsDestroyed, int TotalShipsLost, double CampaignProgressPercentage, int HighestLevel, DateTime LastUpdated.

Captain: int CaptainID, int PlayerID, string CaptainName, int ExperiencePoints, int Level, string SpecializationClass (General/Aggressive/Defensive/Scout), int BattlesParticipated, bool IsAvailable.

BattleRecord: int BattleID, int PlayerID, string OpponentName, DateTime BattleDate, string Result, int ShipsDestroyed, int ShipsLost, int ExperienceGained, string DifficultyLevel, string BattleMode.

CampaignSave: int SaveID, int PlayerID, string CampaignName, int CurrentTurn, int TerritoryControlled, int ResourcePoints, string EnemyFaction, string DifficultyLevel, DateTime SaveDate.

Ship Hierarchy (Unity Entities):

Base Class Ship: Health, Speed, List<Weapon> Armament.

Battleship: 12,000hp, 22 knots. Armament: 3 heavy turrets, 4 light turrets, 2 torpedo launchers, recon planes.

Cruiser: 9,000hp, 30 knots. Armament: 3 medium turrets, 4 light turrets, 2 torpedo launchers.

Destroyer: 4,000hp, 35 knots. Armament: 1 medium turret, 8 light turrets, 6 torpedo launchers.

Corvette: 1,750hp, 35 knots. Armament: 7 light turrets, 4 torpedo launchers.

Torpedo Boat: 300hp, 45 knots. Armament: 1 light turret, 1 torpedo launcher.

API Schemas (Pydantic/FastAPI):

Vec3: float x, y, z.

Environment: float gravity (default 9.81).

GameState: Vec3 ai_ship_position, Vec3 target_ship_position, Environment environment.

ShootAction: string action="shoot", float angle_horizontal, float angle_vertical, float power.

2. Sequence Diagram Specifications:
Visualize the "AI Turn" interaction:

Actors: Unity Client, FastAPI Backend, SQLite Database.

Process:

Unity Client serializes GameState into a JSON package.

Unity sends JSON via HTTP POST to the Python FastAPI backend.

Python (physics.py) runs the ballistic solver (compute_minimum_speed_ballistic).

Python returns a JSON response (ShootAction) containing angles and power.

Unity receives JSON and executes the shot animation.

Unity triggers an immediate Database Save after the action to update BattleRecord, PlayerStats, and CampaignSave.

3. Activity Diagram Specifications:
Visualize the "Game Loop Logic":

Nodes: Start Turn -> Check if Active Player is AI or Human.

AI Path: Request AI strategy (FastAPI) -> Receive Decision -> Display Strategy text/voice on screen (Spectator Mode logic) -> Execute Move/Shot.

Human Path: Wait for UI Input -> Execute Move/Shot.

Shared Path: Calculate Hit/Miss -> Update SQLite Database (Persistent Save) -> Check for Game Over.

End Path: Update CampaignSave (Territory/Resources) and PlayerStats (XP/Level).

Output Format: Provide three separate code blocks in Mermaid.js syntax."


**Prompt 4(Claude)**
"My role is to work on the database connection, storyng player users and their stats, the leveling up logic. I'll user SQLLite and unity and my first task was the following. create the databases in sqlite locally and write the queries (CRUD) for creati8ng a new player and save their name, independently from the game.  Now my branch hierarchy looks like this: 1. database_schema.sql              (SQL Database Schema) ├── 2. DatabaseModels.cs                (C# Model Classes) ├── 3. DatabaseManager.cs               (Connection Management) ├── 4. PlayerRepository.cs              (CRUD Operations - Players) ├── 5. PlayerStatsRepository.cs         (Statistics & Progression) ├── 6. DatabaseUsageExample.cs          (6 Practical Examples) ├── 7. DatabaseTests.cs                 (Unit Tests & Validation) ├── 8. SETUP_GUIDE.md                   (Installation Instructions) ├── 9. README.md                        (Project Overview) └── 10. PROJECT_STRUCTURE.md            (This File). My next task is the following: Progression bar, and the user story related to this one is the following: As a player, when my fleet reaches a certain level, I want to unlock advanced ships like Carriers so that I can enhance my gameplay experience.
Context
Players currently have access to advanced ships without fleet level restrictions. This change aims to create a more engaging progression system.
Acceptance criteria

Players can only unlock advanced ships like Carriers after reaching a specified fleet level.
The required fleet level for unlocking advanced ships should be clearly displayed in the game. Think deeply and write me exactly what I should add, where and the piece of code that i need to integer in the project, if i need a separeate file or anything else"

Assistant response summary:
- **Action**: Highlighted the adds needed to the existing files and creating 2 new files:  ShipUnlockRepository.cs and ProgressionBarUI.cs.