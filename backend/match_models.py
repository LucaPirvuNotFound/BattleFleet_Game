from enum import Enum
from typing import Any

from pydantic import BaseModel, Field


class GameMode(str, Enum):
    PVP = "pvp"
    PVE = "pve"
    LOCAL = "local"


class MatchPhase(str, Enum):
    COIN = "coin"
    PLACEMENT = "placement"
    COMBAT = "combat"
    FINISHED = "finished"


class FleetShip(BaseModel):
    name: str = Field(..., min_length=1, max_length=64)
    weapons: list[str] = Field(default_factory=list)


class FleetPayload(BaseModel):
    ships: list[FleetShip] = Field(..., min_length=1, max_length=5)
    total_cost: int = Field(..., ge=0, le=100)


class QueueRequest(BaseModel):
    mode: GameMode = GameMode.PVP
    fleet: FleetPayload


class InstantMatchRequest(BaseModel):
    mode: GameMode
    fleet: FleetPayload
    opponent_fleet: FleetPayload | None = None
    opponent_username: str | None = Field(default=None, max_length=64)


class ShipPlacement(BaseModel):
    ship_index: int = Field(..., ge=0, le=4)
    x: int = Field(..., ge=0, le=127)
    y: int = Field(..., ge=0, le=127)
    rotation: int = Field(default=0, ge=0, le=3)


class PlacementRequest(BaseModel):
    placements: list[ShipPlacement] = Field(..., min_length=1, max_length=5)


class MatchPlayerView(BaseModel):
    username: str
    slot: int
    fleet: FleetPayload
    placement_ready: bool
    coin_ack: bool
    is_you: bool = False


class MatchView(BaseModel):
    match_id: str
    mode: GameMode
    phase: MatchPhase
    map_seed: int
    map_index: int
    first_player_username: str | None
    you_go_first: bool
    local_username: str | None
    opponent_username: str | None
    players: list[MatchPlayerView]


class QueueStatusResponse(BaseModel):
    status: str
    match_id: str | None = None
    message: str | None = None


class MatchEvent(BaseModel):
    type: str
    match_id: str
    phase: MatchPhase | None = None
    payload: dict[str, Any] = Field(default_factory=dict)
