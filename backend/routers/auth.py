from fastapi import APIRouter, HTTPException, status
from passlib.context import CryptContext

from dependencies import create_access_token
from models import TokenResponse, UserLoginRequest, UserRegisterRequest

router = APIRouter(prefix="/auth", tags=["auth"])

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# username -> { "email": str, "hashed_password": str }
users_db: dict[str, dict[str, str]] = {}


def _hash_password(password: str) -> str:
    return pwd_context.hash(password)


def _verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def _username_taken(username: str) -> bool:
    return username in users_db


def _email_taken(email: str) -> bool:
    normalized = email.lower()
    return any(record["email"].lower() == normalized for record in users_db.values())


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(body: UserRegisterRequest) -> dict[str, str]:
    if _username_taken(body.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered",
        )
    if _email_taken(body.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    users_db[body.username] = {
        "email": body.email,
        "hashed_password": _hash_password(body.password),
    }
    return {"message": "User registered successfully"}


@router.post("/login", response_model=TokenResponse)
def login(body: UserLoginRequest) -> TokenResponse:
    user = users_db.get(body.username)
    if user is None or not _verify_password(body.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(subject=body.username)
    return TokenResponse(access_token=access_token, token_type="bearer")
