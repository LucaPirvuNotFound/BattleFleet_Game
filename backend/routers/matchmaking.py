from typing import Any

from fastapi import APIRouter, Depends

from dependencies import get_current_user
from match_models import QueueRequest, QueueStatusResponse
from services import match_store

router = APIRouter(prefix="/matchmaking", tags=["matchmaking"])


@router.post("/queue", status_code=202)
def join_queue(
    body: QueueRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> QueueStatusResponse:
    username = current_user["username"]
    match_store.enqueue(username, body.mode, body.fleet)
    matched = _find_active_match_id(username)
    if matched is not None:
        return QueueStatusResponse(
            status="matched",
            match_id=matched,
            message="Match found",
        )
    status_payload = match_store.get_queue_status(username)
    return QueueStatusResponse(**status_payload)


@router.get("/status", response_model=QueueStatusResponse)
def queue_status(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> QueueStatusResponse:
    username = current_user["username"]
    status_payload = match_store.get_queue_status(username)

    # If user was paired, they are no longer in queue — check active match
    if status_payload["status"] == "idle":
        matched = _find_active_match_id(username)
        if matched is not None:
            return QueueStatusResponse(
                status="matched",
                match_id=matched,
                message="Match found",
            )

    return QueueStatusResponse(**status_payload)


@router.delete("/queue", status_code=204)
def leave_queue(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> None:
    match_store.dequeue(current_user["username"])


def _find_active_match_id(username: str) -> str | None:
    for match in match_store.matches_by_id.values():
        if match["phase"] == "finished":
            continue
        if any(player["username"] == username for player in match["players"]):
            return match["match_id"]
    return None
