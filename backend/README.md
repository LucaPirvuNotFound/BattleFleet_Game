# Battle Fleet AI Backend (“The Brain”)

Local HTTP service for a **Battle Fleet 2**–style university project: the Unity client sends the current **game state** as JSON; this server returns a **shoot action** (aim angles and launch speed) computed from basic projectile physics.

---

## What This Backend Does

1. **Accepts** a POST body describing the AI ship position, enemy ship position, and optional gravity.
2. **Validates** the payload with **Pydantic** models (`GameState`).
3. **Computes** a ballistic firing solution: horizontal yaw, vertical pitch (elevation), and muzzle speed (“power”).
4. **Returns** JSON matching the `ShootAction` schema.

This is **version 1**: a deterministic geometric solver, not an LLM. It gives the AI a baseline “always aim at the enemy center with vacuum ballistics” behavior before you add wind, drag, or smarter tactics.

---

## Tech Stack

| Piece | Role |
|--------|------|
| **Python 3.x** | Runtime |
| **FastAPI** | HTTP API framework, automatic OpenAPI docs |
| **Uvicorn** | ASGI server (runs the FastAPI app locally) |
| **Pydantic v2** | Request/response schemas and validation |
| **`math` (stdlib)** | Trajectory math |

Dependencies are pinned loosely in `requirements.txt`.

---

## Project Layout

```
backend/
├── README.md                 ← this file
├── requirements.txt
└── app/
    ├── __init__.py
    ├── main.py               # FastAPI routes
    ├── schemas.py            # Pydantic models (GameState, ShootAction, Vec3, …)
    └── physics.py            # Ballistic solver: compute_minimum_speed_ballistic()
```

---

## How It Works

### Request model (`GameState`)

- **`ai_ship_position`**, **`target_ship_position`**: `Vec3` with `x`, `y`, `z` (meters), **Y-up** (aligned with typical Unity scenes).
- **`environment.gravity`**: magnitude of gravitational acceleration (default **9.81** m/s²). Motion assumes gravity pulls along **−Y**.

### Response model (`ShootAction`)

- **`action`**: always `"shoot"` in this version.
- **`angle_horizontal`**: yaw in **radians**, **`atan2(dx, dz)`** — **0** radians points along **+Z** (common “forward” in Unity); increasing angle rotates toward **+X**.
- **`angle_vertical`**: pitch in **radians**, elevation **above the horizontal XZ plane** (positive = upward component of velocity).
- **`power`**: launch speed in **m/s** (magnitude of initial velocity in the ballistic model).

### Physics (`physics.py`)

The solver assumes:

- No air resistance  
- Flat Earth, constant **g** downward  
- Point shooter and point target  

For a given horizontal distance **d** in the XZ plane and vertical offset **h** (target − shooter along Y), there are infinitely many pairs of **(launch speed, elevation)** that hit the target. This implementation picks the **minimum launch speed** that still reaches the target, then solves for elevation (it uses the **lower** arc when two roots appear numerically).

Special case: if the target is almost **directly above or below** (no horizontal separation), the code uses a dedicated vertical shortcut.

Invalid geometry (e.g. shooter and target coincident, bad gravity) raises `ValueError`; the API maps that to **HTTP 422** with a short detail message.

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Simple `{ "status": "ok" }` for connectivity checks |
| POST | `/ai/decide` | Main endpoint: body = `GameState`, returns `ShootAction` |
| POST | `/ai/simulate-shot` | Same logic as `/ai/decide` (alias) |

Interactive docs (Swagger UI): **`http://127.0.0.1:<port>/docs`** while the server is running.

---

## Run Locally

From the **`backend`** directory:

```bash
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

If port **8000** is already taken (common with other dev servers), use another port, e.g. **`8010`**:

```bash
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8010
```

---

## Quick Test (Dummy JSON)

**PowerShell:**

```powershell
$body = @'
{
  "ai_ship_position": { "x": 0, "y": 10, "z": 0 },
  "target_ship_position": { "x": 200, "y": 12, "z": 50 },
  "environment": { "gravity": 9.81 }
}
'@

Invoke-RestMethod -Uri "http://127.0.0.1:8000/ai/decide" -Method Post -Body $body -ContentType "application/json"
```

You should get JSON with `action`, `angle_horizontal`, `angle_vertical`, and `power`.

---

## Unity Client Notes

- Angles are in **radians**. If your gameplay code uses **degrees**, multiply by `Mathf.Rad2Deg` (or `180f / Mathf.PI`).
- If your cannon’s forward axis is not **+Z**, apply a **fixed offset or basis change** on the client; keep the server math in a single consistent world frame.
- **`power`** is modeled as **initial speed** in m/s. Map it to your game’s normalized “power bar” or max range however your Unity physics expect.

---

## Limitations (Intentional for v1)

- No wind, Magnus effect, or ship motion relative to water  
- Aims at a **single point** (ship center), not hull sampling or splash radius  
- Minimum-speed solution only; no high-arc vs low-arc policy for obstacles  

These are natural extensions for later milestones.
