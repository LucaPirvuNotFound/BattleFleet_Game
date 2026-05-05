from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class Vec3(BaseModel):
    """Right-handed coordinates; assume Y-up (Unity convention) unless documented otherwise."""

    x: float = Field(..., description="World X")
    y: float = Field(..., description="World Y (up)")
    z: float = Field(..., description="World Z")


class Environment(BaseModel):
    """Optional environmental factors; extend as the Unity sim grows."""

    gravity: float = Field(
        9.81,
        ge=0.0,
        description="Gravitational acceleration magnitude (m/s²). Motion uses -Y as down.",
    )


class GameState(BaseModel):
    """Incoming board snapshot from the Unity client."""

    ai_ship_position: Vec3 = Field(..., description="Position of the AI-controlled ship (muzzle origin).")
    target_ship_position: Vec3 = Field(..., description="Position of the enemy ship (aim point).")
    environment: Environment = Field(default_factory=Environment)


class ShootAction(BaseModel):
    """Fire solution returned to Unity."""

    action: Literal["shoot"] = "shoot"
    angle_horizontal: float = Field(
        ...,
        description="Yaw angle in radians: rotation around world Y from +Z toward +X (atan2(x,z)).",
    )
    angle_vertical: float = Field(
        ...,
        description="Pitch angle in radians: elevation above the horizontal plane (positive = upward component).",
    )
    power: float = Field(..., ge=0.0, description="Launch speed magnitude (m/s), matching flat-earth ballistic model.")
