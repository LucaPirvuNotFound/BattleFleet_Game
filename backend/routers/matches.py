from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user, get_current_user_optional
from match_models import (
    BattleHandoffResponse,
    BattleSessionResponse,
    GameMode,
    InstantMatchRequest,
    MatchView,
    PlacementRequest,
)
from services import match_store

router = APIRouter(prefix="/matches", tags=["matches"])


@router.post("/instant", response_model=MatchView, status_code=201)
def create_instant_match(
    body: InstantMatchRequest,
    current_user: dict[str, Any] | None = Depends(get_current_user_optional),
) -> MatchView:
    username = _resolve_username(current_user, body.mode)
    match = match_store.create_instant_match(
        username,
        body.mode,
        body.fleet,
        opponent_fleet=body.opponent_fleet,
        opponent_username=body.opponent_username,
    )
    return match_store.get_match(match["match_id"], username)


@router.get("/{match_id}", response_model=MatchView)
def get_match(
    match_id: str,
    current_user: dict[str, Any] | None = Depends(get_current_user_optional),
) -> MatchView:
    username = current_user["username"] if current_user else None
    return match_store.get_match(match_id, username)


@router.post("/{match_id}/coin_ack", response_model=MatchView)
def coin_ack(
    match_id: str,
    current_user: dict[str, Any] | None = Depends(get_current_user_optional),
) -> MatchView:
    username = _resolve_coin_ack_username(current_user, match_id)
    return match_store.acknowledge_coin(match_id, username)


@router.post("/{match_id}/battle/handoff", response_model=BattleHandoffResponse)
def battle_handoff(
    match_id: str,
    current_user: dict[str, Any] | None = Depends(get_current_user_optional),
) -> BattleHandoffResponse:
    username = _resolve_coin_ack_username(current_user, match_id)
    return match_store.create_battle_handoff(match_id, username)


@router.get("/{match_id}/battle/session", response_model=BattleSessionResponse)
def battle_session(match_id: str, token: str) -> BattleSessionResponse:
    return match_store.get_battle_session(match_id, token)


@router.post("/{match_id}/placement", response_model=MatchView)
def submit_placement(
    match_id: str,
    body: PlacementRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> MatchView:
    placements = [placement.model_dump() for placement in body.placements]
    return match_store.submit_placement(match_id, current_user["username"], placements)


@router.post("/{match_id}/ready", response_model=MatchView)
def mark_ready(
    match_id: str,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> MatchView:
    return match_store.mark_ready(match_id, current_user["username"])


def _resolve_coin_ack_username(
    current_user: dict[str, Any] | None,
    match_id: str,
) -> str:
    if current_user is not None:
        return current_user["username"]
    match = match_store.matches_by_id.get(match_id)
    if match is not None and match.get("mode") == GameMode.LOCAL.value:
        players = match.get("players", [])
        if players:
            return str(players[0]["username"])
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Login required for this action",
    )


def _resolve_username(current_user: dict[str, Any] | None, mode: GameMode) -> str:
    if current_user is not None:
        return current_user["username"]
    if mode == GameMode.LOCAL:
        return "Guest"
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Login required for this mode",
    )
