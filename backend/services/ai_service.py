import json
import math
import httpx
from gtts import gTTS

OLLAMA_API_URL = os.getenv("OLLAMA_API_URL", "http://host.docker.internal:11434/api/generate")
OLLAMA_TIMEOUT_SEC = float(os.getenv("OLLAMA_TIMEOUT_SEC", "12"))
SKIP_OLLAMA = os.getenv("SKIP_OLLAMA", "").lower() in ("1", "true", "yes")


def _ship_xz(position: dict) -> tuple[float, float]:
    return float(position.get("x", 0.0)), float(position.get("z", 0.0))


def _fallback_admiral_decision(game_context: dict) -> dict:
    """Rule-based fallback when Ollama is unavailable or returns invalid JSON."""
    match_id = str(game_context.get("match_id", ""))
    round_num = int(game_context.get("round", 1))
    ai_fleet = game_context.get("ai_fleet", [])
    visible_human = game_context.get("visible_human_ships", [])
    rules = game_context.get("rules", {})
    max_move = float(rules.get("max_move_distance", 90.0))

    actions: list[dict] = []
    for ship in ai_fleet:
        ship_index = int(ship.get("ship_index", -1))
        if ship_index < 0:
            continue

        sx, sz = _ship_xz(ship.get("position", {}))
        target = None
        best_dist = float("inf")
        for human in visible_human:
            if human.get("visible_to_ai") is False:
                continue
            hx, hz = _ship_xz(human.get("position", {}))
            dist = math.hypot(hx - sx, hz - sz)
            if dist < best_dist:
                best_dist = dist
                target = human

        orders: list[dict] = []
        if target is not None:
            tx, tz = _ship_xz(target.get("position", {}))
            dx, dz = tx - sx, tz - sz
            bearing = math.degrees(math.atan2(dx, -dz))
            move_dist = min(max_move, max(0.0, best_dist - 40.0))
            if move_dist > 5.0:
                orders.append({"type": "move", "angle": bearing, "distance": round(move_dist, 1)})

            weapon_name = "Light Cannon"
            for weapon in ship.get("weapons", []):
                if isinstance(weapon, dict) and weapon.get("available", True):
                    weapon_name = str(weapon.get("name", weapon_name))
                    break
                if isinstance(weapon, str) and weapon:
                    weapon_name = weapon
                    break

            fire_dist = max(20.0, min(best_dist, 200.0))
            orders.append(
                {
                    "type": "fire",
                    "weapon": weapon_name,
                    "angle": bearing,
                    "distance": round(fire_dist, 1),
                }
            )

        if orders:
            actions.append({"ship_index": ship_index, "orders": orders})

    return {
        "match_id": match_id,
        "round": round_num,
        "phase": "ai_turn_end",
        "actions": actions,
    }


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
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(OLLAMA_API_URL, json=payload, timeout=OLLAMA_TIMEOUT_SEC)
            response.raise_for_status()
            result_text = response.json()["response"]
    except Exception:
        return _fallback_admiral_decision(game_context_json)

    try:
        decision = json.loads(result_text)
    except json.JSONDecodeError:
        return _fallback_admiral_decision(game_context_json)

    if not isinstance(decision, dict) or not decision.get("actions"):
        return _fallback_admiral_decision(game_context_json)

    decision = _normalize_admiral_decision(decision, game_context_json)
    if not _has_effective_actions(decision):
        return _fallback_admiral_decision(game_context_json)

    return decision


def _normalize_admiral_decision(decision: dict, game_context: dict) -> dict:
    """Fix common LLM mistakes (zero-distance moves, wrong casing)."""
    rules = game_context.get("rules", {})
    max_move = float(rules.get("max_move_distance", 90.0))
    min_move = float(rules.get("min_move_distance", 5.0))
    default_move = min(max_move, 45.0)

    decision["match_id"] = str(decision.get("match_id") or game_context.get("match_id", ""))
    decision["round"] = int(decision.get("round") or game_context.get("round", 1))
    decision["phase"] = "ai_turn_end"

    for action in decision.get("actions", []):
        if not isinstance(action, dict):
            continue
        orders = action.get("orders", [])
        if not isinstance(orders, list):
            action["orders"] = []
            continue
        for order in orders:
            if not isinstance(order, dict):
                continue
            order["type"] = str(order.get("type", "")).strip().lower()
            if order["type"] == "move":
                distance = float(order.get("distance", 0) or 0)
                if distance <= 0:
                    order["distance"] = default_move
                else:
                    order["distance"] = min(distance, max_move)
                if abs(float(order.get("angle", 0) or 0)) < 0.01:
                    order["angle"] = _default_bearing_for_ship(action, game_context)
            elif order["type"] == "fire":
                fire_dist = float(order.get("distance", 0) or 0)
                if fire_dist <= 0:
                    order["distance"] = 80.0
    return decision


def _default_bearing_for_ship(action: dict, game_context: dict) -> float:
    ship_index = int(action.get("ship_index", -1))
    ai_fleet = game_context.get("ai_fleet", [])
    visible_human = game_context.get("visible_human_ships", [])

    ship_pos = None
    for ship in ai_fleet:
        if int(ship.get("ship_index", -1)) == ship_index:
            ship_pos = ship.get("position", {})
            break
    if not ship_pos or not visible_human:
        return 0.0

    sx, sz = _ship_xz(ship_pos)
    target = visible_human[0]
    tx, tz = _ship_xz(target.get("position", {}))
    return math.degrees(math.atan2(tx - sx, -(tz - sz)))


def _has_effective_actions(decision: dict) -> bool:
    for action in decision.get("actions", []):
        for order in action.get("orders", []):
            if not isinstance(order, dict):
                continue
            order_type = str(order.get("type", "")).lower()
            if order_type == "move" and float(order.get("distance", 0) or 0) > 0:
                return True
            if order_type == "fire" and str(order.get("weapon", "")).strip():
                return True
    return False


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
