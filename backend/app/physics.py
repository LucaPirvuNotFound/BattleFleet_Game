from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass(frozen=True)
class BallisticSolution:
    yaw_rad: float
    pitch_rad: float
    launch_speed: float


def compute_minimum_speed_ballistic(
    shooter: tuple[float, float, float],
    target: tuple[float, float, float],
    gravity: float = 9.81,
) -> BallisticSolution:
    """
    Compute yaw, pitch, and launch speed for a vacuum ballistic shot under gravity along -Y.

    Uses the **minimum launch speed** that can still reach the target (single physically meaningful
    choice among infinitely many angle/speed pairs). No drag, flat earth, point masses.

    Coordinate convention:
    - Horizontal plane: XZ; yaw = atan2(dx, dz) so 0 rad faces +Z (common Unity forward).
    - Pitch is elevation above the XZ plane for the initial velocity vector.

    Raises:
        ValueError: If the shot is degenerate (same horizontal position with insufficient physics)
                    or gravity is non-positive.
    """
    if gravity <= 0:
        raise ValueError("gravity must be positive (magnitude of downward acceleration).")

    sx, sy, sz = shooter
    tx, ty, tz = target
    dx, dy, dz = tx - sx, ty - sy, tz - sz

    d = math.hypot(dx, dz)
    h = dy

    yaw = math.atan2(dx, dz)

    # Degenerate: target directly above/below (horizontal distance ~ 0)
    if d < 1e-9:
        if abs(h) < 1e-9:
            raise ValueError("target coincides with shooter.")
        # Straight vertical: need initial vy toward target; no horizontal component.
        # vy^2 = 2 g h only works for aiming at rest — for projectile from origin with speed v at 90°:
        # Use energy: v = sqrt(2 * g * |h|) when firing straight up/down distance |h|... Actually for
        # vertical shot to climb height h>0: v_y = sqrt(2 g h). For h<0 (below), still solvable with
        # downward velocity — treat separately.
        if h > 0:
            v = math.sqrt(2.0 * gravity * h)
            pitch = math.pi / 2.0
        else:
            # Target below: aim downward; minimum speed is sqrt(2 g |h|) dropping straight down
            v = math.sqrt(2.0 * gravity * abs(h))
            pitch = -math.pi / 2.0
        return BallisticSolution(yaw_rad=yaw, pitch_rad=pitch, launch_speed=v)

    # Minimum speed to reach (d, h): classic result with +y upward and gravity g downward.
    inner = h + math.sqrt(d * d + h * h)
    if inner < 0:
        raise ValueError("invalid geometry for minimum-speed formula.")

    v_min_sq = gravity * inner
    if v_min_sq <= 0:
        raise ValueError("cannot derive positive launch speed for this segment.")

    v = math.sqrt(v_min_sq)

    # Solve for elevation using the quadratic in tan(theta) for this fixed v (discriminant ~ 0).
    # (g d^2 / (2 v^2)) tan^2 - d tan + (h + g d^2 / (2 v^2)) = 0
    g_d2_over_2v2 = gravity * d * d / (2.0 * v * v)
    a = g_d2_over_2v2
    b = -d
    c = h + g_d2_over_2v2

    disc = b * b - 4.0 * a * c
    if disc < -1e-6:
        raise ValueError("target unreachable with ballistic arc at minimum speed (numerical issue).")
    disc = max(0.0, disc)

    sqrt_disc = math.sqrt(disc)
    t1 = (-b - sqrt_disc) / (2.0 * a)
    t2 = (-b + sqrt_disc) / (2.0 * a)

    # At minimum speed the roots coincide; pick stable branch (prefer lower arc if tiny drift).
    tan_candidates = [t for t in (t1, t2) if math.isfinite(t)]
    if not tan_candidates:
        raise ValueError("no valid elevation.")

    tan_theta = min(tan_candidates)  # lower arc (smaller tan); swap if you prefer high arc

    pitch = math.atan(tan_theta)

    return BallisticSolution(yaw_rad=yaw, pitch_rad=pitch, launch_speed=v)
