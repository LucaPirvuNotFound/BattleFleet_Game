import json
import httpx
from gtts import gTTS
import os
from pathlib import Path

OLLAMA_API_URL = os.getenv("OLLAMA_API_URL", "http://host.docker.internal:11434/api/generate")

async def get_admiral_decision(game_context_json: dict) -> dict:
    """
    Agent 1: Evaluates game context and outputs JSON tactical decisions.
    """
    prompt = f"""
    You are the Enemy Admiral AI. Analyze the following game state and output your next move.
    
    Familiarize yourself with the following stats of each possible ship:
    - Battleship: 12,000hp, 22 knots, armament: 3 heavy turrets, 4 light turrets, 2 torpedo launchers, can launch recon planes
    - Cruiser: 9,000hp, 30 knots, armament: 3 medium turrets, 4 light turrets, 2 torpedo launchers
    - Destroyer: 4,000hp, 35 knots, armament: 1 medium turret, 8 light turrets, 6 torpedo launchers
    - Corvette: 1750hp, 35 knots, armament: 7 light turrets, 4 torpedo launchers
    - Torpedo Boat: 300hp, 45 knots, armament: 1 light turret, 1 torpedo launcher
    
    Respond ONLY with a valid JSON object matching this exact expected format structure:
    {{
      "match_id": "<the_match_id>",
      "round": <the_round_number>,
      "phase": "ai_turn_end",
      "actions": [
        {{
          "ship_index": <ship_index>,
          "orders": [
            {{ "type": "move", "angle": <float>, "distance": <float> }},
            {{ "type": "fire", "weapon": "<weapon_name>", "angle": <float>, "distance": <float> }}
          ]
        }}
      ]
    }}
    
    Game State: {json.dumps(game_context_json)}
    """
    
    payload = {
        "model": "llama3.2:1b",
        "prompt": prompt,
        "format": "json",  # Forces Ollama to output valid JSON
        "stream": False
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(OLLAMA_API_URL, json=payload, timeout=60.0)
        response.raise_for_status()
        result_text = response.json()["response"]
        
        try:
            return json.loads(result_text)
        except json.JSONDecodeError:
            return {"error": "AI failed to return valid JSON", "raw_output": result_text}


async def get_narrator_commentary(game_context_json: dict, instruction_md_path: str, output_audio_path: str) -> str:
    """
    Agent 2: Reads MD instructions, evaluates JSON context, outputs text commentary, and generates an audio file.
    """
    # 1. Read the markdown instruction file
    try:
        with open(instruction_md_path, "r", encoding="utf-8") as file:
            md_instructions = file.read()
    except FileNotFoundError:
        md_instructions = "You are Snoop Dogg acting as a naval deck officer. Warn the captain about the current situation using your signature style, slang, and laid-back attitude."

    prompt = f"""
    {md_instructions}
    
    Current Game Status (JSON):
    {json.dumps(game_context_json)}
    
    Output a single, immersive sentence reacting to the game status.
    """
    
    payload = {
        "model": "qwen2.5:1.5b",
        "prompt": prompt,
        "stream": False
    }
    
    # 2. Ask Ollama for the text commentary
    async with httpx.AsyncClient() as client:
        response = await client.post(OLLAMA_API_URL, json=payload, timeout=60.0)
        response.raise_for_status()
        commentary_text = response.json()["response"].strip()

    # 3. Convert Text to Speech (Audio file)
    # Save the audio to a file that FastAPI can serve to Godot via a static file endpoint
    os.makedirs(os.path.dirname(output_audio_path), exist_ok=True)
    # Note: gTTS uses Google Translate TTS, which doesn't have custom celebrity voices natively.
    # We use US English to approximate the requirement as best as the library supports.
    tts = gTTS(text=commentary_text, lang='en', tld='us')
    tts.save(output_audio_path)
    
    return commentary_text