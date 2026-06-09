import os
import sys
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.database_manager import DatabaseManager
from database.player_repository import PlayerRepository

SECRET_KEY = os.getenv("BATTLEFLEET_SECRET_KEY", "dev-secret-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

security = HTTPBearer()
optional_security = HTTPBearer(auto_error=False)

# Global database manager
db_manager = DatabaseManager(database_path=os.path.join(os.path.dirname(__file__), "instance", "BattleFleetGame.db"))

def get_db() -> DatabaseManager:
    if not db_manager.is_ready():
        os.makedirs(os.path.join(os.path.dirname(__file__), "instance"), exist_ok=True)
        db_manager.initialize()
    return db_manager

def get_player_repo(db: DatabaseManager = Depends(get_db)) -> PlayerRepository:
    return PlayerRepository(db)

def create_access_token(subject: str, expires_delta: timedelta | None = None) -> str:
    expire = datetime.now(timezone.utc) + (
        expires_delta if expires_delta is not None else timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    payload = {"sub": subject, "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> str:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    username: str | None = payload.get("sub")
    if username is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return username


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    player_repo: PlayerRepository = Depends(get_player_repo)
) -> dict[str, Any]:
    username = decode_access_token(credentials.credentials)
    user = player_repo.get_player_by_name(username)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return {"username": user.player_name, "email": user.email}


async def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_security),
    player_repo: PlayerRepository = Depends(get_player_repo)
) -> dict[str, Any] | None:
    if credentials is None:
        return None
    username = decode_access_token(credentials.credentials)
    user = player_repo.get_player_by_name(username)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return {"username": user.player_name, "email": user.email}
