import json
import os

import httpx
from gtts import gTTS

OLLAMA_API_URL = os.getenv("OLLAMA_API_URL", "http://host.docker.internal:11434/api/generate")
_TIMEOUT = 300.0


def _tactical_summary(ctx: dict) -> str:
    """Compact tactical snapshot — keeps the prompt under ~200 tokens."""

    def _slim_ship(s: dict) -> dict:
        pos = s.get("position") or {}
        raw_weapons = s.get("weapons", [])
        weapons = []
        for w in raw_weapons:
            if isinstance(w, str):
                weapons.append(w)
            elif isinstance(w, dict) and w.get("available", True):
                weapons.append(w.get("name", "?"))
        return {
            "i": s.get("ship_index", "?"),
            "hp": s.get("hp", "?"),
            "x": round(float(pos.get("x", 0)), 1),
            "z": round(float(pos.get("z", 0)), 1),
            "hdg": round(float(pos.get("heading_degrees", 0)), 1),
            "weapons": weapons,
        }

    ai_ships = [_slim_ship(s) for s in ctx.get("ai_fleet", [])]
    vis_human = [_slim_ship(s) for s in ctx.get("visible_human_ships", [])]

    return json.dumps(
        {
            "match_id": ctx.get("match_id", ""),
            "round": ctx.get("round", 1),
            "ai": ai_ships,
            "enemy": vis_human,
        },
        separators=(",", ":"),
    )


async def get_admiral_decision(game_context_json: dict) -> dict:
    summary = _tactical_summary(game_context_json)

    prompt = (
        "You are the Enemy Admiral. Reply with ONLY valid JSON — no markdown, no explanation.\n\n"
        f"State: {summary}\n\n"
        "Rules — move: angle -180 to 180 (0=ahead), distance 0-90; "
        "fire: angle -180 to 180, distance <= weapon range.\n\n"
        "Output format (one action block per ship):\n"
        '{"match_id":"<id>","round":<n>,"phase":"ai_turn_end",'
        '"actions":[{"ship_index":0,"orders":['
        '{"type":"move","angle":0,"distance":50},'
        '{"type":"fire","weapon":"Light Cannon","angle":0,"distance":100}'
        "]}]}"
    )

    payload = {
        "model": "llama3.2:1b",
        "prompt": prompt,
        "format": "json",
        "stream": False,
        "keep_alive": -1,
    }

    async with httpx.AsyncClient() as client:
        response = await client.post(OLLAMA_API_URL, json=payload, timeout=_TIMEOUT)
        response.raise_for_status()
        result_text = response.json()["response"]

    try:
        return json.loads(result_text)
    except json.JSONDecodeError:
        return {"error": "AI failed to return valid JSON", "raw_output": result_text}


async def get_narrator_commentary(
    game_context_json: dict,
    instruction_md_path: str,
    output_audio_path: str,
) -> str:
    try:
        with open(instruction_md_path, "r", encoding="utf-8") as f:
            md_instructions = f.read()
    except FileNotFoundError:
        md_instructions = (
            "You are Snoop Dogg acting as a naval deck officer. React to what's happening "
            "in one sentence using your signature slang and laid-back attitude."
        )

    summary = _tactical_summary(game_context_json)

    prompt = (
        f"{md_instructions}\n\n"
        f"Situation: {summary}\n\n"
        "Give exactly ONE sentence of in-character commentary."
    )

    payload = {
        "model": "qwen2.5:1.5b",
        "prompt": prompt,
        "stream": False,
        "keep_alive": -1,
    }

    async with httpx.AsyncClient() as client:
        response = await client.post(OLLAMA_API_URL, json=payload, timeout=_TIMEOUT)
        response.raise_for_status()
        commentary_text = response.json()["response"].strip()

    os.makedirs(os.path.dirname(output_audio_path), exist_ok=True)
    tts = gTTS(text=commentary_text, lang="en", tld="us")
    tts.save(output_audio_path)

    return commentary_text
