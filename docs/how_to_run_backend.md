# How to Run the Backend and Test the AIs

This guide explains how to spin up the FastAPI backend and test the integrated AI endpoints using the built-in test routes.

## Prerequisites
- **Docker** and **Docker Compose** installed on your machine.
- **Ollama** running locally. Ensure you have pulled the required models:
  - `ollama pull llama3.2:1b` (Enemy Admiral)
  - `ollama pull qwen2.5:1.5b` (Deck Officer / Narrator)
  - **Important for Linux Users:** By default, Ollama only listens on localhost (`127.0.0.1`). To allow the Docker container to connect via `host.docker.internal`, you must configure Ollama to listen on all interfaces. 
    - If running via systemd: Run `sudo systemctl edit ollama.service`, add `Environment="OLLAMA_HOST=0.0.0.0"` under the `[Service]` section, then run `sudo systemctl daemon-reload` and `sudo systemctl restart ollama`.
    - If running manually via CLI: Start Ollama with `OLLAMA_HOST=0.0.0.0 ollama serve`.

## 1. Running the Backend Container

The backend is fully dockerized. To start it, navigate to the `backend` directory and use Docker Compose:

```bash
cd backend
docker-compose up --build
```

This will build the image (including installing Python dependencies) and start the FastAPI server. 
- The API will be accessible at: `http://localhost:8001` (or `8000` depending on your `docker-compose.yml` port mapping).
- The interactive API documentation (Swagger UI) is available at: `http://localhost:8001/docs`.

## 2. Testing the AI Endpoints

The backend provides specific endpoints for testing the Ollama AI agents.

### A. Testing the Enemy Admiral (Tactical JSON Agent)

The Admiral takes a JSON game state and returns a tactical decision in JSON format.

**Endpoint:** `POST /ai/test/admiral`

**Example cURL request:**
```bash
curl -X 'POST' \
  'http://localhost:8001/ai/test/admiral' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "game_state": {
    "player_ships": 3,
    "enemy_ships": 2,
    "last_hit_x": 4,
    "last_hit_y": 5
  }
}'
```
*Expected Output:* A JSON object containing `target_x`, `target_y`, and `strategy`.

### B. Testing the Deck Officer Narrator (Snoop Dogg Persona & TTS)

The Narrator evaluates the game state, generates immersive text, and synthesizes an MP3 audio file using gTTS.

**Endpoint:** `POST /ai/test/narrator`

**Example cURL request:**
```bash
curl -X 'POST' \
  'http://localhost:8001/ai/test/narrator' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "game_state": {
    "event": "ship_sunk",
    "details": "The enemy flagship has been destroyed."
  },
  "instruction_text": "You are Snoop Dogg acting as a naval deck officer. Warn the captain about the current situation using your signature style, slang, and laid-back attitude."
}'
```
*Note: `instruction_text` is optional and will default to the Snoop Dogg persona if omitted.*

*Expected Output:* 
```json
{
  "commentary": "Yo Captain, we just sunk their main ride, ya dig? It's all good in the hood, but keep your eyes peeled for more bogies.",
  "audio_path": "instance/narrator_output.mp3"
}
```
You can then retrieve or play the `.mp3` file from the `backend/instance/` directory.
