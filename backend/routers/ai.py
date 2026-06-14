import base64
import os

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Dict, Any, Optional
import json
import logging
import os

from services.ai_service import get_admiral_decision, get_narrator_commentary

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["AI"])

class GameStatePayload(BaseModel):
    game_state: Dict[str, Any]

class NarratorPayload(BaseModel):
    game_state: Dict[str, Any]
    instruction_text: Optional[str] = "You are Snoop Dogg acting as a naval deck officer. Warn the captain about the current situation using your signature style, slang, and laid-back attitude."

@router.post("/narrator_turn")
async def narrator_turn(payload: GameStatePayload):
    """
    Game narrator: generates a one-sentence Snoop Dogg commentary line about
    the current battle state, converts it to MP3 via gTTS, and returns the
    audio as base64 so the client can decode and play it without a second request.
    """
    output_audio_path = "instance/narrator_output.mp3"
    os.makedirs("instance", exist_ok=True)
    try:
        commentary = await get_narrator_commentary(
            payload.game_state,
            "instance/_game_narrator_instruction.md",
            output_audio_path,
        )
        with open(output_audio_path, "rb") as f:
            audio_b64 = base64.b64encode(f.read()).decode("utf-8")
        return {"commentary": commentary, "audio_b64": audio_b64}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/admiral_turn")
async def admiral_turn(payload: GameStatePayload):
    """
    PvE AI turn endpoint. Takes the serialized game state built by
    BattleTurnManager.build_ai_turn_request and returns tactical decisions
    in the form: { match_id, round, phase, actions: [ { ship_index, orders: [...] } ] }
    """
    try:
        logger.info(
            "admiral_turn request match=%s round=%s ai_ships=%d",
            payload.game_state.get("match_id"),
            payload.game_state.get("round"),
            len(payload.game_state.get("ai_fleet", [])),
        )
        decision = await get_admiral_decision(payload.game_state)
        logger.info("admiral_turn response: %s", json.dumps(decision)[:2000])
        return decision
    except Exception as e:
        logger.exception("admiral_turn failed")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/test/admiral")
async def test_admiral(payload: GameStatePayload):
    """
    Test endpoint for the Enemy Admiral (llama3.2:1b).
    Takes a JSON game state and returns the tactical decision.
    """
    try:
        decision = await get_admiral_decision(payload.game_state)
        return decision
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/test/narrator")
async def test_narrator(payload: NarratorPayload):
    """
    Test endpoint for the Deck Officer Narrator (qwen2.5:1.5b).
    Takes a JSON game state and optional markdown instructions.
    Returns the commentary text and generates an audio file.
    """
    temp_md_path = "instance/temp_instruction.md"
    output_audio_path = "instance/narrator_output.mp3"
    
    # Write the instruction text to a temp file
    os.makedirs(os.path.dirname(temp_md_path), exist_ok=True)
    with open(temp_md_path, "w", encoding="utf-8") as f:
        f.write(payload.instruction_text)
        
    try:
        commentary = await get_narrator_commentary(
            payload.game_state, 
            temp_md_path, 
            output_audio_path
        )
        return {
            "commentary": commentary,
            "audio_path": output_audio_path
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
