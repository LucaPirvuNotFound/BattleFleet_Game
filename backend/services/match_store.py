from __future__ import annotations

import os
import random
import uuid
from typing import Any

from fastapi import HTTPException, status

from match_models import (
    BattleHandoffResponse,
    BattlePlayerSession,
    BattleSessionResponse,
    FleetPayload,
    GameMode,
    MatchPhase,
    MatchPlayerView,
    MatchView,
)

BATTLE_SERVER_HOST = os.getenv("BATTLE_SERVER_HOST", "127.0.0.1")
BATTLE_SERVER_PORT = int(os.getenv("BATTLE_SERVER_PORT", "7777"))

# username -> queue entry
queue_by_user: dict[str, dict[str, Any]] = {}

# match_id -> match document
matches_by_id: dict[str, dict[str, Any]] = {}

AI_USERNAME = "AI_Captain"
AI_FLEET: dict[str, Any] = {
    "ships": [{"name": "Corvette", "weapons": ["Light Cannon"]}],
    "total_cost": 15,
}


def _fleet_to_dict(fleet: FleetPayload) -> dict[str, Any]:
    return fleet.model_dump()


def _new_player(username: str, slot: int, fleet: FleetPayload) -> dict[str, Any]:
    return {
        "username": username,
        "slot": slot,
        "fleet": _fleet_to_dict(fleet),
        "placement": None,
        "coin_ack": False,
        "placement_ready": False,
    }


def _create_match(
    mode: GameMode,
    players: list[dict[str, Any]],
) -> dict[str, Any]:
    match_id = str(uuid.uuid4())
    usernames = [player["username"] for player in players]
    first_player = random.choice(usernames)

    match = {
        "match_id": match_id,
        "mode": mode.value,
        "phase": MatchPhase.COIN.value,
        "map_seed": random.randint(1, 2_147_483_647),
        "map_index": 1,
        "first_player_username": first_player,
        "players": players,
    }
    matches_by_id[match_id] = match
    return match


def enqueue(username: str, mode: GameMode, fleet: FleetPayload) -> None:
    if username in queue_by_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Already in matchmaking queue",
        )
    for match in matches_by_id.values():
        if _player_in_match(match, username) and match["phase"] != MatchPhase.FINISHED.value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Already in an active match",
            )

    entry = {
        "username": username,
        "mode": mode.value,
        "fleet": _fleet_to_dict(fleet),
    }
    queue_by_user[username] = entry

    if mode == GameMode.PVP:
        _try_pair_pvp()


def dequeue(username: str) -> bool:
    return queue_by_user.pop(username, None) is not None


def get_queue_status(username: str) -> dict[str, Any]:
    if username not in queue_by_user:
        return {"status": "idle", "match_id": None, "message": "Not in queue"}
    return {
        "status": "searching",
        "match_id": None,
        "message": "Searching for opponent...",
    }


def _try_pair_pvp() -> None:
    pvp_waiting = [
        entry for entry in queue_by_user.values() if entry["mode"] == GameMode.PVP.value
    ]
    if len(pvp_waiting) < 2:
        return

    first_entry = pvp_waiting[0]
    second_entry = next(
        entry for entry in pvp_waiting[1:] if entry["username"] != first_entry["username"]
    )

    queue_by_user.pop(first_entry["username"], None)
    queue_by_user.pop(second_entry["username"], None)

    player_a = _new_player(
        first_entry["username"],
        0,
        FleetPayload.model_validate(first_entry["fleet"]),
    )
    player_b = _new_player(
        second_entry["username"],
        1,
        FleetPayload.model_validate(second_entry["fleet"]),
    )
    _create_match(GameMode.PVP, [player_a, player_b])


def create_instant_match(
    username: str,
    mode: GameMode,
    fleet: FleetPayload,
    *,
    opponent_fleet: FleetPayload | None = None,
    opponent_username: str | None = None,
) -> dict[str, Any]:
    if mode == GameMode.PVP:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="PvP requires matchmaking queue",
        )

    human = _new_player(username, 0, fleet)

    if mode == GameMode.LOCAL:
        guest_name = (opponent_username or "Local_Opponent").strip() or "Local_Opponent"
        guest_fleet = opponent_fleet if opponent_fleet is not None else fleet
        local_opponent = _new_player(guest_name, 1, guest_fleet)
        return _create_match(GameMode.LOCAL, [human, local_opponent])

    ai = _new_player(AI_USERNAME, 1, fleet)
    match = _create_match(GameMode.PVE, [human, ai])
    # AI auto-acknowledges coin flip for smoother solo flow
    ai_player = match["players"][1]
    ai_player["coin_ack"] = True
    return match


def get_match(match_id: str, username: str | None) -> MatchView:
    match = _require_match(match_id)
    if username and not _player_in_match(match, username) and match["mode"] != GameMode.LOCAL.value:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a player in this match")
    return _to_match_view(match, username)


def acknowledge_coin(match_id: str, username: str) -> MatchView:
    match = _require_match(match_id)
    player = _require_player(match, username)
    if match["phase"] != MatchPhase.COIN.value:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Not in coin phase")

    player["coin_ack"] = True
    _maybe_advance_from_coin(match)
    return _to_match_view(match, username)


