from __future__ import annotations

from fastapi import FastAPI, HTTPException

from app.physics import compute_minimum_speed_ballistic
from app.schemas import GameState, ShootAction

app = FastAPI(
    title="Battle Fleet AI Brain",
    description="Local HTTP service: accepts game state JSON, returns a ballistic shoot action.",
    version="0.1.0",
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/ai/decide", response_model=ShootAction)
def decide(state: GameState) -> ShootAction:
    """
    Heuristic v1: compute a vacuum ballistic solution toward the enemy ship center.
    """
    try:
        sol = compute_minimum_speed_ballistic(
            (
                state.ai_ship_position.x,
                state.ai_ship_position.y,
                state.ai_ship_position.z,
            ),
            (
                state.target_ship_position.x,
                state.target_ship_position.y,
                state.target_ship_position.z,
            ),
            gravity=state.environment.gravity,
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e

    return ShootAction(
        action="shoot",
        angle_horizontal=sol.yaw_rad,
        angle_vertical=sol.pitch_rad,
        power=sol.launch_speed,
    )


@app.post("/ai/simulate-shot", response_model=ShootAction)
def simulate_shot(state: GameState) -> ShootAction:
    """Alias for clients that prefer RESTful naming."""
    return decide(state)
