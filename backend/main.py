import asyncio
import os

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.auth import router as auth_router
from routers.matchmaking import router as matchmaking_router
from routers.matches import router as matches_router
from routers.ai import router as ai_router

app = FastAPI(title="BattleFleet API", version="0.1.0")


async def _warmup_ollama() -> None:
    """Load both AI models into RAM at startup and pin them with keep_alive=-1."""
    url = os.getenv("OLLAMA_API_URL", "http://host.docker.internal:11434/api/generate")
    models = ["llama3.2:1b", "qwen2.5:1.5b"]
    async with httpx.AsyncClient() as client:
        for model in models:
            try:
                await client.post(
                    url,
                    json={"model": model, "prompt": "ready", "stream": False, "keep_alive": -1},
                    timeout=300.0,
                )
            except Exception:
                pass  # Warmup failures are non-fatal


@app.on_event("startup")
async def startup_event() -> None:
    asyncio.create_task(_warmup_ollama())

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(matchmaking_router)
app.include_router(matches_router)
app.include_router(ai_router)
