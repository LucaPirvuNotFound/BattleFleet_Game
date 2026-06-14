from fastapi import APIRouter, Depends, HTTPException, status
import bcrypt

from dependencies import create_access_token, get_player_repo
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from database.player_repository import PlayerRepository
from models import TokenResponse, UserLoginRequest, UserRegisterRequest

router = APIRouter(prefix="/auth", tags=["auth"])

def _hash_password(password: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')


def _verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except ValueError:
        return False


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(body: UserRegisterRequest, player_repo: PlayerRepository = Depends(get_player_repo)) -> dict[str, str]:
    if player_repo.player_exists(body.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered",
        )
    
    # We do not strictly check for email uniqueness with a helper yet, 
    # but the DB enforces UNIQUE on Email. Let's try inserting.
    hashed = _hash_password(body.password)
    player = player_repo.create_player(player_name=body.username, email=body.email, password_hash=hashed)
    if not player:
         raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Registration failed. Email might already be registered.",
        )

    return {"message": "User registered successfully"}


@router.post("/login", response_model=TokenResponse)
def login(body: UserLoginRequest, player_repo: PlayerRepository = Depends(get_player_repo)) -> TokenResponse:
    user = player_repo.get_player_by_name(body.username)
    if user is None or not _verify_password(body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    player_repo.update_last_played_date(user.player_id)
    access_token = create_access_token(subject=body.username)
    return TokenResponse(access_token=access_token, token_type="bearer")
