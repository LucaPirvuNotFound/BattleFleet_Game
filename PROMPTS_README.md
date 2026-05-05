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
