# BattleFleet Game - AI & Architecture Context

## General Architecture
This project is an asymmetric multiplayer naval combat game featuring a meta-game and real-time battle phase.

### Phase A: Meta-game (FastAPI)
- Uses FastAPI (running in a Docker container on port 8001 mapping to 8000) for player authentication, profile management, matchmaking queues, and loadout validation.
- Clients connect to this API to manage their fleets and wait for matches.

### Phase B/C: Battle Phase (Godot Dedicated Server)
- Players transition from the FastAPI meta-game to a real-time Godot headless server instance via ENet for gameplay.
- Fast API is responsible for issuing connection info (IP/port) and handling match result records when the Godot server finishes.

## Local AI Integration (Ollama)
The game utilizes local LLMs running via Ollama for dynamic, offline AI interactions:

1. **The Enemy Admiral (Tactical JSON Agent)**
   - **Model:** `llama3.2:1b`
   - **Role:** Analyzes the game context (provided as JSON) and makes tactical moves (returning JSON with `target_x`, `target_y`, `strategy`).
   - **Why:** Extremely fast, low RAM usage (~1GB), highly tuned for strict JSON output ensuring robust game logic.

2. **The Deck Officer (Narrator Agent)**
   - **Model:** `qwen2.5:1.5b`
   - **Role:** Generates immersive narrative text based on markdown instructions and JSON state, simulating a deck officer's frantic reactions.
   - **Why:** Strong roleplay capabilities, handles markdown and contextual text generation efficiently while remaining lightweight.
   - **Output:** Text commentary which is also processed into an audio file using `gTTS` (configured with a Snoop Dogg style persona).

## Infrastructure Notes
- The FastAPI backend is dockerized.
- Since Ollama runs on the host (e.g., Linux Pi), the Docker container uses `host.docker.internal` (via `extra_hosts` in `docker-compose.yml`) to communicate with the Ollama API at `http://host.docker.internal:11434/api/generate`.
- `gTTS` is used to generate audio files via Google Translate's API.
