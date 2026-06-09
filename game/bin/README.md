# Battle server (Godot)

The battle server must be running **before** you finish match prep (after the coin countdown the client connects on port **7777**).

## Option A — Godot Editor F5 (easiest)

1. Start **FastAPI** (see below).
2. Press **F5** in Godot (main scene).
3. Play through menu → PvE → coin flip → countdown.

In the editor, battle placement runs **in the same process** — you do **not** need a second window or F6.

To test the real ENet server flow from the editor, run with user arg `--force-battle-server` and start `BattleServerMain` separately (F6).

## Option B — PowerShell script (Windows)

From the `game` folder:

```powershell
.\bin\start-battle-server.ps1
```

If Godot is not found, set the path once:

```powershell
$env:BATTLEFLEET_GODOT_EXE = "C:\path\to\Godot_v4.6-stable_win64.exe"
.\bin\start-battle-server.ps1
```

## Option C — Command line (Godot on PATH)

```powershell
godot --path . res://scenes/battle/BattleServerMain.tscn -- --battle-server --port 7777
```

If you see `'godot' is not recognized`, use Option A or B, or add your Godot folder to Windows PATH.

---

# FastAPI (meta-game)

From the `backend` folder:

```powershell
# Docker
docker compose up --build

# Or local Python
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8001
```

API: `http://127.0.0.1:8001`