def submit_placement(match_id: str, username: str, placements: list[dict[str, Any]]) -> MatchView:
    match = _require_match(match_id)
    player = _require_player(match, username)
    if match["phase"] != MatchPhase.PLACEMENT.value:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Not in placement phase")

    fleet_size = len(player["fleet"]["ships"])
    if len(placements) != fleet_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Expected {fleet_size} ship placements",
        )

    indices = sorted(int(p["ship_index"]) for p in placements)
    if indices != list(range(fleet_size)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="ship_index values must cover each ship exactly once",
        )

    player["placement"] = placements
    return _to_match_view(match, username)


def create_battle_handoff(match_id: str, username: str | None) -> BattleHandoffResponse:
    match = _require_match(match_id)
    if not all(player["coin_ack"] for player in match["players"]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Coin flip not complete for all players",
        )
    if username and not _player_in_match(match, username) and match["mode"] != GameMode.LOCAL.value:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a player in this match")

    battle_token = match.get("battle_token")
    if not battle_token:
        battle_token = str(uuid.uuid4())
        match["battle_token"] = battle_token

    match["phase"] = MatchPhase.COMBAT.value
    session_players = _battle_session_players(match)
    first_player = match.get("first_player_username")
    you_go_first = username is not None and first_player == username

    return BattleHandoffResponse(
        match_id=match["match_id"],
        battle_host=BATTLE_SERVER_HOST,
        battle_port=BATTLE_SERVER_PORT,
        battle_token=battle_token,
        map_seed=match["map_seed"],
        map_index=match["map_index"],
        mode=GameMode(match["mode"]),
        first_player_username=first_player,
        you_go_first=you_go_first,
        local_username=username,
        players=session_players,
    )


def get_battle_session(match_id: str, battle_token: str) -> BattleSessionResponse:
    match = _require_match(match_id)
    if match.get("battle_token") != battle_token:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid battle token")
    if match["phase"] != MatchPhase.COMBAT.value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Match is not in combat phase",
        )

    return BattleSessionResponse(
        match_id=match["match_id"],
        battle_token=battle_token,
        map_seed=match["map_seed"],
        map_index=match["map_index"],
        mode=GameMode(match["mode"]),
        first_player_username=match.get("first_player_username"),
        players=_battle_session_players(match),
    )


def _battle_session_players(match: dict[str, Any]) -> list[BattlePlayerSession]:
    players: list[BattlePlayerSession] = []
    for player in match["players"]:
        players.append(
            BattlePlayerSession(
                username=player["username"],
                slot=player["slot"],
                fleet=FleetPayload.model_validate(player["fleet"]),
                is_ai=player["username"] == AI_USERNAME,
            )
        )
    return players


def mark_ready(match_id: str, username: str) -> MatchView:
    match = _require_match(match_id)
    player = _require_player(match, username)
    if match["phase"] != MatchPhase.PLACEMENT.value:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Not in placement phase")
    if player["placement"] is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Submit placement before ready",
        )

    player["placement_ready"] = True

    # Auto-ready AI or local hot-seat guest (slot 1) for prototype
    for other in match["players"]:
        is_ai = other["username"] == AI_USERNAME
        is_local_guest = match["mode"] == GameMode.LOCAL.value and other["slot"] == 1
        if is_ai or is_local_guest:
            if other["placement"] is None:
                other["placement"] = _default_ai_placement(other)
            other["placement_ready"] = True

    _maybe_advance_from_placement(match)
    return _to_match_view(match, username)


def _default_ai_placement(player: dict[str, Any]) -> list[dict[str, Any]]:
    placements = []
    for index in range(len(player["fleet"]["ships"])):
        placements.append({"ship_index": index, "x": index * 2, "y": 0, "rotation": 0})
    return placements


def _maybe_advance_from_coin(match: dict[str, Any]) -> None:
    if match["phase"] != MatchPhase.COIN.value:
        return
    if all(player["coin_ack"] for player in match["players"]):
        match["phase"] = MatchPhase.PLACEMENT.value


def _maybe_advance_from_placement(match: dict[str, Any]) -> None:
    if match["phase"] != MatchPhase.PLACEMENT.value:
        return
    if all(player["placement_ready"] for player in match["players"]):
        match["phase"] = MatchPhase.COMBAT.value


def _require_match(match_id: str) -> dict[str, Any]:
    match = matches_by_id.get(match_id)
    if match is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Match not found")
    return match


def _require_player(match: dict[str, Any], username: str) -> dict[str, Any]:
    for player in match["players"]:
        if player["username"] == username:
            return player
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a player in this match")


def _player_in_match(match: dict[str, Any], username: str) -> bool:
    return any(player["username"] == username for player in match["players"])


def _to_match_view(match: dict[str, Any], username: str | None) -> MatchView:
    players_view: list[MatchPlayerView] = []
    opponent_username: str | None = None

    for player in match["players"]:
        is_you = username is not None and player["username"] == username
        if username and player["username"] != username and player["username"] != AI_USERNAME:
            opponent_username = player["username"]

        players_view.append(
            MatchPlayerView(
                username=player["username"],
                slot=player["slot"],
                fleet=FleetPayload.model_validate(player["fleet"]),
                placement_ready=player["placement_ready"],
                coin_ack=player["coin_ack"],
                is_you=is_you,
            )
        )

    first_player = match.get("first_player_username")
    you_go_first = username is not None and first_player == username

    return MatchView(
        match_id=match["match_id"],
        mode=GameMode(match["mode"]),
        phase=MatchPhase(match["phase"]),
        map_seed=match["map_seed"],
        map_index=match["map_index"],
        first_player_username=first_player,
        you_go_first=you_go_first,
        local_username=username,
        opponent_username=opponent_username,
        players=players_view,
    )
